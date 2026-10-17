package com.zone19.scp.story;

import com.zone19.scp.block.LockerBlock;
import com.zone19.scp.entity.Scp096Entity;
import com.zone19.scp.item.GunItem;
import com.zone19.scp.item.KeycardItem;
import com.zone19.scp.network.Net;
import com.zone19.scp.network.StoryEventPacket;
import com.zone19.scp.network.StorySyncPacket;
import com.zone19.scp.registry.ModEntities;
import com.zone19.scp.registry.ModItems;
import com.zone19.scp.registry.ModSounds;
import com.zone19.scp.story.Chapters.Chapter;
import com.zone19.scp.story.Chapters.Line;
import com.zone19.scp.story.Chapters.Step;
import com.zone19.scp.story.Chapters.StepType;
import com.zone19.scp.world.FacilityBuilder;
import com.zone19.scp.world.PlayerFlags;
import com.zone19.scp.world.ZoneLayout;
import com.zone19.scp.world.ZoneManager;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.phys.AABB;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/** Drives the campaign: steps, chapter transitions, rewards, SCP spawns and client sync. */
public final class StoryManager {
    private static int pendingChapter;
    private static int pendingDelay;

    // ------------------------------------------------------------------ ticking
    public static void serverTick(MinecraftServer server) {
        if (pendingDelay > 0 && --pendingDelay == 0) {
            beginChapter(server, pendingChapter);
        }
        if (server.getTickCount() % 10 != 0) return;
        StoryData d = StoryData.get(server);
        if (d.chapter <= 0 || d.finished) return;
        Chapter c = Chapters.get(d.chapter);
        if (d.step >= c.steps().size()) {
            // a chapter finished but the server stopped before the next one began
            if (pendingDelay == 0) schedule(d.chapter + 1, 40);
            return;
        }
        Step s = c.steps().get(d.step);
        if (s.type() != StepType.REGION) return;
        ServerLevel zone = ZoneManager.zone(server);
        AABB box = ZoneLayout.REGIONS.get(s.target());
        if (zone == null || box == null) return;
        for (ServerPlayer p : zone.players()) {
            if (p.isAlive() && !p.isSpectator() && box.contains(p.position())) {
                advance(server, 1);
                return;
            }
        }
    }

    private static void schedule(int chapter, int delay) {
        pendingChapter = chapter;
        pendingDelay = delay;
    }

    // ------------------------------------------------------------------ progress
    private static void advance(MinecraftServer server, int amount) {
        StoryData d = StoryData.get(server);
        Step s = currentStep(d);
        if (s == null) return;
        d.progress += amount;
        d.setDirty();
        if (d.progress >= s.count()) {
            completeStep(server);
        } else {
            syncAll(server);
        }
    }

    private static void completeStep(MinecraftServer server) {
        StoryData d = StoryData.get(server);
        Chapter c = Chapters.get(d.chapter);
        Step s = c.steps().get(d.step);
        say(server, s.done());
        d.step++;
        d.progress = 0;
        d.setDirty();
        broadcastSound(server, ModSounds.RADIO_BEEP.get(), 0.6F);
        if (d.step >= c.steps().size()) {
            finishChapter(server, c);
        } else {
            syncAll(server);
        }
    }

    private static void finishChapter(MinecraftServer server, Chapter c) {
        StoryData d = StoryData.get(server);
        say(server, c.outro());
        for (ServerPlayer p : zonePlayers(server)) giveRewards(p, c.number());
        cleanup(server, c.number());
        if (c.number() >= Chapters.COUNT) {
            d.finished = true;
            d.setDirty();
            Net.toAll(StoryEventPacket.ending());
            syncAll(server);
        } else {
            syncAll(server);
            schedule(c.number() + 1, 240);
        }
    }

    public static void beginChapter(MinecraftServer server, int number) {
        StoryData d = StoryData.get(server);
        Chapter c = Chapters.get(number);
        d.chapter = c.number();
        d.step = 0;
        d.progress = 0;
        d.finished = false;
        d.setDirty();
        pendingDelay = 0;
        onChapterStart(server, c.number());
        for (ServerPlayer p : zonePlayers(server)) setCheckpoint(p, c.number());
        Net.toAll(StoryEventPacket.title(c.titleKey(), c.subtitleKey()));
        if (!c.music().isEmpty()) Net.toAll(StoryEventPacket.music(c.music()));
        say(server, c.intro());
        syncAll(server);
    }

