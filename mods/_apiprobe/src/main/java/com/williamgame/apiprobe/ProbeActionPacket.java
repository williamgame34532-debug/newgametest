package com.williamgame.apiprobe;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.network.CustomPayloadEvent;

public record ProbeActionPacket(int action) {
    public static void encode(ProbeActionPacket msg, FriendlyByteBuf buf) {
        buf.writeVarInt(msg.action);
    }

    public static ProbeActionPacket decode(FriendlyByteBuf buf) {
        return new ProbeActionPacket(buf.readVarInt());
    }

    public static void handle(ProbeActionPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            ServerPlayer player = ctx.getSender();
            if (player != null) {
                player.displayClientMessage(net.minecraft.network.chat.Component.literal("action " + msg.action), true);
            }
        });
        ctx.setPacketHandled(true);
    }
}
