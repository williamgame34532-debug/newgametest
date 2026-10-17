package com.zone19.scp.world;

import com.zone19.scp.Zone19Mod;
import com.zone19.scp.config.Zone19Config;
import com.zone19.scp.story.StoryData;
import com.zone19.scp.story.StoryManager;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.ListTag;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.levelgen.Heightmap;
import org.jetbrains.annotations.Nullable;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/** Getting players in and out of the Zone-19 dimension. */
public final class ZoneManager {
    public static final ResourceKey<Level> ZONE = ResourceKey.create(Registries.DIMENSION, Zone19Mod.id("zone19"));
    private static final Map<UUID, ListTag> SAVED_INVENTORIES = new HashMap<>();

    public static boolean isInZone(Player p) {
        return p.level().dimension().equals(ZONE);
    }

    @Nullable
    public static ServerLevel zone(MinecraftServer server) {
        return server.getLevel(ZONE);
    }

    public static void ensureBuilt(MinecraftServer server) {
        StoryData d = StoryData.get(server);
        ServerLevel zone = zone(server);
        if (zone == null || d.built) return;
        FacilityBuilder.build(zone);
        d.built = true;
        d.setDirty();
    }

    public static void enter(ServerPlayer p) {
        MinecraftServer server = p.server;
        ServerLevel zone = zone(server);
        if (zone == null) {
            p.sendSystemMessage(Component.translatable("message.scpzone19.no_dimension").withStyle(ChatFormatting.RED));
            return;
        }
        ensureBuilt(server);
        StoryData d = StoryData.get(server);
        BlockPos cp = ZoneLayout.checkpoint(d.chapter);
        p.teleportTo(zone, cp.getX() + 0.5, cp.getY(), cp.getZ() + 0.5, -90.0F, 0.0F);
        if (Zone19Config.COMMON.adventureInZone.get() && p.gameMode.getGameModeForPlayer() == GameType.SURVIVAL) {
            p.setGameMode(GameType.ADVENTURE);
            PlayerFlags.set(p, "was_survival", true);
        }
        PlayerFlags.set(p, "entered", true);
        StoryManager.onEnter(p);
    }

    public static void leave(ServerPlayer p) {
        MinecraftServer server = p.server;
        ServerLevel overworld = server.overworld();
        BlockPos spawn = overworld.getSharedSpawnPos();
        int y = overworld.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, spawn.getX(), spawn.getZ());
        p.teleportTo(overworld, spawn.getX() + 0.5, y, spawn.getZ() + 0.5, p.getYRot(), 0.0F);
        if (PlayerFlags.get(p, "was_survival") && p.gameMode.getGameModeForPlayer() == GameType.ADVENTURE) {
            p.setGameMode(GameType.SURVIVAL);
        }
        PlayerFlags.set(p, "was_survival", false);
        p.setRespawnPosition(Level.OVERWORLD, null, 0.0F, false, false);
    }

    public static void onLogin(ServerPlayer p) {
        if (Zone19Config.COMMON.autoEnterZone.get() && !PlayerFlags.get(p, "entered")) {
            enter(p);
        } else {
            StoryManager.sync(p);
        }
    }

    /** Death inside the facility keeps the inventory (keycards are story-critical). */
    public static void onDeath(ServerPlayer p) {
        if (!isInZone(p) || !Zone19Config.COMMON.keepInventoryInZone.get()) return;
        if (p.level().getGameRules().getBoolean(net.minecraft.world.level.GameRules.RULE_KEEPINVENTORY)) return;
        SAVED_INVENTORIES.put(p.getUUID(), p.getInventory().save(new ListTag()));
        p.getInventory().clearContent();
    }

    public static void onClone(Player original, Player fresh) {
        ListTag saved = SAVED_INVENTORIES.remove(original.getUUID());
        if (saved != null) fresh.getInventory().load(saved);
    }

    private ZoneManager() {
    }
}