    // ------------------------------------------------------------------ hooks from blocks/items/events
    public static boolean onInteract(ServerPlayer player, String kind) {
        StoryData d = StoryData.get(player.server);
        Step s = currentStep(d);
        if (s == null || s.type() != StepType.INTERACT || !s.target().equals(kind)) return false;
        advance(player.server, 1);
        return true;
    }

    public static void onKill(MinecraftServer server, String entity) {
        StoryData d = StoryData.get(server);
        Step s = currentStep(d);
        if (s != null && s.type() == StepType.KILL && s.target().equals(entity)) advance(server, 1);
    }

    public static void onLocker(ServerPlayer p, String kind, BlockPos pos) {
        StoryData d = StoryData.get(p.server);
        String flag = "locker_" + kind + "_" + d.epoch;
        boolean gave = false;
        switch (kind) {
            case LockerBlock.ARMORY -> {
                gave |= giveIfMissing(p, ModItems.USP.get());
                if (KeycardItem.bestLevel(p) < 2) gave |= give(p, new ItemStack(ModItems.KEYCARD_2.get()));
                gave |= giveIfMissing(p, ModItems.RADIO.get());
                gave |= giveIfMissing(p, ModItems.SNAV.get());
                gave |= giveIfMissing(p, ModItems.STUN_BATON.get());
                int ammo = GunItem.countReserve(p, ModItems.AMMO_9MM.get());
                if (ammo < 48) gave |= give(p, new ItemStack(ModItems.AMMO_9MM.get(), 48 - ammo));
                if (!PlayerFlags.get(p, flag)) {
                    PlayerFlags.set(p, flag, true);
                    give(p, new ItemStack(ModItems.FIRST_AID.get()));
                    give(p, new ItemStack(ModItems.BALLISTIC_VEST.get()));
                    gave = true;
                }
            }
            case LockerBlock.MEDICAL -> {
                if (d.chapter < 3 && !d.finished) {
                    locked(p);
                    return;
                }
                if (!PlayerFlags.get(p, flag)) {
                    PlayerFlags.set(p, flag, true);
                    give(p, new ItemStack(ModItems.SCP500.get()));
                    give(p, new ItemStack(ModItems.FIRST_AID.get(), 2));
                    give(p, new ItemStack(ModItems.EYEDROPS.get(), 2));
                    give(p, new ItemStack(ModItems.GAS_MASK.get()));
                    gave = true;
                }
            }
            case LockerBlock.O5_SAFE -> {
                if (d.chapter < 6 && !d.finished) {
                    locked(p);
                    return;
                }
                if (KeycardItem.bestLevel(p) < 5) gave |= give(p, new ItemStack(ModItems.KEYCARD_5.get()));
                if (!PlayerFlags.get(p, flag)) {
                    PlayerFlags.set(p, flag, true);
                    give(p, new ItemStack(ModItems.DOC_096.get()));
                    gave = true;
                }
            }
            default -> {
            }
        }
        p.level().playSound(null, pos, ModSounds.PICKUP.get(), SoundSource.BLOCKS, 0.8F, 1.0F);
        p.displayClientMessage(Component.translatable(gave ? "message.scpzone19.locker_ok" : "message.scpzone19.locker_empty")
                .withStyle(gave ? ChatFormatting.GREEN : ChatFormatting.GRAY), true);
        onInteract(p, kind);
    }

    private static void locked(ServerPlayer p) {
        p.level().playSound(null, p.blockPosition(), ModSounds.DOOR_ERROR.get(), SoundSource.BLOCKS, 0.7F, 1.0F);
        p.displayClientMessage(Component.translatable("message.scpzone19.locker_locked").withStyle(ChatFormatting.RED), true);
    }

    public static void onEnter(ServerPlayer p) {
        MinecraftServer server = p.server;
        StoryData d = StoryData.get(server);
        if (!PlayerFlags.get(p, "terminal_seen")) {
            PlayerFlags.set(p, "terminal_seen", true);
            Net.toPlayer(p, StoryEventPacket.openTerminal());
        }
        if (d.chapter == 0) {
            beginChapter(server, 1);
        } else {
            setCheckpoint(p, d.chapter);
            sync(p);
        }
    }

