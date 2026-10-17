package com.zone19.scp.story;

import net.minecraft.nbt.CompoundTag;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.saveddata.SavedData;

/** Shared campaign progress for the whole world (co-op: everyone plays the same shift). */
public class StoryData extends SavedData {
    private static final String NAME = "scpzone19_story";

    public int chapter;
    public int step;
    public int progress;
    public boolean finished;
    public boolean built;
    /** Bumped on /zone19 reset so per-player locker rewards can be claimed again. */
    public int epoch;

    public static StoryData get(MinecraftServer server) {
        return server.overworld().getDataStorage().computeIfAbsent(StoryData::load, StoryData::new, NAME);
    }

    private static StoryData load(CompoundTag tag) {
        StoryData d = new StoryData();
        d.chapter = tag.getInt("Chapter");
        d.step = tag.getInt("Step");
        d.progress = tag.getInt("Progress");
        d.finished = tag.getBoolean("Finished");
        d.built = tag.getBoolean("Built");
        d.epoch = tag.getInt("Epoch");
        return d;
    }

    @Override
    public CompoundTag save(CompoundTag tag) {
        tag.putInt("Chapter", chapter);
        tag.putInt("Step", step);
        tag.putInt("Progress", progress);
        tag.putBoolean("Finished", finished);
        tag.putBoolean("Built", built);
        tag.putInt("Epoch", epoch);
        return tag;
    }
}
