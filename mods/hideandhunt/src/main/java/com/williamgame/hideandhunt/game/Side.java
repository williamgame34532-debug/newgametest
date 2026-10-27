package com.williamgame.hideandhunt.game;

import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;

/** Side of a player. In the lobby SPECTATOR means "opted out / watching"; in a round it means "eliminated". */
public enum Side {
    NONE("none", ChatFormatting.WHITE, 0xFFDDDDDD),
    HIDER("hider", ChatFormatting.GREEN, 0xFF55FF7F),
    HUNTER("hunter", ChatFormatting.RED, 0xFFFF5555),
    SPECTATOR("spectator", ChatFormatting.GRAY, 0xFFAAAAAA);

    public final String id;
    public final ChatFormatting color;
    public final int argb;

    Side(String id, ChatFormatting color, int argb) {
        this.id = id;
        this.color = color;
        this.argb = argb;
    }

    public MutableComponent displayName() {
        return Component.translatable("hideandhunt.side." + id).withStyle(color);
    }

    public MutableComponent pluralName() {
        return Component.translatable("hideandhunt.side." + id + ".plural").withStyle(color);
    }

    public static Side byOrdinal(int i) {
        Side[] v = values();
        return i >= 0 && i < v.length ? v[i] : NONE;
    }

    /** Accepts hider/hiders/hunter/hunters/none/spectator/spec. */
    public static Side parse(String s) {
        if (s == null) return null;
        switch (s.toLowerCase(java.util.Locale.ROOT)) {
            case "hider": case "hiders": return HIDER;
            case "hunter": case "hunters": case "seeker": case "seekers": return HUNTER;
            case "none": case "leave": return NONE;
            case "spectator": case "spectators": case "spec": return SPECTATOR;
            default: return null;
        }
    }
}
