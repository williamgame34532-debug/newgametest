package com.williamgame.hideandhunt.network;

import com.williamgame.hideandhunt.game.GameManager;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.network.CustomPayloadEvent;

/** Taunt key pressed by a hider. */
public record TauntPacket(int unused) {
    public static void encode(TauntPacket m, FriendlyByteBuf buf) {
        buf.writeVarInt(m.unused);
    }

    public static TauntPacket decode(FriendlyByteBuf buf) {
        return new TauntPacket(buf.readVarInt());
    }

    public static void handle(TauntPacket m, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            ServerPlayer player = ctx.getSender();
            if (player != null) {
                GameManager.get(player.server).taunt(player);
            }
        });
        ctx.setPacketHandled(true);
    }
}
