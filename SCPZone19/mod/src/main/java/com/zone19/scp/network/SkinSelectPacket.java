package com.zone19.scp.network;

import com.zone19.scp.world.SkinManager;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.network.NetworkEvent;

import java.util.function.Supplier;

public record SkinSelectPacket(String skin) {
    public void encode(FriendlyByteBuf buf) {
        buf.writeUtf(skin, 64);
    }

    public static SkinSelectPacket decode(FriendlyByteBuf buf) {
        return new SkinSelectPacket(buf.readUtf(64));
    }

    public static void handle(SkinSelectPacket msg, Supplier<NetworkEvent.Context> ctx) {
        ServerPlayer player = ctx.get().getSender();
        ctx.get().enqueueWork(() -> {
            if (player != null) SkinManager.select(player, msg.skin());
        });
        ctx.get().setPacketHandled(true);
    }
}
