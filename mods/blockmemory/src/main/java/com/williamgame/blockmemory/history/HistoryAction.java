package com.williamgame.blockmemory.history;

public enum HistoryAction {
    PLACED, BROKEN, EXPLODED, RESTORED, ANCIENT;

    public static HistoryAction byId(int id) {
        HistoryAction[] v = values();
        return id >= 0 && id < v.length ? v[id] : BROKEN;
    }

    public boolean isRemoval() {
        return this == BROKEN || this == EXPLODED;
    }

    public String key() {
        return "blockmemory.action." + name().toLowerCase(java.util.Locale.ROOT);
    }
}
