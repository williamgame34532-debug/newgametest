using System.Collections.Generic;
using UnityEngine;

namespace StickWars
{
    // Приём: позы, тайминги, урон, отбрасывание и продолжения комбо.
    public class Move
    {
        public string name;
        public Pose w, s;
        public float dur = 0.35f, hitAt = 0.45f, reach = 1f, dmg = 6f, stun = 0.2f;
        public Vector2 knock = new Vector2(3f, 1f);
        public int limb;               // 0 кисть(п) 1 кисть(з) 2 стопа(п) 3 стопа(з) 4 оружие
        public bool high, low, launcher, slam, knockdown, air, weapon, stab, flip, cleave, heavy;
        public float lunge, hopX, hopY, spin;
        public string sfx = "punch";
        public Move[] next = new Move[0];

        public static Move Jab, Cross, Hook, Upper, Knee, FrontKick, Roundhouse, SpinKick, Sweep, FlyKick, AirPunch, AirKick, DiveKick;
        public static Move Slash, Rise, SpinSlash, Thrust, Overhead, AirSlash, AirSmash;

        static Move M(string n, Pose w, Pose s, float dur, float reach, float dmg, float kx, float ky, int limb)
        {
            return new Move { name = n, w = w, s = s, dur = dur, reach = reach, dmg = dmg, knock = new Vector2(kx, ky), limb = limb };
        }

        static Move()
        {
            Jab = M("Джеб", Pose.JabW, Pose.JabS, 0.24f, 0.95f, 5f, 2f, 0.5f, 0); Jab.stun = 0.18f; Jab.lunge = 3f;
            Cross = M("Кросс", Pose.Punch2W, Pose.Punch2S, 0.28f, 1.0f, 7f, 3.5f, 1f, 1); Cross.lunge = 4f;
            Hook = M("Хук", Pose.HookW, Pose.HookS, 0.32f, 0.95f, 8f, 3.5f, 1.5f, 0); Hook.high = true;
            Upper = M("Апперкот", Pose.UpperW, Pose.UpperS, 0.38f, 0.95f, 9f, 1.5f, 12.5f, 0); Upper.launcher = true; Upper.high = true; Upper.hopY = 3f; Upper.sfx = "kick";
            Knee = M("Колено", Pose.KneeW, Pose.KneeS, 0.3f, 0.8f, 8f, 2f, 3f, 2); Knee.lunge = 3f;
            FrontKick = M("Прямой пинок", Pose.KickW, Pose.KickS, 0.38f, 1.2f, 9f, 8f, 1.5f, 2); FrontKick.sfx = "kick";
            Roundhouse = M("Хай-кик", Pose.RoundW, Pose.RoundS, 0.42f, 1.15f, 11f, 6.5f, 3.5f, 2); Roundhouse.high = true; Roundhouse.sfx = "kick";
            SpinKick = M("Вертушка", Pose.RoundW, Pose.RoundS, 0.52f, 1.25f, 13f, 10f, 5f, 2); SpinKick.high = true; SpinKick.flip = true; SpinKick.knockdown = true; SpinKick.heavy = true; SpinKick.sfx = "kick";
            Sweep = M("Подсечка", Pose.SweepW, Pose.SweepS, 0.4f, 1.15f, 7f, 2f, 4.5f, 2); Sweep.low = true; Sweep.knockdown = true; Sweep.sfx = "kick";
            FlyKick = M("Удар в прыжке", Pose.FlyKickW, Pose.FlyKickS, 0.55f, 1.25f, 12f, 11f, 3f, 2); FlyKick.hopX = 9f; FlyKick.hopY = 7.5f; FlyKick.knockdown = true; FlyKick.heavy = true; FlyKick.air = true; FlyKick.sfx = "kick";
            AirPunch = M("Удар в воздухе", Pose.FlyKickW, Pose.AirPunchS, 0.28f, 1.0f, 7f, 3f, 4f, 0); AirPunch.air = true;
            AirKick = M("Пинок в воздухе", Pose.FlyKickW, Pose.FlyKickS, 0.32f, 1.2f, 8f, 4f, 3.5f, 2); AirKick.air = true; AirKick.sfx = "kick";
            DiveKick = M("Пике", Pose.DiveW, Pose.DiveS, 0.42f, 1.2f, 12f, 3f, -16f, 2); DiveKick.air = true; DiveKick.slam = true; DiveKick.knockdown = true; DiveKick.heavy = true; DiveKick.sfx = "kick";

            Slash = M("Рубящий", Pose.SlashW, Pose.SlashS, 0.42f, 1f, 1f, 4.5f, 1.2f, 4); Slash.weapon = true; Slash.lunge = 3f; Slash.sfx = "slash";
            Rise = M("Подброс", Pose.RiseW, Pose.RiseS, 0.44f, 1f, 1.1f, 1.5f, 13f, 4); Rise.weapon = true; Rise.launcher = true; Rise.high = true; Rise.sfx = "slash";
            SpinSlash = M("Круговой", Pose.SpinSlashW, Pose.SpinSlashS, 0.55f, 1.05f, 1.3f, 9f, 4f, 4); SpinSlash.weapon = true; SpinSlash.flip = true; SpinSlash.cleave = true; SpinSlash.knockdown = true; SpinSlash.heavy = true; SpinSlash.sfx = "slash";
            Thrust = M("Выпад", Pose.StabW, Pose.StabS, 0.42f, 1.15f, 1.1f, 6f, 1f, 4); Thrust.weapon = true; Thrust.stab = true; Thrust.lunge = 9f; Thrust.sfx = "slash";
            Overhead = M("Сверху", Pose.SmashW, Pose.SmashS, 0.58f, 1f, 1.45f, 4f, 7f, 4); Overhead.weapon = true; Overhead.knockdown = true; Overhead.heavy = true; Overhead.slam = true; Overhead.sfx = "whoosh";
            AirSlash = M("Воздушный удар", Pose.SlashW, Pose.SlashS, 0.36f, 1f, 0.9f, 3f, 4f, 4); AirSlash.weapon = true; AirSlash.air = true; AirSlash.sfx = "slash";
            AirSmash = M("Удар вниз", Pose.SmashW, Pose.SmashS, 0.45f, 1f, 1.3f, 2f, -16f, 4); AirSmash.weapon = true; AirSmash.air = true; AirSmash.slam = true; AirSmash.knockdown = true; AirSmash.heavy = true; AirSmash.sfx = "whoosh";

            Jab.next = new[] { Cross, Jab, Knee };
            Cross.next = new[] { Hook, Upper, FrontKick };
            Hook.next = new[] { Upper, Roundhouse, SpinKick };
            Knee.next = new[] { Upper, Hook };
            FrontKick.next = new[] { Roundhouse, SpinKick, Sweep };
            Roundhouse.next = new[] { SpinKick, Sweep, Upper };
            AirPunch.next = new[] { AirKick, DiveKick };
            AirKick.next = new[] { AirPunch, DiveKick };
            Slash.next = new[] { Rise, Thrust, SpinSlash, Slash };
            Thrust.next = new[] { Slash, Overhead, SpinSlash };
            AirSlash.next = new[] { AirSmash, AirSlash };
        }

