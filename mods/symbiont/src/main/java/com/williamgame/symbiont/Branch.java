package com.williamgame.symbiont;

/** The four evolution branches. Index is stored in player data. */
public enum Branch {
    MINER("miner", 0xFFB347),
    WARRIOR("warrior", 0xE0414B),
    FARMER("farmer", 0x7CC46A),
    EXPLORER("explorer", 0x6EC3F5);

    public final String id;
    public final int color;

    Branch(String id, int color) {
        this.id = id;
        this.color = color;
    }

    public static Branch byIndex(int i) {
        Branch[] v = values();
        return i >= 0 && i < v.length ? v[i] : null;
    }

    public static Branch byName(String s) {
        for (Branch b : values()) {
            if (b.id.equalsIgnoreCase(s)) return b;
        }
        return null;
    }

    public String translationKey() {
        return "symbiont.branch." + id;
    }
}
