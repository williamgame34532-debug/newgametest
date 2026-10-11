using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using UnityEngine;

// Транспорт сетевой игры. Хост — пир 0, клиенты получают номера 1..N.
// Сообщения бывают надёжные (доставка по порядку, с повтором) и ненадёжные (снимки состояния).
public interface INetTransport
{
    bool IsHost { get; }
    // peer: у хоста — номер клиента (или -1 = всем), у клиента — всегда хосту
    void Send(int peer, byte[] data, int len, bool reliable);
    bool Receive(out int peer, out byte[] data);
    void Tick();
    void Close();
    List<int> Peers { get; }
    string Describe { get; }
    // отключившиеся с прошлого опроса
    List<int> Dropped { get; }
}

// Прямое соединение по UDP (адрес хоста или виртуальная сеть Radmin/Hamachi/ZeroTier).
// Поверх UDP — простая надёжная доставка: номер пакета, подтверждение, повтор каждые 200 мс.
public class UdpTransport : INetTransport
{
    public const int DefaultPort = 27960;
    const byte U = 0, R = 1, ACK = 2, HELLO = 3, BYE = 4;

    class Conn
    {
        public IPEndPoint ep;
        public ushort outSeq, inNext;
        public readonly Dictionary<ushort, (byte[] data, float sent)> unacked = new Dictionary<ushort, (byte[], float)>();
        public readonly Dictionary<ushort, byte[]> early = new Dictionary<ushort, byte[]>();
        public float lastHeard;
    }

    readonly UdpClient sock;
    readonly bool host;
    readonly Dictionary<int, Conn> conns = new Dictionary<int, Conn>();
    readonly Dictionary<string, int> byAddr = new Dictionary<string, int>();
    readonly Queue<(int, byte[])> inbox = new Queue<(int, byte[])>();
    readonly List<int> peers = new List<int>();
    readonly List<int> dropped = new List<int>();
    int nextPeer = 1;
    float helloT;
    string desc;

    public bool IsHost => host;
    public List<int> Peers => peers;
    public List<int> Dropped => dropped;
    public string Describe => desc;

    public static UdpTransport Host(int port)
    {
        var t = new UdpTransport(true, new IPEndPoint(IPAddress.Any, port), null);
        t.desc = "IP: " + LocalIPs() + "  порт " + port;
        return t;
    }

    public static UdpTransport Join(string address, int port)
    {
        var ips = Dns.GetHostAddresses(address);
        IPAddress ip = null;
        foreach (var a in ips) if (a.AddressFamily == AddressFamily.InterNetwork) { ip = a; break; }
        if (ip == null) throw new Exception("адрес не найден: " + address);
        var t = new UdpTransport(false, new IPEndPoint(IPAddress.Any, 0), new IPEndPoint(ip, port));
        t.desc = "Хост " + address + ":" + port;
        return t;
    }

    UdpTransport(bool isHost, IPEndPoint bind, IPEndPoint server)
    {
        host = isHost;
        sock = new UdpClient(bind);
        sock.Client.Blocking = false;
        try { sock.Client.ReceiveBufferSize = 1 << 20; } catch { }
        // Windows: не рвать «соединение» из-за ICMP «порт недоступен»
        try { const int SIO_UDP_CONNRESET = -1744830452; sock.Client.IOControl(SIO_UDP_CONNRESET, new byte[] { 0 }, null); } catch { }
        if (!host)
        {
            var c = new Conn { ep = server, lastHeard = Time.unscaledTime };
            conns[0] = c; byAddr[server.ToString()] = 0;
            peers.Add(0);
        }
    }

    static string LocalIPs()
    {
        var list = new List<string>();
        try
        {
            foreach (var a in Dns.GetHostAddresses(Dns.GetHostName()))
                if (a.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(a)) list.Add(a.ToString());
        }
        catch { }
        return list.Count > 0 ? string.Join(", ", list) : "127.0.0.1";
    }

    public void Send(int peer, byte[] data, int len, bool reliable)
    {
        if (peer < 0) { foreach (var p in peers) Send(p, data, len, reliable); return; }
        if (!conns.TryGetValue(peer, out var c)) return;
        byte[] pkt;
        if (reliable)
        {
            ushort seq = c.outSeq++;
            pkt = new byte[len + 3];
            pkt[0] = R; pkt[1] = (byte)(seq & 255); pkt[2] = (byte)(seq >> 8);
            Buffer.BlockCopy(data, 0, pkt, 3, len);
            c.unacked[seq] = (pkt, Time.unscaledTime);
        }
        else
        {
            pkt = new byte[len + 1];
            pkt[0] = U;
            Buffer.BlockCopy(data, 0, pkt, 1, len);
        }
        Raw(c.ep, pkt, pkt.Length);
    }

