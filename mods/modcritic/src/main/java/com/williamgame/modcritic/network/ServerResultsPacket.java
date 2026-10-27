package com.williamgame.modcritic.network;

import com.williamgame.modcritic.RatingEntry;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

import java.util.ArrayList;
import java.util.List;

/** Server -> client: every player's submitted ratings. */
public record ServerResultsPacket(List<PlayerRatings> players) {
    public record PlayerRatings(String name, List<RatingEntry> entries) {
    }

    public static void encode(ServerResultsPacket msg, FriendlyByteBuf buf) {
        buf.writeVarInt(msg.players.size());
        for (PlayerRatings p : msg.players) {
            buf.writeUtf(p.name, 64);
            buf.writeVarInt(p.entries.size());
            for (RatingEntry e : p.entries) PacketIO.writeEntry(buf, e);
        }
    }

    public static ServerResultsPacket decode(FriendlyByteBuf buf) {
        int n = Math.min(buf.readVarInt(), 4096);
        List<PlayerRatings> players = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            String name = buf.readUtf(64);
            int m = Math.min(buf.readVarInt(), 4096);
            List<RatingEntry> entries = new ArrayList<>(m);
            for (int j = 0; j < m; j++) entries.add(PacketIO.readEntry(buf));
            players.add(new PlayerRatings(name, entries));
        }
        return new ServerResultsPacket(players);
    }

    public static void handle(ServerResultsPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.modcritic.client.ClientHooks.onServerResults(msg.players);
            }
        });
        ctx.setPacketHandled(true);
    }
}
