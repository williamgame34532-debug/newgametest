package com.zone19.scp.world;

import com.zone19.scp.network.Net;
import com.zone19.scp.network.SkinSyncPacket;
import net.minecraft.server.level.ServerPlayer;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/** Server-side registry of who wears which personnel skin; mirrored to every client. */
public final class SkinManager {
    private static final Map<UUID, String> SKINS = new HashMap<>();

    public static void select(ServerPlayer player, String id) {
        GuardSkin skin = GuardSkin.byId(id);
        if (skin == null) return;
        if (skin == GuardSkin.DEFAULT) SKINS.remove(player.getUUID());
        else SKINS.put(player.getUUID(), skin.id());
        PlayerFlags.setString(player, "skin", skin.id());
        broadcast();
    }

    public static void onLogin(ServerPlayer player) {
        String saved = PlayerFlags.getString(player, "skin");
        GuardSkin skin = GuardSkin.byId(saved);
        if (skin != null && skin != GuardSkin.DEFAULT) SKINS.put(player.getUUID(), skin.id());
        broadcast();
    }

    public static void onLogout(ServerPlayer player) {
        SKINS.remove(player.getUUID());
        broadcast();
    }

    public static void clear() {
        SKINS.clear();
    }

    private static void broadcast() {
        Net.toAll(new SkinSyncPacket(new HashMap<>(SKINS)));
    }

    private SkinManager() {
    }
}
