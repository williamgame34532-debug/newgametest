#if !(UNITY_STANDALONE_WIN || UNITY_STANDALONE_LINUX || UNITY_STANDALONE_OSX || STEAMWORKS_WIN || STEAMWORKS_LIN_OSX)
#define DISABLESTEAMWORKS
#endif
using System.Collections.Generic;
using UnityEngine;
#if !DISABLESTEAMWORKS
using Steamworks;
#endif

// Steam: лобби «только для друзей», приглашение через оверлей Steam (Shift+Tab), присоединение по приглашению,
// обмен пакетами P2P через серверы Steam (без открытия портов). Нужен запущенный Steam.
// Пока у игры нет своего AppID, используется тестовый 480 (Spacewar) — файл steam_appid.txt рядом с игрой.
public static class SteamNet
{
#if DISABLESTEAMWORKS
    public static bool Ready => false;
    public static string PersonaName => null;
    public static string Error = "Steam недоступен на этой платформе";
    public static void Init() { }
    public static void RunCallbacks() { }
    public static void Shutdown() { }
    public static void LeaveLobby() { }
    public static void InviteFriends() { }
    public static INetTransport CreateHost() => null;
#else
    public static bool Ready { get; private set; }
    public static string Error;
    static bool tried;
    static Callback<GameLobbyJoinRequested_t> cbJoinReq;
    static Callback<P2PSessionRequest_t> cbSession;
    static Callback<LobbyChatUpdate_t> cbChat;
    static CallResult<LobbyCreated_t> crCreated;
    static CallResult<LobbyEnter_t> crEnter;
    public static CSteamID Lobby = CSteamID.Nil;
    static SteamTransport current;

    public static string PersonaName { get { Init(); return Ready ? SteamFriends.GetPersonaName() : null; } }

    public static void Init()
    {
        if (tried) return;
        tried = true;
        try
        {
            if (!Packsize.Test() || !DllCheck.Test()) { Error = "Неверная версия Steamworks"; return; }
            Ready = SteamAPI.Init();
            if (!Ready) { Error = "Steam не запущен (или нет steam_appid.txt)"; return; }
            cbJoinReq = Callback<GameLobbyJoinRequested_t>.Create(OnJoinRequested);
            cbSession = Callback<P2PSessionRequest_t>.Create(r => SteamNetworking.AcceptP2PSessionWithUser(r.m_steamIDRemote));
            cbChat = Callback<LobbyChatUpdate_t>.Create(OnLobbyChat);
            crCreated = CallResult<LobbyCreated_t>.Create(OnCreated);
            crEnter = CallResult<LobbyEnter_t>.Create(OnEnter);
            // игра запущена из приглашения Steam: +connect_lobby <id>
            var args = System.Environment.GetCommandLineArgs();
            for (int i = 0; i + 1 < args.Length; i++)
                if (args[i] == "+connect_lobby" && ulong.TryParse(args[i + 1], out ulong lid))
                    crEnter.Set(SteamMatchmaking.JoinLobby(new CSteamID(lid)));
        }
        catch (System.Exception e) { Ready = false; Error = "Steam: " + e.Message; }
    }

    public static void RunCallbacks() { if (Ready) { try { SteamAPI.RunCallbacks(); } catch { } } }
    public static void Shutdown() { if (Ready) { LeaveLobby(); SteamAPI.Shutdown(); Ready = false; } }

    public static void LeaveLobby()
    {
        if (!Ready || Lobby == CSteamID.Nil) return;
        SteamMatchmaking.LeaveLobby(Lobby);
        Lobby = CSteamID.Nil;
    }

    public static void InviteFriends()
    {
        if (Ready && Lobby != CSteamID.Nil) SteamFriends.ActivateGameOverlayInviteDialog(Lobby);
    }

    public static INetTransport CreateHost()
    {
        Init();
        if (!Ready) return null;
        current = new SteamTransport(true, CSteamID.Nil);
        crCreated.Set(SteamMatchmaking.CreateLobby(ELobbyType.k_ELobbyTypeFriendsOnly, 8));
        return current;
    }

    static void OnCreated(LobbyCreated_t r, bool fail)
    {
        if (fail || r.m_eResult != EResult.k_EResultOK) { Net.Status = "Steam: лобби не создано (" + r.m_eResult + ")"; return; }
        Lobby = new CSteamID(r.m_ulSteamIDLobby);
        SteamMatchmaking.SetLobbyData(Lobby, "game", "scp-foundation-wars");
        Net.Status = "Лобби Steam создано — пригласите друзей (кнопка или Shift+Tab)";
    }

