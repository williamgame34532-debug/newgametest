package com.williamgame.echoesofsleep.distortion;

import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderGetter;
import net.minecraft.core.HolderLookup;
import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.NbtUtils;
import net.minecraft.nbt.Tag;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.saveddata.SavedData;

import java.util.HashMap;
import java.util.Map;

/**
 * Per-dimension Distortion state. Lives in the dimension's own data storage, so every dimension
 * dreams separately. Every block the Distortion touches is recorded here with its original state
 * so that it can always be restored - after a crash, a restart or a chunk unload.
 */
public class DistortionData extends SavedData {
    public static final String NAME = "echoesofsleep_distortion";

    public int level;            // 0 = none, 1 Unease, 2 Warped, 3 Nightmare
    public int ticksLeft;
    public int totalTicks;
    public int consecutiveNights; // nights slept without cleansing
    public int cleansing;         // echoes slain during the current distortion
    public long lastMotherTime = -100000L;
    public final Map<Long, Entry> entries = new HashMap<>();

    public static class Entry {
        public final BlockState original;
        public final BlockState replacement;
        public long revertAt;

        public Entry(BlockState original, BlockState replacement, long revertAt) {
            this.original = original;
            this.replacement = replacement;
            this.revertAt = revertAt;
        }
    }

    public static DistortionData get(ServerLevel level) {
        return level.getDataStorage().computeIfAbsent(
                new SavedData.Factory<>(DistortionData::new, DistortionData::load, null), NAME);
    }

    public static DistortionData load(CompoundTag tag, HolderLookup.Provider registries) {
        DistortionData d = new DistortionData();
        d.level = tag.getInt("level");
        d.ticksLeft = tag.getInt("ticksLeft");
        d.totalTicks = tag.getInt("totalTicks");
        d.consecutiveNights = tag.getInt("consecutive");
        d.cleansing = tag.getInt("cleansing");
        d.lastMotherTime = tag.getLong("lastMother");
        HolderGetter<Block> blocks = registries.lookupOrThrow(Registries.BLOCK);
        ListTag list = tag.getList("entries", Tag.TAG_COMPOUND);
        for (int i = 0; i < list.size(); i++) {
            CompoundTag e = list.getCompound(i);
            BlockState orig = NbtUtils.readBlockState(blocks, e.getCompound("orig"));
            BlockState repl = NbtUtils.readBlockState(blocks, e.getCompound("repl"));
            d.entries.put(e.getLong("pos"), new Entry(orig, repl, e.getLong("at")));
        }
        return d;
    }

    @Override
    public CompoundTag save(CompoundTag tag, HolderLookup.Provider registries) {
        tag.putInt("level", level);
        tag.putInt("ticksLeft", ticksLeft);
        tag.putInt("totalTicks", totalTicks);
        tag.putInt("consecutive", consecutiveNights);
        tag.putInt("cleansing", cleansing);
        tag.putLong("lastMother", lastMotherTime);
        ListTag list = new ListTag();
        for (Map.Entry<Long, Entry> en : entries.entrySet()) {
            CompoundTag e = new CompoundTag();
            e.putLong("pos", en.getKey());
            e.put("orig", NbtUtils.writeBlockState(en.getValue().original));
            e.put("repl", NbtUtils.writeBlockState(en.getValue().replacement));
            e.putLong("at", en.getValue().revertAt);
            list.add(e);
        }
        tag.put("entries", list);
        return tag;
    }

    public boolean isActive() {
        return level > 0 && ticksLeft > 0;
    }

    /** 0..1 strength: fades in over 10 s and out over the last 2 minutes. */
    public float intensity() {
        return intensity(level, ticksLeft, totalTicks);
    }

    public static float intensity(int level, int ticksLeft, int totalTicks) {
        if (level <= 0 || ticksLeft <= 0 || totalTicks <= 0) return 0.0F;
        int elapsed = totalTicks - ticksLeft;
        float in = Math.min(1.0F, elapsed / 200.0F);
        float out = Math.min(1.0F, ticksLeft / 2400.0F);
        return Math.max(0.0F, Math.min(in, out));
    }

    public void track(BlockPos pos, BlockState original, BlockState replacement, long revertAt) {
        long key = pos.asLong();
        Entry existing = entries.get(key);
        if (existing != null) {
            // keep the very first original, only update what is there now
            entries.put(key, new Entry(existing.original, replacement, Math.max(existing.revertAt, revertAt)));
        } else {
            entries.put(key, new Entry(original, replacement, revertAt));
        }
        setDirty();
    }

    public boolean isTracked(BlockPos pos) {
        return entries.containsKey(pos.asLong());
    }
}
