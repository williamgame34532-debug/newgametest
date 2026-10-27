package com.williamgame.hideandhunt.network;

import com.williamgame.hideandhunt.game.GameManager;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.network.CustomPayloadEvent;

/** A change requested from the tablet GUI. The server re-checks operator permission before applying it. */
public record TabletActionPacket(String action, String key, String value) {
    public static void encode(TabletActionPacket m, FriendlyByteBuf buf) {
        buf.writeUtf(m.action, 32);
        buf.writeUtf(m.key, 64);
        buf.writeUtf(m.value, 64);
    }

    public static TabletActionPacket decode(FriendlyByteBuf buf) {
        return new TabletActionPacket(buf.readUtf(32), buf.readUtf(64), buf.readUtf(64));
    }

    public static void handle(TabletActionPacket m, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            ServerPlayer player = ctx.getSender();
            if (player != null) {
                GameManager.get(player.server).handleTabletAction(player, m.action, m.key, m.value);
            }
        });
        ctx.setPacketHandled(true);
    }
}
