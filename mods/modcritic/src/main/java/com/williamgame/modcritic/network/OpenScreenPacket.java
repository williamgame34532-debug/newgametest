package com.williamgame.modcritic.network;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

/** Server -> client: open a Mod Critic screen (sent by the /critic command). */
public record OpenScreenPacket(int screen) {
    public static final int RATING = 0;
    public static final int RESULTS = 1;

    public static void encode(OpenScreenPacket msg, FriendlyByteBuf buf) {
        buf.writeVarInt(msg.screen);
    }

    public static OpenScreenPacket decode(FriendlyByteBuf buf) {
        return new OpenScreenPacket(buf.readVarInt());
    }

    public static void handle(OpenScreenPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.modcritic.client.ClientHooks.openFromServer(msg.screen);
            }
        });
        ctx.setPacketHandled(true);
    }
}
