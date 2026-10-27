package com.williamgame.modcritic.network;

import com.williamgame.modcritic.CriticSavedData;
import com.williamgame.modcritic.RatingEntry;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.network.CustomPayloadEvent;

/** Client -> server: store (or remove) the sender's rating of one mod. */
public record SubmitRatingPacket(RatingEntry entry, boolean remove) {
    public static void encode(SubmitRatingPacket msg, FriendlyByteBuf buf) {
        buf.writeBoolean(msg.remove);
        PacketIO.writeEntry(buf, msg.entry);
    }

    public static SubmitRatingPacket decode(FriendlyByteBuf buf) {
        boolean remove = buf.readBoolean();
        return new SubmitRatingPacket(PacketIO.readEntry(buf), remove);
    }

    public static void handle(SubmitRatingPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            ServerPlayer player = ctx.getSender();
            if (player == null || msg.entry.modId.isEmpty()) return;
            CriticSavedData data = CriticSavedData.get(player.server);
            if (msg.remove) {
                data.remove(player.getUUID(), msg.entry.modId);
            } else {
                data.put(player.getUUID(), player.getGameProfile().getName(), msg.entry);
            }
        });
        ctx.setPacketHandled(true);
    }
}
