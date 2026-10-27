package com.williamgame.echoesofsleep.network;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

/** Server -> client: the Distortion state of the dimension the player is in. */
public record DistortionSyncPacket(int level, int ticksLeft, int totalTicks) {
    public static void encode(DistortionSyncPacket msg, FriendlyByteBuf buf) {
        buf.writeVarInt(msg.level);
        buf.writeVarInt(msg.ticksLeft);
        buf.writeVarInt(msg.totalTicks);
    }

    public static DistortionSyncPacket decode(FriendlyByteBuf buf) {
        return new DistortionSyncPacket(buf.readVarInt(), buf.readVarInt(), buf.readVarInt());
    }

    public static void handle(DistortionSyncPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.echoesofsleep.client.ClientHooks.onDistortionSync(msg.level, msg.ticksLeft, msg.totalTicks);
            }
        });
        ctx.setPacketHandled(true);
    }
}
