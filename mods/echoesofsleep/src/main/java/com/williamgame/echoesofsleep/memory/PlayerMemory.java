package com.williamgame.echoesofsleep.memory;

import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.Tag;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.player.Player;

import java.util.ArrayList;
import java.util.List;

/**
 * The "Trace" (След): everything a player did, stored server-side in the player's persistent data
 * (copied on respawn in {@link com.williamgame.echoesofsleep.event.CommonEvents}).
 * This is a thin live view over a CompoundTag: every setter writes straight into the player's data.
 */
public class PlayerMemory {
    public static final String KEY = "echoesofsleep_memory";
    public static final int PATH_CAPACITY = 96;
    public static final int DEATH_CAPACITY = 8;

    private final CompoundTag tag;

    private PlayerMemory(CompoundTag tag) {
        this.tag = tag;
    }

    public static PlayerMemory of(Player player) {
        CompoundTag pd = player.getPersistentData();
        if (!pd.contains(KEY, Tag.TAG_COMPOUND)) {
            pd.put(KEY, new CompoundTag());
        }
        return new PlayerMemory(pd.getCompound(KEY));
    }

    public CompoundTag raw() {
        return tag;
    }

    // ---- Dread -------------------------------------------------------------------------------
    public float dread() {
        return tag.getFloat("dread");
    }

    public void setDread(float value) {
        tag.putFloat("dread", Mth.clamp(value, 0.0F, 100.0F));
    }

    public void addDread(float delta) {
        setDread(dread() + delta);
    }

    // ---- Kills -------------------------------------------------------------------------------
    public void recordKill(String entityTypeId, boolean hostile) {
        CompoundTag kills = tag.getCompound("kills");
        kills.putInt(entityTypeId, kills.getInt(entityTypeId) + 1);
        tag.put("kills", kills);
        tag.putInt("totalKills", totalKills() + 1);
        if (hostile) {
            tag.putInt("hostileKills", hostileKills() + 1);
        }
    }

    public int totalKills() {
        return tag.getInt("totalKills");
    }

    public int hostileKills() {
        return tag.getInt("hostileKills");
    }

    /** Entity type ids the player killed most, most frequent first (used for Stitcher patchwork). */
    public List<String> topKilledTypes(int max) {
        CompoundTag kills = tag.getCompound("kills");
        List<String> keys = new ArrayList<>(kills.getAllKeys());
        keys.sort((a, b) -> Integer.compare(kills.getInt(b), kills.getInt(a)));
        return keys.size() > max ? keys.subList(0, max) : keys;
    }

    public int echoesSlain() {
        return tag.getInt("echoesSlain");
    }

    public void addEchoSlain() {
        tag.putInt("echoesSlain", echoesSlain() + 1);
    }

    // ---- Deaths ------------------------------------------------------------------------------
    public void recordDeath(BlockPos pos, String dimension) {
        ListTag list = tag.getList("deathPositions", Tag.TAG_COMPOUND);
        CompoundTag d = new CompoundTag();
        d.putLong("pos", pos.asLong());
        d.putString("dim", dimension);
        list.add(d);
        while (list.size() > DEATH_CAPACITY) {
            list.remove(0);
        }
        tag.put("deathPositions", list);
        tag.putInt("deaths", deaths() + 1);
    }

    public int deaths() {
        return tag.getInt("deaths");
    }

    public List<BlockPos> deathPositions(String dimension) {
        ListTag list = tag.getList("deathPositions", Tag.TAG_COMPOUND);
        List<BlockPos> out = new ArrayList<>();
        for (int i = 0; i < list.size(); i++) {
            CompoundTag d = list.getCompound(i);
            if (d.getString("dim").equals(dimension)) {
                out.add(BlockPos.of(d.getLong("pos")));
            }
        }
        return out;
    }

    // ---- Blocks ------------------------------------------------------------------------------
    public void addPlaced() {
        tag.putInt("placed", placed() + 1);
    }

    public int placed() {
        return tag.getInt("placed");
    }

    public void addBroken() {
        tag.putInt("broken", broken() + 1);
    }

    public int broken() {
        return tag.getInt("broken");
    }

    // ---- Underground / darkness (seconds) ----------------------------------------------------
    public void addUnderground(int seconds) {
        tag.putInt("underground", underground() + seconds);
    }

    public int underground() {
        return tag.getInt("underground");
    }

    public void addDarkness(int seconds) {
        tag.putInt("darkness", darkness() + seconds);
    }

    public int darkness() {
        return tag.getInt("darkness");
    }

    // ---- Villagers ---------------------------------------------------------------------------
    public void addVillagerHurt() {
        tag.putInt("villagersHurt", villagersHurt() + 1);
    }

    public int villagersHurt() {
        return tag.getInt("villagersHurt");
    }

    // ---- Sleep -------------------------------------------------------------------------------
    public int nightsWithoutSleep() {
        return tag.getInt("nightsNoSleep");
    }

    public void setNightsWithoutSleep(int n) {
        tag.putInt("nightsNoSleep", Math.max(0, n));
    }

    public boolean sleptTonight() {
        return tag.getBoolean("sleptTonight");
    }

    public void setSleptTonight(boolean v) {
        tag.putBoolean("sleptTonight", v);
    }

    public long lastDay() {
        return tag.contains("lastDay") ? tag.getLong("lastDay") : -1L;
    }

    public void setLastDay(long day) {
        tag.putLong("lastDay", day);
    }

    // ---- Path ring buffer --------------------------------------------------------------------
    public void recordPathPoint(BlockPos pos, String dimension) {
        if (!dimension.equals(tag.getString("pathDim"))) {
            tag.putLongArray("path", new long[0]);
            tag.putString("pathDim", dimension);
        }
        long[] path = tag.getLongArray("path");
        if (path.length > 0) {
            BlockPos last = BlockPos.of(path[path.length - 1]);
            if (last.distSqr(pos) < 4.0) {
                return; // standing still: don't waste the buffer
            }
        }
        long[] next;
        if (path.length < PATH_CAPACITY) {
            next = new long[path.length + 1];
            System.arraycopy(path, 0, next, 0, path.length);
        } else {
            next = new long[PATH_CAPACITY];
            System.arraycopy(path, 1, next, 0, PATH_CAPACITY - 1);
        }
        next[next.length - 1] = pos.asLong();
        tag.putLongArray("path", next);
    }

    /** When the player sleeps, today's path becomes the "dream path" that Echo Doppelgangers walk. */
    public void archivePathAsDream() {
        tag.putLongArray("dreamPath", tag.getLongArray("path"));
        tag.putString("dreamPathDim", tag.getString("pathDim"));
    }

    public List<BlockPos> dreamPath(String dimension) {
        List<BlockPos> out = new ArrayList<>();
        String key = tag.contains("dreamPath") && tag.getLongArray("dreamPath").length > 0 ? "dreamPath" : "path";
        String dimKey = key.equals("dreamPath") ? "dreamPathDim" : "pathDim";
        if (!dimension.equals(tag.getString(dimKey))) {
            return out;
        }
        for (long l : tag.getLongArray(key)) {
            out.add(BlockPos.of(l));
        }
        return out;
    }

    /** Copy everything to a respawned player. */
    public static void copy(Entity from, Entity to) {
        CompoundTag src = from.getPersistentData().getCompound(KEY);
        to.getPersistentData().put(KEY, src.copy());
    }
}