    // Друг нажал «Присоединиться» / принял приглашение
    static void OnJoinRequested(GameLobbyJoinRequested_t r)
    {
        if (Net.InGame) return;
        crEnter.Set(SteamMatchmaking.JoinLobby(r.m_steamIDLobby));
        Net.Status = "Вход в лобби друга…";
    }

    static void OnEnter(LobbyEnter_t r, bool fail)
    {
        if (fail) { Net.Status = "Не удалось войти в лобби"; return; }
        Lobby = new CSteamID(r.m_ulSteamIDLobby);
        var owner = SteamMatchmaking.GetLobbyOwner(Lobby);
        if (owner == SteamUser.GetSteamID()) return;   // своё лобби
        current = new SteamTransport(false, owner);
        Net.JoinSteam(current);
        Game.I.ShowNetLobby();
    }

    static void OnLobbyChat(LobbyChatUpdate_t r)
    {
        // кто-то вышел из лобби — транспорт сам заметит по тишине
    }

    // ---------------- транспорт поверх Steam P2P ----------------
    public class SteamTransport : INetTransport
    {
        readonly bool host;
        readonly Dictionary<int, CSteamID> ids = new Dictionary<int, CSteamID>();
        readonly Dictionary<ulong, int> peerOf = new Dictionary<ulong, int>();
        readonly Dictionary<int, float> heard = new Dictionary<int, float>();
        readonly List<int> peers = new List<int>();
        readonly List<int> dropped = new List<int>();
        readonly Queue<(int, byte[])> inbox = new Queue<(int, byte[])>();
        int nextPeer = 1;
        byte[] buf = new byte[1 << 16];
        float pingT;

        public SteamTransport(bool isHost, CSteamID hostId)
        {
            host = isHost;
            if (!host) { ids[0] = hostId; peerOf[hostId.m_SteamID] = 0; peers.Add(0); heard[0] = Time.unscaledTime; }
        }

        public bool IsHost => host;
        public List<int> Peers => peers;
        public List<int> Dropped => dropped;
        public string Describe => "Steam (друзья)";

        public void Send(int peer, byte[] data, int len, bool reliable)
        {
            if (peer < 0) { foreach (var p in peers) Send(p, data, len, reliable); return; }
            if (!ids.TryGetValue(peer, out var id)) return;
            var type = reliable ? EP2PSend.k_EP2PSendReliable : (len <= 1200 ? EP2PSend.k_EP2PSendUnreliableNoDelay : EP2PSend.k_EP2PSendReliable);
            byte[] d = data;
            if (data.Length != len) { d = new byte[len]; System.Buffer.BlockCopy(data, 0, d, 0, len); }
            SteamNetworking.SendP2PPacket(id, d, (uint)len, type, 0);
        }

        public bool Receive(out int peer, out byte[] data)
        {
            if (inbox.Count > 0) { var x = inbox.Dequeue(); peer = x.Item1; data = x.Item2; return true; }
            peer = -1; data = null; return false;
        }

        public void Tick()
        {
            float now = Time.unscaledTime;
            for (int guard = 0; guard < 4000 && SteamNetworking.IsP2PPacketAvailable(out uint size, 0); guard++)
            {
                if (size > buf.Length) buf = new byte[size];
                if (!SteamNetworking.ReadP2PPacket(buf, size, out uint got, out CSteamID from, 0)) break;
                if (!peerOf.TryGetValue(from.m_SteamID, out int pid))
                {
                    if (!host) continue;
                    pid = nextPeer++;
                    peerOf[from.m_SteamID] = pid; ids[pid] = from; peers.Add(pid);
                }
                heard[pid] = now;
                if (got == 1 && buf[0] == 0) continue;   // проверка связи
                var d = new byte[got]; System.Buffer.BlockCopy(buf, 0, d, 0, (int)got);
                inbox.Enqueue((pid, d));
            }
            if (now > pingT)
            {
                pingT = now + 1f;
                foreach (var kv in ids) SteamNetworking.SendP2PPacket(kv.Value, new byte[] { 0 }, 1, EP2PSend.k_EP2PSendUnreliableNoDelay, 0);
                var dead = new List<int>();
                foreach (var kv in heard) if (now - kv.Value > 20f) dead.Add(kv.Key);
                foreach (var p in dead) Drop(p);
            }
        }

        void Drop(int p)
        {
            if (!ids.TryGetValue(p, out var id)) return;
            SteamNetworking.CloseP2PSessionWithUser(id);
            ids.Remove(p); peerOf.Remove(id.m_SteamID); heard.Remove(p); peers.Remove(p);
            dropped.Add(p);
        }

        public void Close()
        {
            foreach (var kv in ids) SteamNetworking.CloseP2PSessionWithUser(kv.Value);
            ids.Clear(); peers.Clear();
        }
    }
#endif
}