    public static void radioReport(ServerPlayer p) {
        StoryData d = StoryData.get(p.server);
        Step s = currentStep(d);
        if (d.finished) {
            Net.toPlayer(p, StoryEventPacket.dialogue(Chapters.LIN, "dlg.scpzone19.radio.finished", 0));
        } else if (s == null || !ZoneManager.isInZone(p)) {
            Net.toPlayer(p, StoryEventPacket.dialogue(Chapters.LIN, "dlg.scpzone19.radio.static", 0));
        } else {
            Net.toPlayer(p, StoryEventPacket.dialogue(Chapters.LIN, s.objective(), 0));
        }
    }

    @Nullable
    public static BlockPos currentWaypoint(MinecraftServer server) {
        Step s = currentStep(StoryData.get(server));
        return s == null ? null : s.waypoint();
    }

    // ------------------------------------------------------------------ admin
    public static void reset(MinecraftServer server) {
        StoryData d = StoryData.get(server);
        ServerLevel zone = ZoneManager.zone(server);
        if (zone != null) {
            removeAll(zone, ModEntities.SCP173.get());
            removeAll(zone, ModEntities.SCP096.get());
            removeAll(zone, ModEntities.SCP106.get());
            removeAll(zone, ModEntities.SCP049_2.get());
            FacilityBuilder.build(zone);
            d.built = true;
        }
        d.chapter = 0;
        d.step = 0;
        d.progress = 0;
        d.finished = false;
        d.epoch++;
        d.setDirty();
        pendingDelay = 0;
        for (ServerPlayer p : zonePlayers(server)) {
            BlockPos s = ZoneLayout.SPAWN;
            p.teleportTo(zone, s.getX() + 0.5, s.getY(), s.getZ() + 0.5, -90.0F, 0.0F);
        }
        beginChapter(server, 1);
    }

    public static void jumpTo(MinecraftServer server, int chapter) {
        ServerLevel zone = ZoneManager.zone(server);
        if (zone != null) {
            removeAll(zone, ModEntities.SCP173.get());
            removeAll(zone, ModEntities.SCP096.get());
            removeAll(zone, ModEntities.SCP106.get());
        }
        for (ServerPlayer p : zonePlayers(server)) {
            if (KeycardItem.bestLevel(p) < 2) give(p, new ItemStack(ModItems.KEYCARD_2.get()));
            for (int k = 1; k < chapter; k++) giveRewards(p, k);
        }
        beginChapter(server, chapter);
    }

    public static void skipStep(MinecraftServer server) {
        if (currentStep(StoryData.get(server)) != null) completeStep(server);
    }

    // ------------------------------------------------------------------ chapter specifics
    private static void onChapterStart(MinecraftServer server, int chapter) {
        ServerLevel zone = ZoneManager.zone(server);
        if (zone == null) return;
        switch (chapter) {
            case 2 -> {
                broadcastSound(server, ModSounds.ALARM_LONG.get(), 0.8F);
                broadcastSound(server, ModSounds.ANNOUNCEMENT.get(), 1.0F);
            }
            case 3 -> {
                removeAll(zone, ModEntities.SCP049_2.get());
                for (BlockPos p : ZoneLayout.SCP049_2_SPAWNS) spawn(zone, ModEntities.SCP049_2.get(), p, 90.0F);
            }
            case 4 -> {
                removeAll(zone, ModEntities.SCP173.get());
                spawn(zone, ModEntities.SCP173.get(), ZoneLayout.SCP173_SPAWN, 0.0F);
                broadcastSound(server, ModSounds.ALARM.get(), 0.8F);
            }
            case 5 -> {
                removeAll(zone, ModEntities.SCP106.get());
                spawn(zone, ModEntities.SCP106.get(), ZoneLayout.SCP106_SPAWN, 90.0F);
                broadcastSound(server, ModSounds.SCP106_LAUGH.get(), 1.0F);
            }
            case 6 -> {
                removeAll(zone, ModEntities.SCP096.get());
                Scp096Entity shy = spawn(zone, ModEntities.SCP096.get(), ZoneLayout.SCP096_SPAWN, 0.0F);
                if (shy != null) shy.setYHeadRot(0.0F);
                broadcastSound(server, ModSounds.ANNOUNCEMENT.get(), 1.0F);
            }
            default -> {
            }
        }
    }

