package com.williamgame.hideandhunt.network;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

import java.util.ArrayList;
import java.util.List;

/** End-of-round results, opens the results screen on every participant's client. */
public record ResultsPacket(int winner, int durationSec, boolean infection, List<Entry> entries,
                            String bestHider, int bestHiderSec, String topHunter, int topHunterCatches, String mvp,
                            String arena) {

    /** startSide/endSide are Side ordinals. caughtBy is empty if the player survived. */
    public record Entry(String name, int startSide, int endSide, int catches, int surviveSec, String caughtBy,
                        int points, int taunts, boolean survived) {}

    public static void encode(ResultsPacket m, FriendlyByteBuf buf) {
        buf.writeVarInt(m.winner);
        buf.writeVarInt(m.durationSec);
        buf.writeBoolean(m.infection);
        buf.writeVarInt(m.entries.size());
        for (Entry e : m.entries) {
            buf.writeUtf(e.name, 64);
            buf.writeVarInt(e.startSide);
            buf.writeVarInt(e.endSide);
            buf.writeVarInt(e.catches);
            buf.writeVarInt(e.surviveSec);
            buf.writeUtf(e.caughtBy, 64);
            buf.writeVarInt(e.points);
            buf.writeVarInt(e.taunts);
            buf.writeBoolean(e.survived);
        }
        buf.writeUtf(m.bestHider, 64);
        buf.writeVarInt(m.bestHiderSec);
        buf.writeUtf(m.topHunter, 64);
        buf.writeVarInt(m.topHunterCatches);
        buf.writeUtf(m.mvp, 64);
        buf.writeUtf(m.arena, 64);
    }

    public static ResultsPacket decode(FriendlyByteBuf buf) {
        int winner = buf.readVarInt();
        int dur = buf.readVarInt();
        boolean inf = buf.readBoolean();
        int n = Math.min(buf.readVarInt(), 512);
        List<Entry> list = new ArrayList<>();
        for (int i = 0; i < n; i++) {
            list.add(new Entry(buf.readUtf(64), buf.readVarInt(), buf.readVarInt(), buf.readVarInt(), buf.readVarInt(),
                    buf.readUtf(64), buf.readVarInt(), buf.readVarInt(), buf.readBoolean()));
        }
        return new ResultsPacket(winner, dur, inf, list, buf.readUtf(64), buf.readVarInt(), buf.readUtf(64), buf.readVarInt(),
                buf.readUtf(64), buf.readUtf(64));
    }

    public static void handle(ResultsPacket m, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.hideandhunt.client.ClientHooks.onResults(m);
            }
        });
        ctx.setPacketHandled(true);
    }
}
