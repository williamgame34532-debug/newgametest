package com.williamgame.hideandhunt.network;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

import java.util.ArrayList;
import java.util.List;

/** Result of the Randomizer Button; the client plays a slot-machine animation before revealing it. */
public record RandomizerPacket(List<String> names, List<Integer> sides, int durationTicks) {
    public static void encode(RandomizerPacket m, FriendlyByteBuf buf) {
        int n = Math.min(m.names.size(), m.sides.size());
        buf.writeVarInt(n);
        for (int i = 0; i < n; i++) {
            buf.writeUtf(m.names.get(i), 64);
            buf.writeVarInt(m.sides.get(i));
        }
        buf.writeVarInt(m.durationTicks);
    }

    public static RandomizerPacket decode(FriendlyByteBuf buf) {
        int n = Math.min(buf.readVarInt(), 512);
        List<String> names = new ArrayList<>();
        List<Integer> sides = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            names.add(buf.readUtf(64));
            sides.add(buf.readVarInt());
        }
        return new RandomizerPacket(names, sides, buf.readVarInt());
    }

    public static void handle(RandomizerPacket m, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.hideandhunt.client.ClientHooks.onRandomizer(m);
            }
        });
        ctx.setPacketHandled(true);
    }
}
