package com.williamgame.blockmemory.history;

import com.williamgame.blockmemory.MemoryConfig;
import com.williamgame.blockmemory.ModRegistry;
import com.williamgame.blockmemory.block.EchoKeystoneBlockEntity;
import com.williamgame.blockmemory.network.GhostReplayPacket;
import com.williamgame.blockmemory.network.LensPacket;
import com.williamgame.blockmemory.network.ModNetwork;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.chunk.LevelChunk;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Shared server-side logic for reading the memory of blocks. */
public final class MemoryService {
    private MemoryService() {
    }

    // ------------------------------------------------------------------ formatting

    public static Component timeAgo(long timeSec) {
        long d = Math.max(0, BlockHistoryData.nowSec() - timeSec);
        if (d < 60) return Component.translatable("blockmemory.time.seconds", d);
        if (d < 3600) return Component.translatable("blockmemory.time.minutes", d / 60);
        if (d < 86400) return Component.translatable("blockmemory.time.hours", d / 3600);
        return Component.translatable("blockmemory.time.days", d / 86400);
    }

    public static MutableComponent blockName(BlockState state) {
        return state.getBlock().getName().copy();
    }

    private static Component pos(BlockPos p) {
        return Component.literal(p.getX() + " " + p.getY() + " " + p.getZ()).withStyle(ChatFormatting.GRAY);
    }

    public static Component describeEntry(HistoryEntry e) {
        Component time = timeAgo(e.timeSec()).copy().withStyle(ChatFormatting.DARK_AQUA);
        Component who = Component.literal(e.actorName()).withStyle(ChatFormatting.YELLOW);
        Component oldName = blockName(e.oldState()).withStyle(ChatFormatting.WHITE);
        Component newName = blockName(e.newState()).withStyle(ChatFormatting.WHITE);
        return switch (e.action()) {
            case PLACED -> e.oldState().isAir()
                    ? Component.translatable("blockmemory.inspect.placed", time, who, newName)
                    : Component.translatable("blockmemory.inspect.placed_over", time, who, newName, oldName);
            case BROKEN -> Component.translatable("blockmemory.inspect.broken", time, who, oldName);
            case EXPLODED -> Component.translatable("blockmemory.inspect.exploded", time, who, oldName);
            case RESTORED -> Component.translatable("blockmemory.inspect.restored", time, who, newName);
            case ANCIENT -> Component.translatable("blockmemory.inspect.ancient", time, newName);
        };
    }

    /** Chat lines describing everything remembered at a position (player history + ruin keystones). */
    public static List<Component> describe(ServerLevel level, BlockPos pos) {
        List<Component> lines = new ArrayList<>();
        BlockState now = level.getBlockState(pos);
        lines.add(Component.translatable("blockmemory.inspect.header", blockName(now).withStyle(ChatFormatting.AQUA), pos(pos))
                .withStyle(ChatFormatting.LIGHT_PURPLE));
        List<HistoryEntry> history = BlockHistoryData.get(level).getHistory(pos);
        int shown = 0;
        for (HistoryEntry e : history) {
            if (shown++ >= 8) {
                lines.add(Component.translatable("blockmemory.inspect.more", history.size() - 8).withStyle(ChatFormatting.DARK_GRAY));
                break;
            }
            lines.add(Component.literal("  • ").withStyle(ChatFormatting.DARK_PURPLE).append(describeEntry(e)));
        }
        for (EchoKeystoneBlockEntity k : keystonesNear(level, pos, 24)) {
            BlockState ancient = k.rememberedAt(pos);
            if (ancient != null) {
                lines.add(Component.literal("  • ").withStyle(ChatFormatting.GOLD).append(
                        Component.translatable("blockmemory.inspect.ancient_years", k.years(),
                                blockName(ancient).withStyle(ChatFormatting.WHITE)).withStyle(ChatFormatting.GOLD)));
                break;
            }
        }
        if (lines.size() == 1) {
            lines.add(Component.translatable("blockmemory.inspect.none").withStyle(ChatFormatting.GRAY, ChatFormatting.ITALIC));
        }
        return lines;
    }

    public static boolean hasMemory(ServerLevel level, BlockPos pos) {
        if (!BlockHistoryData.get(level).getHistory(pos).isEmpty()) return true;
        for (EchoKeystoneBlockEntity k : keystonesNear(level, pos, 24)) {
            if (k.rememberedAt(pos) != null) return true;
        }
        return false;
    }

    // ------------------------------------------------------------------ keystones

    public static List<EchoKeystoneBlockEntity> keystonesNear(ServerLevel level, BlockPos center, int range) {
        List<EchoKeystoneBlockEntity> out = new ArrayList<>();
        int minCx = (center.getX() - range) >> 4, maxCx = (center.getX() + range) >> 4;
        int minCz = (center.getZ() - range) >> 4, maxCz = (center.getZ() + range) >> 4;
        for (int cx = minCx; cx <= maxCx; cx++) {
            for (int cz = minCz; cz <= maxCz; cz++) {
                LevelChunk chunk = level.getChunkSource().getChunkNow(cx, cz);
                if (chunk == null) continue;
                for (BlockEntity be : chunk.getBlockEntities().values()) {
                    if (be instanceof EchoKeystoneBlockEntity k && !k.isRemoved()) out.add(k);
                }
            }
        }
        return out;
    }

    // ------------------------------------------------------------------ ghosts

    private static boolean emptyNow(BlockState now) {
        return now.isAir() || now.canBeReplaced();
    }

    private static boolean renderable(BlockState s) {
        return !s.isAir() && s.getRenderShape() == RenderShape.MODEL;
    }

