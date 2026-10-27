package com.williamgame.modcritic;

import com.williamgame.modcritic.network.ServerResultsPacket;
import net.minecraft.core.HolderLookup;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.saveddata.SavedData;

import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Server-side storage of every player's ratings (world/data/modcritic_ratings.dat). */
public class CriticSavedData extends SavedData {
    public static final int MAX_MODS_PER_PLAYER = 512;

    public static final class PlayerData {
        public String name;
        public final Map<String, RatingEntry> ratings = new LinkedHashMap<>();

        PlayerData(String name) {
            this.name = name;
        }
    }

    private final Map<UUID, PlayerData> players = new LinkedHashMap<>();

    public static CriticSavedData get(MinecraftServer server) {
        return server.overworld().getDataStorage().computeIfAbsent(
                new SavedData.Factory<>(CriticSavedData::new, CriticSavedData::load, null), "modcritic_ratings");
    }

    public static CriticSavedData load(CompoundTag tag, HolderLookup.Provider registries) {
        CriticSavedData d = new CriticSavedData();
        CompoundTag ps = tag.getCompound("players");
        for (String key : ps.getAllKeys()) {
            UUID uuid;
            try {
                uuid = UUID.fromString(key);
            } catch (IllegalArgumentException ex) {
                continue;
            }
            CompoundTag pt = ps.getCompound(key);
            PlayerData pd = new PlayerData(pt.getString("name"));
            CompoundTag mods = pt.getCompound("mods");
            for (String modId : mods.getAllKeys()) {
                CompoundTag mt = mods.getCompound(modId);
                RatingEntry e = new RatingEntry();
                e.modId = modId;
                e.modName = mt.getString("name");
                e.scores = mt.getIntArray("scores");
                e.comment = mt.getString("comment");
                e.time = mt.getLong("time");
                pd.ratings.put(modId, e.sanitize());
            }
            d.players.put(uuid, pd);
        }
        return d;
    }

    @Override
    public CompoundTag save(CompoundTag tag, HolderLookup.Provider registries) {
        CompoundTag ps = new CompoundTag();
        for (Map.Entry<UUID, PlayerData> pe : players.entrySet()) {
            CompoundTag pt = new CompoundTag();
            pt.putString("name", pe.getValue().name);
            CompoundTag mods = new CompoundTag();
            for (RatingEntry e : pe.getValue().ratings.values()) {
                CompoundTag mt = new CompoundTag();
                mt.putString("name", e.modName);
                mt.putIntArray("scores", e.scores);
                mt.putString("comment", e.comment);
                mt.putLong("time", e.time);
                mods.put(e.modId, mt);
            }
            pt.put("mods", mods);
            ps.put(pe.getKey().toString(), pt);
        }
        tag.put("players", ps);
        return tag;
    }

    public void put(UUID player, String name, RatingEntry entry) {
        PlayerData pd = players.computeIfAbsent(player, k -> new PlayerData(name));
        pd.name = name;
        if (!pd.ratings.containsKey(entry.modId) && pd.ratings.size() >= MAX_MODS_PER_PLAYER) return;
        RatingEntry e = entry.copy().sanitize();
        e.time = System.currentTimeMillis();
        pd.ratings.put(e.modId, e);
        setDirty();
    }

    public void remove(UUID player, String modId) {
        PlayerData pd = players.get(player);
        if (pd != null && pd.ratings.remove(modId) != null) {
            if (pd.ratings.isEmpty()) players.remove(player);
            setDirty();
        }
    }

    public boolean clearPlayer(String name) {
        boolean changed = players.values().removeIf(p -> p.name.equalsIgnoreCase(name));
        if (changed) setDirty();
        return changed;
    }

    public void clearAll() {
        players.clear();
        setDirty();
    }

    public Collection<PlayerData> players() {
        return players.values();
    }

    public PlayerData byName(String name) {
        for (PlayerData p : players.values()) {
            if (p.name.equalsIgnoreCase(name)) return p;
        }
        return null;
    }

    /** player name -> entries, for {@link Scoring#average}. */
    public Map<String, Collection<RatingEntry>> byPlayerName() {
        Map<String, Collection<RatingEntry>> m = new LinkedHashMap<>();
        for (PlayerData p : players.values()) {
            if (!p.ratings.isEmpty()) m.put(p.name, p.ratings.values());
        }
        return m;
    }

    public ServerResultsPacket toPacket() {
        List<ServerResultsPacket.PlayerRatings> list = new ArrayList<>();
        for (PlayerData p : players.values()) {
            List<RatingEntry> entries = new ArrayList<>();
            for (RatingEntry e : p.ratings.values()) entries.add(e.copy());
            list.add(new ServerResultsPacket.PlayerRatings(p.name, entries));
        }
        return new ServerResultsPacket(list);
    }
}
