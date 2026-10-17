package com.zone19.scp.network;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.DistExecutor;
import net.minecraftforge.network.NetworkEvent;

import java.util.function.Supplier;

/** meter < 0 hides the blink HUD (player left the facility or blinking is off). */
public record BlinkPacket(int meter, int max, boolean blinking) {
    public void encode(FriendlyByteBuf buf) {
        buf.writeVarInt(meter + 1);
        buf.writeVarInt(max);
        buf.writeBoolean(blinking);
    }

    public static BlinkPacket decode(FriendlyByteBuf buf) {
        return new BlinkPacket(buf.readVarInt() - 1, buf.readVarInt(), buf.readBoolean());
    }

    public static void handle(BlinkPacket msg, Supplier<NetworkEvent.Context> ctx) {
        ctx.get().enqueueWork(() -> DistExecutor.unsafeRunWhenOn(Dist.CLIENT,
                () -> () -> com.zone19.scp.client.ClientPacketHandler.blink(msg)));
        ctx.get().setPacketHandled(true);
    }
}
