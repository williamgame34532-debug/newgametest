package com.zone19.scp.network;

import com.zone19.scp.world.BlinkManager;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.network.NetworkEvent;

import java.util.function.Supplier;

/** The player pressed the blink key: blink now and reset the meter on your own terms. */
public record BlinkNowPacket() {
    public void encode(FriendlyByteBuf buf) {
    }

    public static BlinkNowPacket decode(FriendlyByteBuf buf) {
        return new BlinkNowPacket();
    }

    public static void handle(BlinkNowPacket msg, Supplier<NetworkEvent.Context> ctx) {
        ServerPlayer player = ctx.get().getSender();
        ctx.get().enqueueWork(() -> {
            if (player != null) BlinkManager.blinkNow(player);
        });
        ctx.get().setPacketHandled(true);
    }
}