        public static Move Starter(Style st, bool kick, bool weapon, WeaponKind wk, bool air, bool wantHigh, bool wantLow)
        {
            if (weapon)
            {
                if (air) return Random.value < 0.5f ? AirSlash : AirSmash;
                if (wantHigh) return Random.value < 0.5f ? Rise : SpinSlash;
                switch (wk)
                {
                    case WeaponKind.Spear: return Random.value < 0.75f ? Thrust : SpinSlash;
                    case WeaponKind.Blunt: return Random.value < 0.6f ? Overhead : Slash;
                    case WeaponKind.Staff: return Random.value < 0.5f ? Thrust : Slash;
                }
                return Random.value < 0.7f ? Slash : Thrust;
            }
            if (air) return kick ? (Random.value < 0.5f ? AirKick : DiveKick) : AirPunch;
            if (wantLow) return Sweep;
            if (wantHigh) return kick ? (Random.value < 0.5f ? Roundhouse : SpinKick) : (Random.value < 0.5f ? Hook : Upper);
            if (kick)
            {
                if (st == Style.Acrobat && Random.value < 0.3f) return SpinKick;
                float r = Random.value;
                return r < 0.45f ? FrontKick : r < 0.8f ? Roundhouse : Sweep;
            }
            switch (st)
            {
                case Style.Boxer: return Random.value < 0.6f ? Jab : Hook;
                case Style.Brute: return Random.value < 0.5f ? Cross : Upper;
            }
            return Random.value < 0.7f ? Jab : Knee;
        }
    }
}
