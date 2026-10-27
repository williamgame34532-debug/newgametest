package com.williamgame.blockmemory.history;

import com.williamgame.blockmemory.MemoryConfig;
import it.unimi.dsi.fastutil.longs.Long2ObjectMap;
import it.unimi.dsi.fastutil.longs.Long2ObjectOpenHashMap;
import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderGetter;
import net.minecraft.core.HolderLookup;
import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.Tag;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.ChunkPos;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.saveddata.SavedData;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Per-dimension block history. Stored in the dimension's own data folder ("blockmemory_history.dat").
 * Memory/disk usage is capped per chunk and per block (see {@link MemoryConfig}).
 */
public class BlockHistoryData extends SavedData {
    public static final String NAME = "blockmemory_history";

    private record Actor(UUID id, String name) {
    }

    private final Long2ObjectMap<ChunkHistory> chunks = new Long2ObjectOpenHashMap<>();
    private final List<Actor> actors = new ArrayList<>();
    private final Map<String, Integer> actorIndex = new HashMap<>();

    public static BlockHistoryData get(ServerLevel level) {
        return level.getDataStorage().computeIfAbsent(
                new SavedData.Factory<>(BlockHistoryData::new, BlockHistoryData::load, null), NAME);
    }

    public static long nowSec() {
        return System.currentTimeMillis() / 1000L;
    }

    // ------------------------------------------------------------------ persistence

    public static BlockHistoryData load(CompoundTag tag, HolderLookup.Provider registries) {
        BlockHistoryData d = new BlockHistoryData();
        HolderGetter<Block> blocks = registries.lookupOrThrow(Registries.BLOCK);
        ListTag actorList = tag.getList("actors", Tag.TAG_COMPOUND);
        for (int i = 0; i < actorList.size(); i++) {
            CompoundTag a = actorList.getCompound(i);
            UUID id = null;
            if (a.contains("u")) {
                try {
                    id = UUID.fromString(a.getString("u"));
                } catch (IllegalArgumentException ignored) {
                }
            }
            Actor actor = new Actor(id, a.getString("n"));
            d.actors.add(actor);
            d.actorIndex.put(key(id, actor.name()), i);
        }
        CompoundTag chunkTag = tag.getCompound("chunks");
        for (String k : chunkTag.getAllKeys()) {
            try {
                long key = Long.parseLong(k);
                ChunkHistory h = ChunkHistory.load(chunkTag.getCompound(k), blocks);
                if (!h.isEmpty()) d.chunks.put(key, h);
            } catch (NumberFormatException ignored) {
            }
        }
        return d;
    }

    @Override
    public CompoundTag save(CompoundTag tag, HolderLookup.Provider registries) {
        ListTag actorList = new ListTag();
        for (Actor a : actors) {
            CompoundTag c = new CompoundTag();
            c.putString("n", a.name());
            if (a.id() != null) c.putString("u", a.id().toString());
            actorList.add(c);
        }
        tag.put("actors", actorList);
        CompoundTag chunkTag = new CompoundTag();
        for (Long2ObjectMap.Entry<ChunkHistory> e : chunks.long2ObjectEntrySet()) {
            if (!e.getValue().isEmpty()) {
                chunkTag.put(Long.toString(e.getLongKey()), e.getValue().save());
            }
        }
        tag.put("chunks", chunkTag);
        return tag;
    }

    private static String key(UUID id, String name) {
        return id != null ? id.toString() : "#" + name;
    }

    private int actorId(UUID id, String name) {
        String k = key(id, name);
        Integer idx = actorIndex.get(k);
        if (idx != null) {
            Actor existing = actors.get(idx);
            if (id != null && !existing.name().equals(name)) {
                actors.set(idx, new Actor(id, name)); // player renamed
            }
            return idx;
        }
        actors.add(new Actor(id, name));
        actorIndex.put(k, actors.size() - 1);
        return actors.size() - 1;
    }

    // ------------------------------------------------------------------ writing

    public void record(BlockPos pos, HistoryAction action, UUID actorId, String actorName, BlockState oldState, BlockState newState) {
        long key = ChunkPos.asLong(pos.getX() >> 4, pos.getZ() >> 4);
        ChunkHistory h = chunks.get(key);
        if (h == null) {
            h = new ChunkHistory();
            chunks.put(key, h);
        }
        int actor = actorId(actorId, actorName);
        h.add(new ChunkHistory.Raw(ChunkHistory.pack(pos), nowSec(), (byte) action.ordinal(), actor, oldState, newState),
                MemoryConfig.MAX_ENTRIES_PER_CHUNK.get(), MemoryConfig.MAX_ENTRIES_PER_BLOCK.get());
        setDirty();
    }

    // ------------------------------------------------------------------ reading

