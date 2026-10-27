package com.williamgame.blockmemory.block;

import com.williamgame.blockmemory.ModRegistry;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderGetter;
import net.minecraft.core.HolderLookup;
import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.NbtUtils;
import net.minecraft.nbt.Tag;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.BiConsumer;

/**
 * Remembers the intact shape of the ruin it was buried in: every block that crumbled away or decayed,
 * stored relative to the keystone.
 */
public class EchoKeystoneBlockEntity extends BlockEntity {
    private int[] rel = new int[0];
    private BlockState[] states = new BlockState[0];
    private int years = 1000;
    private String kind = "tower";

    public EchoKeystoneBlockEntity(BlockPos pos, BlockState state) {
        super(ModRegistry.KEYSTONE_BE.get(), pos, state);
    }

    private static int packRel(int dx, int dy, int dz) {
        return ((dx + 512) & 1023) << 20 | ((dy + 512) & 1023) << 10 | ((dz + 512) & 1023);
    }

    public void setMemory(Map<BlockPos, BlockState> absolute, int years, String kind) {
        BlockPos o = getBlockPos();
        rel = new int[absolute.size()];
        states = new BlockState[absolute.size()];
        int i = 0;
        for (Map.Entry<BlockPos, BlockState> e : absolute.entrySet()) {
            BlockPos p = e.getKey();
            rel[i] = packRel(p.getX() - o.getX(), p.getY() - o.getY(), p.getZ() - o.getZ());
            states[i] = e.getValue();
            i++;
        }
        this.years = years;
        this.kind = kind;
        setChanged();
    }

    public int years() {
        return years;
    }

    public String kind() {
        return kind;
    }

    public int size() {
        return rel.length;
    }

    /** Visits every remembered block (absolute position). */
    public void forEach(BiConsumer<BlockPos, BlockState> consumer) {
        BlockPos o = getBlockPos();
        for (int i = 0; i < rel.length; i++) {
            int v = rel[i];
            int dx = ((v >> 20) & 1023) - 512;
            int dy = ((v >> 10) & 1023) - 512;
            int dz = (v & 1023) - 512;
            consumer.accept(o.offset(dx, dy, dz), states[i]);
        }
    }

    /** The remembered original state at an absolute position, or null. */
    public BlockState rememberedAt(BlockPos pos) {
        BlockPos o = getBlockPos();
        int dx = pos.getX() - o.getX(), dy = pos.getY() - o.getY(), dz = pos.getZ() - o.getZ();
        if (Math.abs(dx) > 500 || Math.abs(dy) > 500 || Math.abs(dz) > 500) return null;
        int key = packRel(dx, dy, dz);
        for (int i = 0; i < rel.length; i++) {
            if (rel[i] == key) return states[i];
        }
        return null;
    }

    @Override
    protected void saveAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.saveAdditional(tag, registries);
        Map<BlockState, Integer> index = new HashMap<>();
        ListTag palette = new ListTag();
        int[] idx = new int[states.length];
        for (int i = 0; i < states.length; i++) {
            idx[i] = index.computeIfAbsent(states[i], s -> {
                palette.add(NbtUtils.writeBlockState(s));
                return palette.size() - 1;
            });
        }
        tag.put("palette", palette);
        tag.putIntArray("rel", rel);
        tag.putIntArray("idx", idx);
        tag.putInt("years", years);
        tag.putString("kind", kind);
    }

    @Override
    protected void loadAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.loadAdditional(tag, registries);
        HolderGetter<Block> blocks = registries.lookupOrThrow(Registries.BLOCK);
        ListTag palTag = tag.getList("palette", Tag.TAG_COMPOUND);
        List<BlockState> palette = new ArrayList<>();
        for (int i = 0; i < palTag.size(); i++) palette.add(NbtUtils.readBlockState(blocks, palTag.getCompound(i)));
        int[] r = tag.getIntArray("rel");
        int[] idx = tag.getIntArray("idx");
        int n = Math.min(r.length, idx.length);
        rel = new int[n];
        states = new BlockState[n];
        int k = 0;
        for (int i = 0; i < n; i++) {
            if (idx[i] < 0 || idx[i] >= palette.size()) continue;
            rel[k] = r[i];
            states[k] = palette.get(idx[i]);
            k++;
        }
        if (k < n) {
            rel = java.util.Arrays.copyOf(rel, k);
            states = java.util.Arrays.copyOf(states, k);
        }
        years = tag.contains("years") ? tag.getInt("years") : 1000;
        kind = tag.getString("kind");
    }
}
