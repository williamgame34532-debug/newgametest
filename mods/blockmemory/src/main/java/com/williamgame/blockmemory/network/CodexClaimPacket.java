package com.williamgame.blockmemory.network;

import com.williamgame.blockmemory.codex.CodexManager;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.network.CustomPayloadEvent;

/** Client -> server: claim the reward of a completed chapter. Fully validated on the server. */
public record CodexClaimPacket(int chapter) {
    public static void encode(CodexClaimPacket msg, FriendlyByteBuf buf) {
        buf.writeVarInt(msg.chapter);
    }

    public static CodexClaimPacket decode(FriendlyByteBuf buf) {
        return new CodexClaimPacket(buf.readVarInt());
    }

    public static void handle(CodexClaimPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            ServerPlayer player = ctx.getSender();
            if (player != null) {
                CodexManager.claim(player, msg.chapter);
            }
        });
        ctx.setPacketHandled(true);
    }
}
