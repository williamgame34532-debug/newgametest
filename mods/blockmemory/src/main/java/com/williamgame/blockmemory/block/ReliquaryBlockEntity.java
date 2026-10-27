package com.williamgame.blockmemory.block;

import com.williamgame.blockmemory.ModRegistry;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.StringTag;
import net.minecraft.nbt.Tag;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

public class ReliquaryBlockEntity extends BlockEntity {
    private final Set<UUID> readers = new HashSet<>();

    public ReliquaryBlockEntity(BlockPos pos, BlockState state) {
        super(ModRegistry.RELIQUARY_BE.get(), pos, state);
    }

    public boolean hasRead(UUID player) {
        return readers.contains(player);
    }

    public void markRead(UUID player) {
        readers.add(player);
        setChanged();
    }

    @Override
    protected void saveAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.saveAdditional(tag, registries);
        ListTag list = new ListTag();
        for (UUID id : readers) list.add(StringTag.valueOf(id.toString()));
        tag.put("readers", list);
    }

    @Override
    protected void loadAdditional(CompoundTag tag, HolderLookup.Provider registries) {
        super.loadAdditional(tag, registries);
        readers.clear();
        ListTag list = tag.getList("readers", Tag.TAG_STRING);
        for (int i = 0; i < list.size(); i++) {
            try {
                readers.add(UUID.fromString(list.getString(i)));
            } catch (IllegalArgumentException ignored) {
            }
        }
    }
}
