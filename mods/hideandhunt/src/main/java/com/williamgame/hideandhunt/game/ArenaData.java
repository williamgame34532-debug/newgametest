package com.williamgame.hideandhunt.game;

import net.minecraft.core.BlockPos;
import net.minecraft.core.HolderLookup;
import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.Tag;
import net.minecraft.resources.ResourceKey;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.saveddata.SavedData;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Persistent arena configuration (one arena per world) plus crash-safe player snapshots.
 * Stored in the overworld data storage as "hideandhunt_arena".
 */
public class ArenaData extends SavedData {
    public static final String FILE = "hideandhunt_arena";

    public String name = "Arena";
    public String dimension = "minecraft:overworld";
    public SpawnPoint lobby;
    public SpawnPoint spectator;
    public final List<SpawnPoint> hiderSpawns = new ArrayList<>();
    public final List<SpawnPoint> hunterSpawns = new ArrayList<>();
    public BlockPos cornerA;
    public BlockPos cornerB;
    public final GameSettings settings = new GameSettings();
    /** Lobby choices of sides (persisted so that a map can be prepared before players join). */
    public final Map<UUID, Side> sides = new LinkedHashMap<>();
    /** Last known names for the roster. */
    public final Map<UUID, String> names = new HashMap<>();
    /** Player state saved at round start, restored when the round ends (or at next login after a crash). */
    public final Map<UUID, CompoundTag> snapshots = new HashMap<>();
    /** Scoreboard team the player had before we coloured them, restored later ("" = none). */
    public final Map<UUID, String> prevTeams = new HashMap<>();
    public ListTag hiderKit = new ListTag();
    public ListTag hunterKit = new ListTag();
    /** Name of the sidebar objective that was displayed before a round, restored afterwards. */
    public String prevSidebar = "";
    public int roundsPlayed;

    public static ArenaData get(MinecraftServer server) {
        return server.overworld().getDataStorage().computeIfAbsent(
                new SavedData.Factory<>(ArenaData::new, ArenaData::load, null), FILE);
    }

    public ResourceKey<Level> dimensionKey() {
        ResourceLocation rl = ResourceLocation.tryParse(dimension);
        if (rl == null) rl = ResourceLocation.withDefaultNamespace("overworld");
        return ResourceKey.create(Registries.DIMENSION, rl);
    }

    public boolean hasBounds() {
        return cornerA != null && cornerB != null;
    }

    public boolean insideBounds(double x, double y, double z) {
        if (!hasBounds()) return true;
        double minX = Math.min(cornerA.getX(), cornerB.getX()) - 0.5, maxX = Math.max(cornerA.getX(), cornerB.getX()) + 1.5;
        double minY = Math.min(cornerA.getY(), cornerB.getY()) - 1.0, maxY = Math.max(cornerA.getY(), cornerB.getY()) + 2.0;
        double minZ = Math.min(cornerA.getZ(), cornerB.getZ()) - 0.5, maxZ = Math.max(cornerA.getZ(), cornerB.getZ()) + 1.5;
        return x >= minX && x <= maxX && y >= minY && y <= maxY && z >= minZ && z <= maxZ;
    }

    public Side sideOf(UUID id) {
        return sides.getOrDefault(id, Side.NONE);
    }

    public void setSide(UUID id, Side side) {
        if (side == null || side == Side.NONE) sides.remove(id);
        else sides.put(id, side);
        setDirty();
    }

    public ListTag kit(Side side) {
        return side == Side.HUNTER ? hunterKit : hiderKit;
    }

    public void setKit(Side side, ListTag tag) {
        if (side == Side.HUNTER) hunterKit = tag;
        else hiderKit = tag;
        setDirty();
    }

    /** Wipe the whole arena configuration (snapshots are kept so nobody loses items). */
    public void resetArena() {
        name = "Arena";
        dimension = "minecraft:overworld";
        lobby = null;
        spectator = null;
        hiderSpawns.clear();
        hunterSpawns.clear();
        cornerA = null;
        cornerB = null;
        settings.resetToDefaults();
        sides.clear();
        hiderKit = new ListTag();
        hunterKit = new ListTag();
        setDirty();
    }

    // ---------------------------------------------------------------- NBT

    private static ListTag spawnList(List<SpawnPoint> list) {
        ListTag l = new ListTag();
        for (SpawnPoint p : list) l.add(p.save());
        return l;
    }

    private static void readSpawns(ListTag l, List<SpawnPoint> out) {
        out.clear();
        for (int i = 0; i < l.size(); i++) out.add(SpawnPoint.load(l.getCompound(i)));
    }

