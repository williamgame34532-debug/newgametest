package com.williamgame.apiprobe;

import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.saveddata.SavedData;

public class ProbeSavedData extends SavedData {
    private int counter;

    public static ProbeSavedData get(ServerLevel level) {
        return level.getServer().overworld().getDataStorage().computeIfAbsent(
                new SavedData.Factory<>(ProbeSavedData::new, ProbeSavedData::load, null), "apiprobe_data");
    }

    public static ProbeSavedData load(CompoundTag tag, HolderLookup.Provider registries) {
        ProbeSavedData d = new ProbeSavedData();
        d.counter = tag.getInt("counter");
        return d;
    }

    @Override
    public CompoundTag save(CompoundTag tag, HolderLookup.Provider registries) {
        tag.putInt("counter", counter);
        return tag;
    }

    public void bump() {
        counter++;
        setDirty();
    }
}