    private HistoryEntry toEntry(long chunkKey, ChunkHistory.Raw r) {
        Actor a = r.actor >= 0 && r.actor < actors.size() ? actors.get(r.actor) : new Actor(null, "?");
        return new HistoryEntry(ChunkHistory.unpack(chunkKey, r.localPos), r.timeSec, HistoryAction.byId(r.action),
                a.name(), a.id(), r.oldState, r.newState);
    }

    /** History of one block, newest first. */
    public List<HistoryEntry> getHistory(BlockPos pos) {
        List<HistoryEntry> out = new ArrayList<>();
        long key = ChunkPos.asLong(pos.getX() >> 4, pos.getZ() >> 4);
        ChunkHistory h = chunks.get(key);
        if (h == null) return out;
        int local = ChunkHistory.pack(pos);
        for (int i = h.entries.size() - 1; i >= 0; i--) {
            ChunkHistory.Raw r = h.entries.get(i);
            if (r.localPos == local) out.add(toEntry(key, r));
        }
        return out;
    }

    /** The newest entry of every remembered block inside a cube of the given radius. */
    public Map<BlockPos, HistoryEntry> latestAround(BlockPos center, int radius, long sinceSec) {
        Map<BlockPos, HistoryEntry> out = new HashMap<>();
        int minCx = (center.getX() - radius) >> 4, maxCx = (center.getX() + radius) >> 4;
        int minCz = (center.getZ() - radius) >> 4, maxCz = (center.getZ() + radius) >> 4;
        for (int cx = minCx; cx <= maxCx; cx++) {
            for (int cz = minCz; cz <= maxCz; cz++) {
                long key = ChunkPos.asLong(cx, cz);
                ChunkHistory h = chunks.get(key);
                if (h == null) continue;
                // chronological order: later entries overwrite earlier ones
                for (ChunkHistory.Raw r : h.entries) {
                    if (r.timeSec < sinceSec) continue;
                    BlockPos p = ChunkHistory.unpack(key, r.localPos);
                    if (Math.abs(p.getX() - center.getX()) > radius || Math.abs(p.getY() - center.getY()) > radius
                            || Math.abs(p.getZ() - center.getZ()) > radius) continue;
                    out.put(p, toEntry(key, r));
                }
            }
        }
        return out;
    }

    /** All entries in a cube (any number per block), oldest first. */
    public List<HistoryEntry> allAround(BlockPos center, int radius, long sinceSec) {
        List<HistoryEntry> out = new ArrayList<>();
        int minCx = (center.getX() - radius) >> 4, maxCx = (center.getX() + radius) >> 4;
        int minCz = (center.getZ() - radius) >> 4, maxCz = (center.getZ() + radius) >> 4;
        for (int cx = minCx; cx <= maxCx; cx++) {
            for (int cz = minCz; cz <= maxCz; cz++) {
                long key = ChunkPos.asLong(cx, cz);
                ChunkHistory h = chunks.get(key);
                if (h == null) continue;
                for (ChunkHistory.Raw r : h.entries) {
                    if (r.timeSec < sinceSec) continue;
                    BlockPos p = ChunkHistory.unpack(key, r.localPos);
                    if (Math.abs(p.getX() - center.getX()) > radius || Math.abs(p.getY() - center.getY()) > radius
                            || Math.abs(p.getZ() - center.getZ()) > radius) continue;
                    out.add(toEntry(key, r));
                }
            }
        }
        return out;
    }

    /** Forget everything inside a cube. Returns the number of forgotten entries. */
    public int clear(BlockPos center, int radius) {
        int removed = 0;
        int minCx = (center.getX() - radius) >> 4, maxCx = (center.getX() + radius) >> 4;
        int minCz = (center.getZ() - radius) >> 4, maxCz = (center.getZ() + radius) >> 4;
        for (int cx = minCx; cx <= maxCx; cx++) {
            for (int cz = minCz; cz <= maxCz; cz++) {
                long key = ChunkPos.asLong(cx, cz);
                ChunkHistory h = chunks.get(key);
                if (h == null) continue;
                int before = h.entries.size();
                h.entries.removeIf(r -> {
                    BlockPos p = ChunkHistory.unpack(key, r.localPos);
                    return Math.abs(p.getX() - center.getX()) <= radius && Math.abs(p.getY() - center.getY()) <= radius
                            && Math.abs(p.getZ() - center.getZ()) <= radius;
                });
                removed += before - h.entries.size();
                if (h.isEmpty()) chunks.remove(key);
            }
        }
        if (removed > 0) setDirty();
        return removed;
    }

    public int chunkCount() {
        return chunks.size();
    }

    public int entryCount() {
        int n = 0;
        for (ChunkHistory h : chunks.values()) n += h.entries.size();
        return n;
    }
}
