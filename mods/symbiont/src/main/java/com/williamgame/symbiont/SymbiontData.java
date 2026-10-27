package com.williamgame.symbiont;

import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.StringTag;
import net.minecraft.nbt.Tag;
import net.minecraft.world.entity.player.Player;

import java.util.UUID;

/**
 * Per-player symbiont state. It is a thin view over a CompoundTag stored in the player's Forge
 * persistent data, so it survives logout, death (copied in PlayerEvent.Clone) and server restarts
 * even while the companion entity itself does not exist.
 */
public class SymbiontData {
    public static final String KEY = "symbiont_data";

    public static final int STATE_NONE = 0;   // never got an egg
    public static final int STATE_EGG = 1;    // has an egg, not hatched yet
    public static final int STATE_ALIVE = 2;  // companion exists (or will be summoned next to the owner)
    public static final int STATE_DEAD = 3;   // waiting to respawn
    public static final int STATE_LEFT = 4;   // left forever

    public static final int MAX_CHUNKS = 8192;

    private final CompoundTag tag;

    private SymbiontData(CompoundTag tag) {
        this.tag = tag;
    }

    public static SymbiontData of(Player player) {
        CompoundTag root = player.getPersistentData();
        if (!root.contains(KEY, Tag.TAG_COMPOUND)) {
            root.put(KEY, new CompoundTag());
        }
        return new SymbiontData(root.getCompound(KEY));
    }

    public CompoundTag raw() {
        return tag;
    }

    /** Resets everything for a freshly hatched companion (keeps nothing from a previous one). */
    public void resetForHatch(String name, int seed, long now) {
        for (String k : tag.getAllKeys().toArray(new String[0])) {
            tag.remove(k);
        }
        setState(STATE_ALIVE);
        setName(name);
        setBond(50);
        setSatiety(80);
        setBranch(-1);
        setStage(0);
        tag.putInt("seed", seed);
        tag.putLong("hatched", now);
        tag.putBoolean("eggGiven", true);
        tag.putInt("generation", generation() + 1);
    }

    // ---------------------------------------------------------------- basic fields
    public int state() { return tag.getInt("state"); }
    public void setState(int s) { tag.putInt("state", s); }

    public boolean eggGiven() { return tag.getBoolean("eggGiven"); }
    public void setEggGiven(boolean b) { tag.putBoolean("eggGiven", b); }

    public String name() {
        String n = tag.getString("name");
        return n.isEmpty() ? "Symbiont" : n;
    }
    public void setName(String n) { tag.putString("name", n); }

    public double xp(Branch b) { return tag.getDouble("xp_" + b.id); }
    public void setXp(Branch b, double v) { tag.putDouble("xp_" + b.id, Math.max(0, v)); }

    public Branch branch() { return Branch.byIndex(tag.contains("branch") ? tag.getInt("branch") : -1); }
    public void setBranch(int i) { tag.putInt("branch", i); }

    public int stage() { return tag.getInt("stage"); }
    public void setStage(int s) { tag.putInt("stage", Math.max(0, Math.min(3, s))); }

    public Form form() { return Form.of(branch(), stage()); }

    public double bond() { return tag.getDouble("bond"); }
    public void setBond(double v) { tag.putDouble("bond", Math.max(0, Math.min(100, v))); }

    public double satiety() { return tag.getDouble("satiety"); }
    public void setSatiety(double v) { tag.putDouble("satiety", Math.max(0, Math.min(100, v))); }

    public long respawnAt() { return tag.getLong("respawnAt"); }
    public void setRespawnAt(long t) { tag.putLong("respawnAt", t); }

    public UUID entityUuid() { return tag.hasUUID("entity") ? tag.getUUID("entity") : null; }
    public void setEntityUuid(UUID id) {
        if (id == null) tag.remove("entity");
        else tag.putUUID("entity", id);
    }

    public float health() { return tag.getFloat("health"); }
    public void setHealth(float h) { tag.putFloat("health", h); }

    public int seed() { return tag.getInt("seed"); }
    public long hatchedAt() { return tag.getLong("hatched"); }
    public int generation() { return tag.getInt("generation"); }

    public int deaths() { return tag.getInt("deaths"); }
    public void addDeath() { tag.putInt("deaths", deaths() + 1); }

    public long ticksTogether() { return tag.getLong("together"); }
    public void addTicksTogether(long t) { tag.putLong("together", ticksTogether() + t); }

    // ---------------------------------------------------------------- nest
    public boolean hasNest() { return tag.contains("nestPos"); }
    public BlockPos nestPos() { return BlockPos.of(tag.getLong("nestPos")); }
    public String nestDim() { return tag.getString("nestDim"); }
    public void setNest(BlockPos pos, String dim) {
        tag.putLong("nestPos", pos.asLong());
        tag.putString("nestDim", dim);
    }
    public void clearNest() {
        tag.remove("nestPos");
        tag.remove("nestDim");
    }

    // ---------------------------------------------------------------- timers / counters
    public long getTime(String key) { return tag.getLong(key); }
    public void setTime(String key, long v) { tag.putLong(key, v); }
    public int getCounter(String key) { return tag.getInt(key); }
    public void setCounter(String key, int v) { tag.putInt(key, v); }
    public boolean getFlag(String key) { return tag.getBoolean(key); }
    public void setFlag(String key, boolean v) { tag.putBoolean(key, v); }
    public String getString(String key) { return tag.getString(key); }
    public void setString(String key, String v) { tag.putString(key, v); }

    // ---------------------------------------------------------------- exploration memory
    public long[] chunks() { return tag.getLongArray("chunks"); }
    public void setChunks(long[] arr) { tag.putLongArray("chunks", arr); }

    public boolean hasVisited(String listKey, String value) {
        ListTag list = tag.getList(listKey, Tag.TAG_STRING);
        for (int i = 0; i < list.size(); i++) {
            if (list.getString(i).equals(value)) return true;
        }
        return false;
    }

    /** @return true if it was new */
    public boolean markVisited(String listKey, String value, int cap) {
        if (hasVisited(listKey, value)) return false;
        ListTag list = tag.getList(listKey, Tag.TAG_STRING);
        if (list.size() >= cap) list.remove(0);
        list.add(StringTag.valueOf(value));
        tag.put(listKey, list);
        return true;
    }

    public int visitedCount(String listKey) {
        return tag.getList(listKey, Tag.TAG_STRING).size();
    }
}
