package com.williamgame.modcritic.network;

import com.williamgame.modcritic.CriticSavedData;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.network.CustomPayloadEvent;

/** Client -> server: please send me everybody's ratings. */
public record RequestResultsPacket(int unused) {
    public static void encode(RequestResultsPacket msg, FriendlyByteBuf buf) {
        buf.writeVarInt(msg.unused);
    }

    public static RequestResultsPacket decode(FriendlyByteBuf buf) {
        return new RequestResultsPacket(buf.readVarInt());
    }

    public static void handle(RequestResultsPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            ServerPlayer player = ctx.getSender();
            if (player == null) return;
            CriticNetwork.sendTo(player, CriticSavedData.get(player.server).toPacket());
        });
        ctx.setPacketHandled(true);
    }
}
