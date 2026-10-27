package com.williamgame.hideandhunt.game;

import net.minecraft.nbt.CompoundTag;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * All tweakable rules of an arena. Generic key/value storage so that the command, the tablet GUI,
 * NBT and the network all share a single list of definitions. Booleans are stored as 0/1, choices as index.
 * Common code: used by both the server and the client screen (no client imports here).
 */
public final class GameSettings {
    public enum Kind { INT, BOOL, CHOICE }

    public enum Tab { ARENA, TEAMS, TIMERS, RULES }

    public record Def(String key, Kind kind, Tab tab, int def, int min, int max, List<String> choices, String unit) {
        public String langKey() {
            return "hideandhunt.setting." + key;
        }

        public String descKey() {
            return "hideandhunt.setting." + key + ".desc";
        }

        public String choiceLangKey(int index) {
            return "hideandhunt.choice." + key + "." + choices.get(index);
        }
    }

    // keys
    public static final String JOIN_MODE = "join_mode";
    public static final String MODE = "mode";
    public static final String HUNTER_RATIO = "hunter_ratio";
    public static final String MIN_PLAYERS = "min_players";
    public static final String MAX_HIDERS = "max_hiders";
    public static final String MAX_HUNTERS = "max_hunters";
    public static final String AUTO_ASSIGN = "auto_assign";
    public static final String AUTO_BALANCE = "auto_balance";
    public static final String BALANCE_CHECK = "balance_check";
    public static final String RESET_TEAMS = "reset_teams";
    public static final String BUTTONS_OP_ONLY = "buttons_op_only";
    public static final String COUNTDOWN = "countdown";
    public static final String HIDE_TIME = "hide_time";
    public static final String HUNT_TIME = "hunt_time";
    public static final String HINT_INTERVAL = "hint_interval";
    public static final String GLOW_LAST = "glow_last";
    public static final String TAUNT_COOLDOWN = "taunt_cooldown";
    public static final String RESULTS_TIME = "results_time";
    public static final String BOUNDARY_GRACE = "boundary_grace";
    public static final String HUNTER_SPEED = "hunter_speed";
    public static final String TAUNT_POINTS = "taunt_points";
    public static final String TAUNTS = "taunts";
    public static final String FRIENDLY_FIRE = "friendly_fire";
    public static final String KEEP_INVENTORY = "keep_inventory";
    public static final String ADVENTURE = "adventure";
    public static final String ENV_DAMAGE = "env_damage";
    public static final String FREEZE_HUNTERS = "freeze_hunters";
    public static final String BLIND_HUNTERS = "blind_hunters";
    public static final String HIDE_NAMETAGS = "hide_nametags";
    public static final String SIDEBAR = "sidebar";
    public static final String LAST_HIDER_GLOW = "last_hider_glow";

    public static final List<Def> DEFS;
    private static final Map<String, Def> BY_KEY = new LinkedHashMap<>();

    static {
        List<Def> d = new ArrayList<>();
        // arena
        d.add(choice(JOIN_MODE, Tab.ARENA, 0, "free", "pads", "random", "admin"));
        d.add(choice(MODE, Tab.ARENA, 0, "classic", "infection"));
        // teams
        d.add(intDef(HUNTER_RATIO, Tab.TEAMS, 4, 1, 20, ""));
        d.add(intDef(MIN_PLAYERS, Tab.TEAMS, 2, 2, 64, ""));
        d.add(intDef(MAX_HIDERS, Tab.TEAMS, 0, 0, 64, ""));
        d.add(intDef(MAX_HUNTERS, Tab.TEAMS, 0, 0, 64, ""));
        d.add(bool(AUTO_ASSIGN, Tab.TEAMS, true));
        d.add(bool(AUTO_BALANCE, Tab.TEAMS, true));
        d.add(bool(BALANCE_CHECK, Tab.TEAMS, true));
        d.add(bool(RESET_TEAMS, Tab.TEAMS, true));
        d.add(bool(BUTTONS_OP_ONLY, Tab.TEAMS, false));
        // timers
        d.add(intDef(COUNTDOWN, Tab.TIMERS, 10, 3, 60, "s"));
        d.add(intDef(HIDE_TIME, Tab.TIMERS, 45, 5, 600, "s"));
        d.add(intDef(HUNT_TIME, Tab.TIMERS, 300, 30, 3600, "s"));
        d.add(intDef(HINT_INTERVAL, Tab.TIMERS, 60, 0, 300, "s"));
        d.add(intDef(GLOW_LAST, Tab.TIMERS, 30, 0, 600, "s"));
        d.add(intDef(TAUNT_COOLDOWN, Tab.TIMERS, 20, 3, 300, "s"));
        d.add(intDef(RESULTS_TIME, Tab.TIMERS, 10, 3, 60, "s"));
        d.add(intDef(BOUNDARY_GRACE, Tab.TIMERS, 3, 0, 30, "s"));
        // rules
        d.add(intDef(HUNTER_SPEED, Tab.RULES, 1, 0, 4, ""));
        d.add(intDef(TAUNT_POINTS, Tab.RULES, 5, 0, 100, ""));
        d.add(bool(TAUNTS, Tab.RULES, true));
        d.add(bool(FRIENDLY_FIRE, Tab.RULES, false));
        d.add(bool(KEEP_INVENTORY, Tab.RULES, false));
        d.add(bool(ADVENTURE, Tab.RULES, true));
        d.add(bool(ENV_DAMAGE, Tab.RULES, false));
        d.add(bool(FREEZE_HUNTERS, Tab.RULES, true));
        d.add(bool(BLIND_HUNTERS, Tab.RULES, true));
        d.add(bool(HIDE_NAMETAGS, Tab.RULES, true));
        d.add(bool(LAST_HIDER_GLOW, Tab.RULES, true));
        d.add(bool(SIDEBAR, Tab.RULES, false));
        DEFS = Collections.unmodifiableList(d);
        for (Def def : DEFS) BY_KEY.put(def.key(), def);
    }

