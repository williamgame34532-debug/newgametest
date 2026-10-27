package com.williamgame.blockmemory.network;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

/** Server -> client: full codex progress of the receiving player. */
public record CodexSyncPacket(int fragments, int claimed, int newlyUnlocked, int completedChapter) {
    public static void encode(CodexSyncPacket msg, FriendlyByteBuf buf) {
        buf.writeVarInt(msg.fragments);
        buf.writeVarInt(msg.claimed);
        buf.writeVarInt(msg.newlyUnlocked + 1);
        buf.writeVarInt(msg.completedChapter + 1);
    }

    public static CodexSyncPacket decode(FriendlyByteBuf buf) {
        return new CodexSyncPacket(buf.readVarInt(), buf.readVarInt(), buf.readVarInt() - 1, buf.readVarInt() - 1);
    }

    public static void handle(CodexSyncPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.blockmemory.client.ClientHooks.onCodexSync(msg.fragments, msg.claimed, msg.newlyUnlocked, msg.completedChapter);
            }
        });
        ctx.setPacketHandled(true);
    }
}