    public static ArenaData load(CompoundTag tag, HolderLookup.Provider registries) {
        ArenaData d = new ArenaData();
        d.name = tag.contains("name") ? tag.getString("name") : "Arena";
        d.dimension = tag.contains("dimension") ? tag.getString("dimension") : "minecraft:overworld";
        if (tag.contains("lobby")) d.lobby = SpawnPoint.load(tag.getCompound("lobby"));
        if (tag.contains("spectator")) d.spectator = SpawnPoint.load(tag.getCompound("spectator"));
        readSpawns(tag.getList("hiderSpawns", Tag.TAG_COMPOUND), d.hiderSpawns);
        readSpawns(tag.getList("hunterSpawns", Tag.TAG_COMPOUND), d.hunterSpawns);
        if (tag.contains("cornerA")) d.cornerA = BlockPos.of(tag.getLong("cornerA"));
        if (tag.contains("cornerB")) d.cornerB = BlockPos.of(tag.getLong("cornerB"));
        d.settings.load(tag.getCompound("settings"));
        ListTag sides = tag.getList("sides", Tag.TAG_COMPOUND);
        for (int i = 0; i < sides.size(); i++) {
            CompoundTag s = sides.getCompound(i);
            if (!s.hasUUID("id")) continue;
            UUID id = s.getUUID("id");
            Side side = Side.byOrdinal(s.getInt("side"));
            if (side != Side.NONE) d.sides.put(id, side);
            if (s.contains("name")) d.names.put(id, s.getString("name"));
        }
        ListTag snaps = tag.getList("snapshots", Tag.TAG_COMPOUND);
        for (int i = 0; i < snaps.size(); i++) {
            CompoundTag s = snaps.getCompound(i);
            if (s.hasUUID("id")) d.snapshots.put(s.getUUID("id"), s.getCompound("data"));
        }
        ListTag teams = tag.getList("prevTeams", Tag.TAG_COMPOUND);
        for (int i = 0; i < teams.size(); i++) {
            CompoundTag s = teams.getCompound(i);
            if (s.hasUUID("id")) d.prevTeams.put(s.getUUID("id"), s.getString("team"));
        }
        d.hiderKit = tag.getList("hiderKit", Tag.TAG_COMPOUND);
        d.hunterKit = tag.getList("hunterKit", Tag.TAG_COMPOUND);
        d.prevSidebar = tag.getString("prevSidebar");
        d.roundsPlayed = tag.getInt("roundsPlayed");
        return d;
    }

    @Override
    public CompoundTag save(CompoundTag tag, HolderLookup.Provider registries) {
        tag.putString("name", name);
        tag.putString("dimension", dimension);
        if (lobby != null) tag.put("lobby", lobby.save());
        if (spectator != null) tag.put("spectator", spectator.save());
        tag.put("hiderSpawns", spawnList(hiderSpawns));
        tag.put("hunterSpawns", spawnList(hunterSpawns));
        if (cornerA != null) tag.putLong("cornerA", cornerA.asLong());
        if (cornerB != null) tag.putLong("cornerB", cornerB.asLong());
        tag.put("settings", settings.save());
        ListTag sl = new ListTag();
        java.util.Set<UUID> ids = new java.util.LinkedHashSet<>(sides.keySet());
        ids.addAll(names.keySet());
        for (UUID id : ids) {
            CompoundTag s = new CompoundTag();
            s.putUUID("id", id);
            s.putInt("side", sideOf(id).ordinal());
            String n = names.get(id);
            if (n != null) s.putString("name", n);
            sl.add(s);
        }
        tag.put("sides", sl);
        ListTag snaps = new ListTag();
        for (Map.Entry<UUID, CompoundTag> e : snapshots.entrySet()) {
            CompoundTag s = new CompoundTag();
            s.putUUID("id", e.getKey());
            s.put("data", e.getValue());
            snaps.add(s);
        }
        tag.put("snapshots", snaps);
        ListTag teams = new ListTag();
        for (Map.Entry<UUID, String> e : prevTeams.entrySet()) {
            CompoundTag s = new CompoundTag();
            s.putUUID("id", e.getKey());
            s.putString("team", e.getValue());
            teams.add(s);
        }
        tag.put("prevTeams", teams);
        tag.put("hiderKit", hiderKit);
        tag.put("hunterKit", hunterKit);
        tag.putString("prevSidebar", prevSidebar);
        tag.putInt("roundsPlayed", roundsPlayed);
        return tag;
    }
}