    private static Def intDef(String key, Tab tab, int def, int min, int max, String unit) {
        return new Def(key, Kind.INT, tab, def, min, max, List.of(), unit);
    }

    private static Def bool(String key, Tab tab, boolean def) {
        return new Def(key, Kind.BOOL, tab, def ? 1 : 0, 0, 1, List.of(), "");
    }

    private static Def choice(String key, Tab tab, int def, String... choices) {
        return new Def(key, Kind.CHOICE, tab, def, 0, choices.length - 1, List.of(choices), "");
    }

    public static Def def(String key) {
        return BY_KEY.get(key);
    }

    public static List<Def> defs(Tab tab) {
        List<Def> out = new ArrayList<>();
        for (Def d : DEFS) if (d.tab() == tab) out.add(d);
        return out;
    }

    // ---------------------------------------------------------------- instance

    private final Map<String, Integer> values = new LinkedHashMap<>();

    public GameSettings() {
        resetToDefaults();
    }

    public void resetToDefaults() {
        values.clear();
        for (Def d : DEFS) values.put(d.key(), d.def());
    }

    public int getInt(String key) {
        Integer v = values.get(key);
        if (v != null) return v;
        Def d = BY_KEY.get(key);
        return d == null ? 0 : d.def();
    }

    public boolean getBool(String key) {
        return getInt(key) != 0;
    }

    public String getChoice(String key) {
        Def d = BY_KEY.get(key);
        if (d == null || d.kind() != Kind.CHOICE) return "";
        int i = Math.max(0, Math.min(d.choices().size() - 1, getInt(key)));
        return d.choices().get(i);
    }

    public void setRaw(String key, int value) {
        Def d = BY_KEY.get(key);
        if (d == null) return;
        values.put(key, Math.max(d.min(), Math.min(d.max(), value)));
    }

    /** Parses a user/GUI provided value. Returns false if the key or value is invalid. */
    public boolean set(String key, String value) {
        Def d = BY_KEY.get(key);
        if (d == null || value == null) return false;
        String v = value.trim().toLowerCase(Locale.ROOT);
        switch (d.kind()) {
            case BOOL -> {
                if (v.equals("true") || v.equals("on") || v.equals("1") || v.equals("yes")) setRaw(key, 1);
                else if (v.equals("false") || v.equals("off") || v.equals("0") || v.equals("no")) setRaw(key, 0);
                else if (v.equals("toggle")) setRaw(key, getBool(key) ? 0 : 1);
                else return false;
                return true;
            }
            case CHOICE -> {
                int idx = d.choices().indexOf(v);
                if (idx < 0) {
                    if (v.equals("next")) idx = (getInt(key) + 1) % d.choices().size();
                    else return false;
                }
                setRaw(key, idx);
                return true;
            }
            default -> {
                try {
                    int n = Integer.parseInt(v);
                    if (n < d.min() || n > d.max()) return false;
                    setRaw(key, n);
                    return true;
                } catch (NumberFormatException e) {
                    return false;
                }
            }
        }
    }

    /** Value as a plain string (true/false, choice id or number). */
    public String valueString(String key) {
        Def d = BY_KEY.get(key);
        if (d == null) return "?";
        return switch (d.kind()) {
            case BOOL -> getBool(key) ? "true" : "false";
            case CHOICE -> getChoice(key);
            default -> String.valueOf(getInt(key));
        };
    }

    public CompoundTag save() {
        CompoundTag t = new CompoundTag();
        for (Map.Entry<String, Integer> e : values.entrySet()) t.putInt(e.getKey(), e.getValue());
        return t;
    }

    public void load(CompoundTag t) {
        resetToDefaults();
        for (Def d : DEFS) {
            if (t.contains(d.key())) setRaw(d.key(), t.getInt(d.key()));
        }
    }

    public static GameSettings fromTag(CompoundTag t) {
        GameSettings s = new GameSettings();
        s.load(t);
        return s;
    }

    // ---------------------------------------------------------------- typed helpers

    public JoinMode joinMode() {
        return JoinMode.byId(getChoice(JOIN_MODE));
    }

    public boolean infection() {
        return "infection".equals(getChoice(MODE));
    }

    public enum JoinMode {
        FREE, PADS, RANDOM, ADMIN;

        public static JoinMode byId(String id) {
            for (JoinMode m : values()) if (m.name().equalsIgnoreCase(id)) return m;
            return FREE;
        }
    }
}