    public static List<GhostReplayPacket.Ghost> collectGhosts(ServerLevel level, BlockPos center, int radius) {
        Map<BlockPos, GhostReplayPacket.Ghost> ghosts = new HashMap<>();
        double r2 = (radius + 0.5) * (radius + 0.5);
        // ruins: remembered by keystones, larger radius so whole buildings reassemble
        int ancientRadius = radius * 2 + 4;
        double a2 = (ancientRadius + 0.5) * (ancientRadius + 0.5);
        for (EchoKeystoneBlockEntity k : keystonesNear(level, center, ancientRadius + 24)) {
            k.forEach((p, state) -> {
                if (p.distSqr(center) > a2 || !renderable(state)) return;
                BlockState now = level.getBlockState(p);
                if (now == state || !emptyNow(now)) return;
                ghosts.put(p.immutable(), new GhostReplayPacket.Ghost(p.immutable(), Block.getId(state), true));
            });
        }
        // player history
        for (HistoryEntry e : BlockHistoryData.get(level).latestAround(center, radius, 0).values()) {
            BlockPos p = e.pos();
            if (p.distSqr(center) > r2) continue;
            BlockState was = e.oldState();
            if (!renderable(was)) continue;
            BlockState now = level.getBlockState(p);
            if (now == was || !emptyNow(now)) continue;
            ghosts.put(p, new GhostReplayPacket.Ghost(p, Block.getId(was), false));
        }
        List<GhostReplayPacket.Ghost> list = new ArrayList<>(ghosts.values());
        list.sort(Comparator.comparingDouble(g -> g.pos().distSqr(center)));
        if (list.size() > GhostReplayPacket.MAX) list = new ArrayList<>(list.subList(0, GhostReplayPacket.MAX));
        return list;
    }

    /** Collects ghosts around the center and shows them to the user and to everyone standing nearby. */
    public static int replay(ServerPlayer user, BlockPos center) {
        ServerLevel level = user.serverLevel();
        List<GhostReplayPacket.Ghost> ghosts = collectGhosts(level, center, MemoryConfig.REPLAY_RADIUS.get());
        if (ghosts.isEmpty()) return 0;
        GhostReplayPacket packet = new GhostReplayPacket(center, MemoryConfig.REPLAY_SECONDS.get() * 20, ghosts);
        for (ServerPlayer p : level.players()) {
            if (p == user || p.distanceToSqr(center.getX(), center.getY(), center.getZ()) < 48 * 48) {
                ModNetwork.sendTo(p, packet);
            }
        }
        level.playSound(null, center, ModRegistry.SOUND_GHOST_RISE.get(), SoundSource.PLAYERS, 1.0F, 1.0F);
        level.sendParticles(ParticleTypes.SOUL, center.getX() + 0.5, center.getY() + 1.0, center.getZ() + 0.5, 20, 1.5, 0.8, 1.5, 0.02);
        return ghosts.size();
    }

    // ------------------------------------------------------------------ lens

    public static List<LensPacket.Mark> lensMarks(ServerLevel level, BlockPos center) {
        long window = MemoryConfig.LENS_MINUTES.get() * 60L;
        long now = BlockHistoryData.nowSec();
        List<LensPacket.Mark> marks = new ArrayList<>();
        for (HistoryEntry e : BlockHistoryData.get(level).latestAround(center, MemoryConfig.LENS_RADIUS.get(), now - window).values()) {
            int frac = (int) Math.min(255, Math.max(0, (now - e.timeSec()) * 255 / Math.max(1, window)));
            marks.add(new LensPacket.Mark(e.pos(), e.action().ordinal(), frac));
            if (marks.size() >= LensPacket.MAX) break;
        }
        return marks;
    }

    // ------------------------------------------------------------------ restoration

    /** Restores blocks that other players (or explosions) removed recently. Returns the number restored. */
    public static int restore(ServerPlayer user, BlockPos center, int radius, int maxBlocks) {
        ServerLevel level = user.serverLevel();
        BlockHistoryData data = BlockHistoryData.get(level);
        long since = BlockHistoryData.nowSec() - MemoryConfig.RESTORE_MINUTES.get() * 60L;
        UUID self = user.getUUID();
        List<HistoryEntry> candidates = new ArrayList<>();
        for (HistoryEntry e : data.latestAround(center, radius, since).values()) {
            if (!e.action().isRemoval()) continue;
            if (self.equals(e.actorId())) continue;
            BlockState was = e.oldState();
            if (was.isAir() || was.hasProperty(BlockStateProperties.DOUBLE_BLOCK_HALF) || was.hasProperty(BlockStateProperties.BED_PART)) continue;
            candidates.add(e);
        }
        candidates.sort(Comparator.comparingInt(e -> e.pos().getY()));
        int restored = 0;
        for (HistoryEntry e : candidates) {
            if (restored >= maxBlocks) break;
            BlockPos p = e.pos();
            BlockState now = level.getBlockState(p);
            if (!emptyNow(now)) continue;
            BlockState was = e.oldState();
            if (was.getDestroySpeed(level, p) < 0 || !was.canSurvive(level, p)) continue;
            if (level.setBlock(p, was, 3)) {
                data.record(p, HistoryAction.RESTORED, self, user.getGameProfile().getName(), now, was);
                level.sendParticles(ParticleTypes.WAX_OFF, p.getX() + 0.5, p.getY() + 0.5, p.getZ() + 0.5, 6, 0.3, 0.3, 0.3, 0.5);
                restored++;
            }
        }
        return restored;
    }
}
