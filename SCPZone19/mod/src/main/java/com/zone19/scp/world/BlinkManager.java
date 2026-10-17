package com.zone19.scp.world;

import com.zone19.scp.config.Zone19Config;
import com.zone19.scp.network.BlinkPacket;
import com.zone19.scp.network.Net;
import com.zone19.scp.registry.ModItems;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.player.Player;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Server-authoritative blinking, as in SCP - Containment Breach. While a player's eyes are
 * shut SCP-173 and SCP-096 treat them as not looking. A gas mask or eye drops slow the meter.
 */
public final class BlinkManager {
    public static final int BLINK_TICKS = 4;
    private static final int METER = 0, CLOSED = 1, DROPS = 2;
    private static final Map<UUID, int[]> STATE = new HashMap<>();

    private static int max() {
        return Zone19Config.COMMON.blinkInterval.get();
    }

    public static boolean isBlinking(Player p) {
        int[] s = STATE.get(p.getUUID());
        return s != null && s[CLOSED] > 0;
    }

    private static boolean applies(ServerPlayer p) {
        return Zone19Config.COMMON.blinkEnabled.get() && ZoneManager.isInZone(p) && !p.isCreative() && !p.isSpectator() && p.isAlive();
    }

    public static void tick(ServerPlayer p) {
        if (!applies(p)) {
            if (STATE.remove(p.getUUID()) != null) Net.toPlayer(p, new BlinkPacket(-1, 1, false));
            return;
        }
        int[] s = STATE.computeIfAbsent(p.getUUID(), k -> new int[]{max(), 0, 0});
        boolean justClosed = false;
        if (s[CLOSED] > 0) {
            s[CLOSED]--;
        } else {
            boolean slowed = s[DROPS] > 0 || p.getItemBySlot(EquipmentSlot.HEAD).is(ModItems.GAS_MASK.get());
            if (s[DROPS] > 0) s[DROPS]--;
            if (!slowed || p.tickCount % 2 == 0) s[METER]--;
            if (s[METER] <= 0) {
                s[CLOSED] = BLINK_TICKS;
                s[METER] = max();
                justClosed = true;
            }
        }
        if (justClosed || p.tickCount % 5 == 0 || s[CLOSED] == 1) {
            Net.toPlayer(p, new BlinkPacket(s[METER], max(), s[CLOSED] > 0));
        }
    }

    public static void blinkNow(ServerPlayer p) {
        if (!applies(p)) return;
        int[] s = STATE.computeIfAbsent(p.getUUID(), k -> new int[]{max(), 0, 0});
        if (s[CLOSED] > 0) return;
        s[CLOSED] = BLINK_TICKS;
        s[METER] = max();
        Net.toPlayer(p, new BlinkPacket(s[METER], max(), true));
    }

    public static void eyedrops(ServerPlayer p) {
        int[] s = STATE.computeIfAbsent(p.getUUID(), k -> new int[]{max(), 0, 0});
        s[METER] = max();
        s[DROPS] = 600;
    }

    public static void forget(UUID id) {
        STATE.remove(id);
    }

    public static void clear() {
        STATE.clear();
    }

    private BlinkManager() {
    }
}