    private static void cleanup(MinecraftServer server, int chapter) {
        ServerLevel zone = ZoneManager.zone(server);
        if (zone == null) return;
        switch (chapter) {
            case 4 -> removeAll(zone, ModEntities.SCP173.get());
            case 5 -> removeAll(zone, ModEntities.SCP106.get());
            case 6 -> removeAll(zone, ModEntities.SCP096.get());
            default -> {
            }
        }
    }

    private static void giveRewards(ServerPlayer p, int chapter) {
        switch (chapter) {
            case 2 -> {
                if (KeycardItem.bestLevel(p) < 3) give(p, new ItemStack(ModItems.KEYCARD_3.get()));
                give(p, new ItemStack(ModItems.DOC_049.get()));
            }
            case 3 -> {
                giveIfMissing(p, ModItems.P90.get());
                give(p, new ItemStack(ModItems.AMMO_57.get(), 64));
                give(p, new ItemStack(ModItems.DOC_173.get()));
            }
            case 4 -> {
                if (KeycardItem.bestLevel(p) < 4) give(p, new ItemStack(ModItems.KEYCARD_4.get()));
                give(p, new ItemStack(ModItems.EYEDROPS.get(), 2));
                give(p, new ItemStack(ModItems.DOC_106.get()));
            }
            case 5 -> {
                giveIfMissing(p, ModItems.SPAS12.get());
                give(p, new ItemStack(ModItems.AMMO_12G.get(), 24));
            }
            case 6 -> give(p, new ItemStack(ModItems.KEYCARD_OMNI.get()));
            default -> {
            }
        }
    }

    @Nullable
    private static <T extends Mob> T spawn(ServerLevel level, EntityType<T> type, BlockPos pos, float yaw) {
        T mob = type.create(level);
        if (mob == null) return null;
        mob.moveTo(pos.getX() + 0.5, pos.getY(), pos.getZ() + 0.5, yaw, 0.0F);
        mob.setYBodyRot(yaw);
        mob.setYHeadRot(yaw);
        mob.setPersistenceRequired();
        level.addFreshEntity(mob);
        return mob;
    }

    private static void removeAll(ServerLevel level, EntityType<?> type) {
        for (Entity e : level.getEntities(type, e -> true)) e.discard();
    }

    // ------------------------------------------------------------------ util
    @Nullable
    private static Step currentStep(StoryData d) {
        if (d.chapter <= 0 || d.finished) return null;
        Chapter c = Chapters.get(d.chapter);
        return d.step < c.steps().size() ? c.steps().get(d.step) : null;
    }

    private static List<ServerPlayer> zonePlayers(MinecraftServer server) {
        ServerLevel zone = ZoneManager.zone(server);
        return zone == null ? List.of() : zone.players();
    }

    private static void setCheckpoint(ServerPlayer p, int chapter) {
        p.setRespawnPosition(ZoneManager.ZONE, ZoneLayout.checkpoint(chapter), -90.0F, true, false);
    }

    private static void say(MinecraftServer server, List<Line> lines) {
        for (Line line : lines) Net.toAll(StoryEventPacket.dialogue(line.speaker(), line.key(), 0));
    }

    private static void broadcastSound(MinecraftServer server, SoundEvent sound, float volume) {
        for (ServerPlayer p : zonePlayers(server)) p.playNotifySound(sound, SoundSource.AMBIENT, volume, 1.0F);
    }

    private static boolean give(ServerPlayer p, ItemStack stack) {
        if (!p.getInventory().add(stack)) p.drop(stack, false);
        return true;
    }

    private static boolean giveIfMissing(ServerPlayer p, Item item) {
        for (ItemStack s : p.getInventory().items) {
            if (s.is(item)) return false;
        }
        if (p.getOffhandItem().is(item)) return false;
        return give(p, new ItemStack(item));
    }

    public static void sync(ServerPlayer p) {
        Net.toPlayer(p, buildSync(p.server));
    }

    public static void syncAll(MinecraftServer server) {
        Net.toAll(buildSync(server));
    }

    private static StorySyncPacket buildSync(MinecraftServer server) {
        StoryData d = StoryData.get(server);
        Step s = currentStep(d);
        if (s == null) {
            return new StorySyncPacket(d.chapter, d.step, 0, 0, "", d.finished, null);
        }
        return new StorySyncPacket(d.chapter, d.step, d.progress, s.count(), s.objective(), false, s.waypoint());
    }

    private StoryManager() {
    }
}
