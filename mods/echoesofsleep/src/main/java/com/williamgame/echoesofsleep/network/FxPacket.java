package com.williamgame.echoesofsleep.network;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

/** Server -> client: a one-shot scare effect. */
public record FxPacket(int type, float strength) {
    public static final int WAKE_UP = 0;        // white flash + heartbeat + scream
    public static final int WHISPER_BEHIND = 1;  // whisper right behind the player's head
    public static final int FOOTSTEPS = 2;       // footsteps following behind
    public static final int GLITCH = 3;          // frame skip + wrong HUD numbers
    public static final int HEARTBEAT = 4;       // heartbeat
    public static final int DREAMER_PULSE = 5;   // violent shake (boss)

    public static void encode(FxPacket msg, FriendlyByteBuf buf) {
        buf.writeVarInt(msg.type);
        buf.writeFloat(msg.strength);
    }

    public static FxPacket decode(FriendlyByteBuf buf) {
        return new FxPacket(buf.readVarInt(), buf.readFloat());
    }

    public static void handle(FxPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.echoesofsleep.client.ClientHooks.onFx(msg.type, msg.strength);
            }
        });
        ctx.setPacketHandled(true);
    }
}
