package com.williamgame.blockmemory.codex;

import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.Tag;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.saveddata.SavedData;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/** Per-player codex progress, stored once per world (overworld data storage). */
public class CodexData extends SavedData {
    public static final class Progress {
        public int fragments;
        public int claimed;
    }

    private final Map<UUID, Progress> players = new HashMap<>();

    public static CodexData get(MinecraftServer server) {
        return server.overworld().getDataStorage().computeIfAbsent(
                new SavedData.Factory<>(CodexData::new, CodexData::load, null), "blockmemory_codex");
    }

    public static CodexData load(CompoundTag tag, HolderLookup.Provider registries) {
        CodexData d = new CodexData();
        ListTag list = tag.getList("players", Tag.TAG_COMPOUND);
        for (int i = 0; i < list.size(); i++) {
            CompoundTag p = list.getCompound(i);
            try {
                UUID id = UUID.fromString(p.getString("id"));
                Progress pr = new Progress();
                pr.fragments = p.getInt("fragments") & Fragments.ALL_MASK;
                pr.claimed = p.getInt("claimed");
                d.players.put(id, pr);
            } catch (IllegalArgumentException ignored) {
            }
        }
        return d;
    }

    @Override
    public CompoundTag save(CompoundTag tag, HolderLookup.Provider registries) {
        ListTag list = new ListTag();
        for (Map.Entry<UUID, Progress> e : players.entrySet()) {
            CompoundTag p = new CompoundTag();
            p.putString("id", e.getKey().toString());
            p.putInt("fragments", e.getValue().fragments);
            p.putInt("claimed", e.getValue().claimed);
            list.add(p);
        }
        tag.put("players", list);
        return tag;
    }

    public Progress get(UUID player) {
        return players.computeIfAbsent(player, k -> new Progress());
    }

    public void changed() {
        setDirty();
    }
}
