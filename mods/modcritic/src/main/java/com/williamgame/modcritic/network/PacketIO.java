package com.williamgame.modcritic.network;

import com.williamgame.modcritic.Criterion;
import com.williamgame.modcritic.RatingEntry;
import net.minecraft.network.FriendlyByteBuf;

/** Shared (de)serialisation of a {@link RatingEntry}. */
public final class PacketIO {
    private PacketIO() {
    }

    public static void writeEntry(FriendlyByteBuf buf, RatingEntry e) {
        buf.writeUtf(e.modId, 128);
        buf.writeUtf(e.modName, 128);
        buf.writeVarIntArray(e.scores);
        buf.writeUtf(e.comment, RatingEntry.MAX_COMMENT * 4);
        buf.writeVarLong(e.time);
    }

    public static RatingEntry readEntry(FriendlyByteBuf buf) {
        RatingEntry e = new RatingEntry();
        e.modId = buf.readUtf(128);
        e.modName = buf.readUtf(128);
        e.scores = buf.readVarIntArray(Criterion.COUNT * 2);
        e.comment = buf.readUtf(RatingEntry.MAX_COMMENT * 4);
        e.time = buf.readVarLong();
        return e.sanitize();
    }
}
