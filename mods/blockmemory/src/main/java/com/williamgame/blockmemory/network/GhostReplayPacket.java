package com.williamgame.blockmemory.network;

import net.minecraft.core.BlockPos;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

import java.util.ArrayList;
import java.util.List;

/** Server -> client: ghost blocks (what used to stand somewhere) to render translucently for a while. */
public record GhostReplayPacket(BlockPos center, int durationTicks, List<Ghost> ghosts) {
    /** stateId is Block.getId(state); ancient = remembered by a ruin keystone rather than by a player. */
    public record Ghost(BlockPos pos, int stateId, boolean ancient) {
    }

    public static final int MAX = 1024;

    public static void encode(GhostReplayPacket msg, FriendlyByteBuf buf) {
        buf.writeBlockPos(msg.center);
        buf.writeVarInt(msg.durationTicks);
        int n = Math.min(MAX, msg.ghosts.size());
        buf.writeVarInt(n);
        for (int i = 0; i < n; i++) {
            Ghost g = msg.ghosts.get(i);
            buf.writeBlockPos(g.pos);
            buf.writeVarInt(g.stateId);
            buf.writeBoolean(g.ancient);
        }
    }

    public static GhostReplayPacket decode(FriendlyByteBuf buf) {
        BlockPos center = buf.readBlockPos();
        int duration = buf.readVarInt();
        int n = Math.min(MAX, buf.readVarInt());
        List<Ghost> list = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            list.add(new Ghost(buf.readBlockPos(), buf.readVarInt(), buf.readBoolean()));
        }
        return new GhostReplayPacket(center, duration, list);
    }

    public static void handle(GhostReplayPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.blockmemory.client.ClientHooks.onGhosts(msg.center, msg.durationTicks, msg.ghosts);
            }
        });
        ctx.setPacketHandled(true);
    }
}
