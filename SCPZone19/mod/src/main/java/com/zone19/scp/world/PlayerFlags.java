package com.zone19.scp.world;

import net.minecraft.nbt.CompoundTag;
import net.minecraft.world.entity.player.Player;

/** Small per-player flags that survive death (Forge copies the PERSISTED tag on respawn). */
public final class PlayerFlags {
    private static final String ROOT = "scpzone19";

    private static CompoundTag root(Player p) {
        CompoundTag persisted = p.getPersistentData().getCompound(Player.PERSISTED_NBT_TAG);
        CompoundTag mine = persisted.getCompound(ROOT);
        persisted.put(ROOT, mine);
        p.getPersistentData().put(Player.PERSISTED_NBT_TAG, persisted);
        return mine;
    }

    public static boolean get(Player p, String key) {
        return root(p).getBoolean(key);
    }

    public static void set(Player p, String key, boolean value) {
        root(p).putBoolean(key, value);
    }

    public static String getString(Player p, String key) {
        return root(p).getString(key);
    }

    public static void setString(Player p, String key, String value) {
        root(p).putString(key, value);
    }

    private PlayerFlags() {
    }
}
