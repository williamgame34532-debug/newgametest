package com.zone19.scp.network;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.DistExecutor;
import net.minecraftforge.network.NetworkEvent;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.function.Supplier;

public record SkinSyncPacket(Map<UUID, String> skins) {
    public void encode(FriendlyByteBuf buf) {
        buf.writeMap(skins, FriendlyByteBuf::writeUUID, (b, s) -> b.writeUtf(s, 64));
    }

    public static SkinSyncPacket decode(FriendlyByteBuf buf) {
        return new SkinSyncPacket(buf.readMap(HashMap::new, FriendlyByteBuf::readUUID, b -> b.readUtf(64)));
    }

    public static void handle(SkinSyncPacket msg, Supplier<NetworkEvent.Context> ctx) {
        ctx.get().enqueueWork(() -> DistExecutor.unsafeRunWhenOn(Dist.CLIENT,
                () -> () -> com.zone19.scp.client.ClientPacketHandler.skins(msg)));
        ctx.get().setPacketHandled(true);
    }
}
