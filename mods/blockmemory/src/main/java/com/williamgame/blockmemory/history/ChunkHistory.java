package com.williamgame.blockmemory.history;

import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderGetter;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.NbtUtils;
import net.minecraft.nbt.Tag;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Compact history of one chunk. Entries are kept in chronological order (oldest first).
 * On disk every entry is two longs plus a per-chunk block state palette.
 */
public class ChunkHistory {
    /** In-memory entry. localPos packs x(4) z(4) y+2048(12). */
    public static final class Raw {
        public final int localPos;
        public final long timeSec;
        public final byte action;
        public final int actor;
        public final BlockState oldState;
        public final BlockState newState;

        public Raw(int localPos, long timeSec, byte action, int actor, BlockState oldState, BlockState newState) {
            this.localPos = localPos;
            this.timeSec = timeSec;
            this.action = action;
            this.actor = actor;
            this.oldState = oldState;
            this.newState = newState;
        }
    }

    final List<Raw> entries = new ArrayList<>();

    public static int pack(BlockPos pos) {
        int x = pos.getX() & 15;
        int z = pos.getZ() & 15;
        int y = (pos.getY() + 2048) & 0xFFF;
        return (x << 16) | (z << 12) | y;
    }

    public static BlockPos unpack(long chunkKey, int local) {
        int cx = (int) chunkKey;
        int cz = (int) (chunkKey >> 32);
        int x = (local >> 16) & 15;
        int z = (local >> 12) & 15;
        int y = (local & 0xFFF) - 2048;
        return new BlockPos((cx << 4) + x, y, (cz << 4) + z);
    }

    public void add(Raw raw, int maxPerChunk, int maxPerBlock) {
        int count = 0;
        int oldestIdx = -1;
        for (int i = 0; i < entries.size(); i++) {
            if (entries.get(i).localPos == raw.localPos) {
                if (oldestIdx < 0) oldestIdx = i;
                count++;
            }
        }
        if (count >= maxPerBlock && oldestIdx >= 0) {
            entries.remove(oldestIdx);
        }
        entries.add(raw);
        while (entries.size() > maxPerChunk) {
            entries.remove(0);
        }
    }

    public boolean isEmpty() {
        return entries.isEmpty();
    }

    public CompoundTag save() {
        Map<BlockState, Integer> index = new HashMap<>();
        ListTag palette = new ListTag();
        long[] data = new long[entries.size() * 2];
        int i = 0;
        for (Raw r : entries) {
            int o = index.computeIfAbsent(r.oldState, s -> {
                palette.add(NbtUtils.writeBlockState(s));
                return palette.size() - 1;
            });
            int n = index.computeIfAbsent(r.newState, s -> {
                palette.add(NbtUtils.writeBlockState(s));
                return palette.size() - 1;
            });
            data[i++] = ((r.timeSec & 0xFFFFFFFFL) << 32) | ((long) (r.localPos & 0xFFFFF) << 8) | (r.action & 0xFF);
            data[i++] = ((long) (r.actor & 0xFFFFF) << 44) | ((long) (o & 0x3FFFFF) << 22) | (n & 0x3FFFFF);
        }
        CompoundTag tag = new CompoundTag();
        tag.put("palette", palette);
        tag.putLongArray("data", data);
        return tag;
    }

    public static ChunkHistory load(CompoundTag tag, HolderGetter<Block> blocks) {
        ChunkHistory h = new ChunkHistory();
        ListTag palTag = tag.getList("palette", Tag.TAG_COMPOUND);
        BlockState[] palette = new BlockState[palTag.size()];
        for (int i = 0; i < palette.length; i++) {
            palette[i] = NbtUtils.readBlockState(blocks, palTag.getCompound(i));
        }
        long[] data = tag.getLongArray("data");
        for (int i = 0; i + 1 < data.length; i += 2) {
            long a = data[i];
            long b = data[i + 1];
            long time = (a >>> 32) & 0xFFFFFFFFL;
            int local = (int) ((a >>> 8) & 0xFFFFF);
            byte action = (byte) (a & 0xFF);
            int actor = (int) ((b >>> 44) & 0xFFFFF);
            int o = (int) ((b >>> 22) & 0x3FFFFF);
            int n = (int) (b & 0x3FFFFF);
            BlockState os = o < palette.length ? palette[o] : Blocks.AIR.defaultBlockState();
            BlockState ns = n < palette.length ? palette[n] : Blocks.AIR.defaultBlockState();
            h.entries.add(new Raw(local, time, action, actor, os, ns));
        }
        return h;
    }
}