    void Raw(IPEndPoint ep, byte[] pkt, int len)
    {
        try { sock.Send(pkt, len, ep); } catch (Exception e) { Debug.LogWarning("UDP send: " + e.Message); }
    }

    public bool Receive(out int peer, out byte[] data)
    {
        if (inbox.Count > 0) { var x = inbox.Dequeue(); peer = x.Item1; data = x.Item2; return true; }
        peer = -1; data = null; return false;
    }

    public void Tick()
    {
        float now = Time.unscaledTime;
        // приём
        for (int guard = 0; guard < 2000; guard++)
        {
            byte[] pkt; IPEndPoint from = new IPEndPoint(IPAddress.Any, 0);
            try { if (sock.Available <= 0) break; pkt = sock.Receive(ref from); }
            catch (SocketException) { break; }
            catch (ObjectDisposedException) { return; }
            if (pkt == null || pkt.Length < 1) continue;
            string key = from.ToString();
            if (!byAddr.TryGetValue(key, out int pid))
            {
                if (!host || pkt[0] != HELLO) continue;
                pid = nextPeer++;
                conns[pid] = new Conn { ep = from, lastHeard = now };
                byAddr[key] = pid; peers.Add(pid);
            }
            var c = conns[pid];
            c.lastHeard = now;
            switch (pkt[0])
            {
                case U: { var d = new byte[pkt.Length - 1]; Buffer.BlockCopy(pkt, 1, d, 0, d.Length); inbox.Enqueue((pid, d)); break; }
                case R:
                {
                    if (pkt.Length < 3) break;
                    ushort seq = (ushort)(pkt[1] | (pkt[2] << 8));
                    Raw(c.ep, new byte[] { ACK, pkt[1], pkt[2] }, 3);
                    short diff = (short)(seq - c.inNext);
                    if (diff < 0) break;   // уже было
                    var d = new byte[pkt.Length - 3]; Buffer.BlockCopy(pkt, 3, d, 0, d.Length);
                    if (diff > 0) { c.early[seq] = d; break; }
                    inbox.Enqueue((pid, d)); c.inNext++;
                    while (c.early.TryGetValue(c.inNext, out var nx)) { c.early.Remove(c.inNext); inbox.Enqueue((pid, nx)); c.inNext++; }
                    break;
                }
                case ACK: if (pkt.Length >= 3) c.unacked.Remove((ushort)(pkt[1] | (pkt[2] << 8))); break;
                case BYE: Drop(pid); break;
            }
        }
        // повторы и проверка связи
        var dead = new List<int>();
        foreach (var kv in conns)
        {
            var c = kv.Value;
            var resend = new List<ushort>();
            foreach (var u in c.unacked) if (now - u.Value.sent > 0.2f) resend.Add(u.Key);
            foreach (var s in resend) { var u = c.unacked[s]; Raw(c.ep, u.data, u.data.Length); c.unacked[s] = (u.data, now); }
            if (now - c.lastHeard > 15f) dead.Add(kv.Key);
        }
        foreach (var d in dead) Drop(d);
        // клиент стучится, пока хост не ответил, и держит канал живым
        if (!host && now > helloT && conns.TryGetValue(0, out var hc)) { helloT = now + 0.5f; Raw(hc.ep, new byte[] { HELLO }, 1); }
        if (host && now > helloT) { helloT = now + 0.5f; foreach (var kv in conns) Raw(kv.Value.ep, new byte[] { HELLO }, 1); }
    }

    void Drop(int pid)
    {
        if (!conns.TryGetValue(pid, out var c)) return;
        conns.Remove(pid); byAddr.Remove(c.ep.ToString()); peers.Remove(pid);
        dropped.Add(pid);
    }

    public void Close()
    {
        foreach (var kv in conns) Raw(kv.Value.ep, new byte[] { BYE }, 1);
        try { sock.Close(); } catch { }
        conns.Clear(); peers.Clear();
    }
}
