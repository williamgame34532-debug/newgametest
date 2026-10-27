package com.williamgame.hideandhunt.network;

import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

/** Full arena snapshot for the Game Master Tablet. {@code open} = open the screen, otherwise refresh it if open. */
public record TabletDataPacket(CompoundTag data, boolean open) {
    public static void encode(TabletDataPacket m, FriendlyByteBuf buf) {
        buf.writeNbt(m.data);
        buf.writeBoolean(m.open);
    }

    public static TabletDataPacket decode(FriendlyByteBuf buf) {
        CompoundTag t = buf.readNbt();
        return new TabletDataPacket(t == null ? new CompoundTag() : t, buf.readBoolean());
    }

    public static void handle(TabletDataPacket m, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.hideandhunt.client.ClientHooks.onTabletData(m.data, m.open);
            }
        });
        ctx.setPacketHandled(true);
    }
}
