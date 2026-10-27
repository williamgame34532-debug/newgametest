package com.williamgame.hideandhunt.game;

import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;

public enum Phase {
    LOBBY, COUNTDOWN, HIDING, HUNTING, ENDING;

    public boolean inRound() {
        return this == HIDING || this == HUNTING || this == ENDING;
    }

    public MutableComponent displayName() {
        return Component.translatable("hideandhunt.phase." + name().toLowerCase(java.util.Locale.ROOT));
    }

    public static Phase byOrdinal(int i) {
        Phase[] v = values();
        return i >= 0 && i < v.length ? v[i] : LOBBY;
    }
}
