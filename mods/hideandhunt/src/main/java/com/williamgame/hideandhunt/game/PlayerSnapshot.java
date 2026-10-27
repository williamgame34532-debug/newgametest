package com.williamgame.hideandhunt.game;

import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.Tag;
import net.minecraft.resources.ResourceKey;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.Level;

/** Saves and restores everything a round may change on a player. */
public final class PlayerSnapshot {
    private PlayerSnapshot() {}

    public static CompoundTag capture(ServerPlayer p) {
        CompoundTag t = new CompoundTag();
        t.put("inv", p.getInventory().save(new ListTag()));
        // ender chest too: during a round the player could move their own items between it and the
        // (wiped) round inventory, or stash kit items in it
        t.put("ender", p.getEnderChestInventory().createTag(p.registryAccess()));
        t.putInt("gamemode", p.gameMode.getGameModeForPlayer().getId());
        t.putFloat("health", p.getHealth());
        t.putInt("food", p.getFoodData().getFoodLevel());
        t.putFloat("saturation", p.getFoodData().getSaturationLevel());
        ListTag effects = new ListTag();
        for (MobEffectInstance e : p.getActiveEffects()) effects.add(e.save());
        t.put("effects", effects);
        t.putString("dim", p.level().dimension().location().toString());
        t.putDouble("x", p.getX());
        t.putDouble("y", p.getY());
        t.putDouble("z", p.getZ());
        t.putFloat("yaw", p.getYRot());
        t.putFloat("pitch", p.getXRot());
        return t;
    }

    /**
     * Restores inventory, game mode, effects, health and hunger.
     * If {@code lobby} is null the player is also teleported back to where they were when the round started.
     */
    public static void restore(ServerPlayer p, CompoundTag t, boolean restoreInventory) {
        // put the cursor stack / 2x2 crafting grid back into the inventory first so they are wiped with it
        // (otherwise closing the screen later would hand round items out on top of the restored inventory)
        if (!p.hasDisconnected()) p.closeContainer();
        if (restoreInventory && t.contains("inv")) {
            p.getInventory().clearContent();
            p.getInventory().load(t.getList("inv", Tag.TAG_COMPOUND));
            p.getInventory().setChanged();
        }
        if (restoreInventory && t.contains("ender")) {
            p.getEnderChestInventory().fromTag(t.getList("ender", Tag.TAG_COMPOUND), p.registryAccess());
        }
        p.removeAllEffects();
        ListTag effects = t.getList("effects", Tag.TAG_COMPOUND);
        for (int i = 0; i < effects.size(); i++) {
            MobEffectInstance e = MobEffectInstance.load(effects.getCompound(i));
            if (e != null) p.addEffect(e);
        }
        p.setGlowingTag(false);
        p.clearFire();
        p.resetFallDistance();
        if (t.contains("gamemode")) p.setGameMode(GameType.byId(t.getInt("gamemode")));
        if (t.contains("health")) p.setHealth(Math.max(1.0F, Math.min(p.getMaxHealth(), t.getFloat("health"))));
        if (t.contains("food")) {
            p.getFoodData().setFoodLevel(t.getInt("food"));
            p.getFoodData().setSaturation(t.getFloat("saturation"));
        }
    }

    public static void teleportBack(ServerPlayer p, CompoundTag t) {
        ResourceLocation rl = ResourceLocation.tryParse(t.getString("dim"));
        if (rl == null) return;
        ResourceKey<Level> key = ResourceKey.create(Registries.DIMENSION, rl);
        ServerLevel level = p.server.getLevel(key);
        if (level == null) return;
        p.teleportTo(level, t.getDouble("x"), t.getDouble("y"), t.getDouble("z"), t.getFloat("yaw"), t.getFloat("pitch"));
    }
}
