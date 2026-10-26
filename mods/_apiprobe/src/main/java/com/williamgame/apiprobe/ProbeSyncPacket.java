package com.williamgame.apiprobe;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

public record ProbeSyncPacket(int value, String text) {
    public static void encode(ProbeSyncPacket msg, FriendlyByteBuf buf) {
        buf.writeVarInt(msg.value);
        buf.writeUtf(msg.text);
    }

    public static ProbeSyncPacket decode(FriendlyByteBuf buf) {
        return new ProbeSyncPacket(buf.readVarInt(), buf.readUtf());
    }

    public static void handle(ProbeSyncPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.apiprobe.client.ClientHooks.onSync(msg.value, msg.text);
            }
        });
        ctx.setPacketHandled(true);
    }
}
