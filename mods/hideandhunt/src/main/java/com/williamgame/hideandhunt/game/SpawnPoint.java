package com.williamgame.hideandhunt.game;

import net.minecraft.nbt.CompoundTag;

public record SpawnPoint(double x, double y, double z, float yaw, float pitch) {
    public CompoundTag save() {
        CompoundTag t = new CompoundTag();
        t.putDouble("x", x);
        t.putDouble("y", y);
        t.putDouble("z", z);
        t.putFloat("yaw", yaw);
        t.putFloat("pitch", pitch);
        return t;
    }

    public static SpawnPoint load(CompoundTag t) {
        return new SpawnPoint(t.getDouble("x"), t.getDouble("y"), t.getDouble("z"), t.getFloat("yaw"), t.getFloat("pitch"));
    }

    public double distSqr(double px, double py, double pz) {
        double dx = px - x, dy = py - y, dz = pz - z;
        return dx * dx + dy * dy + dz * dz;
    }

    public String shortString() {
        return String.format(java.util.Locale.ROOT, "%.1f %.1f %.1f", x, y, z);
    }
}
