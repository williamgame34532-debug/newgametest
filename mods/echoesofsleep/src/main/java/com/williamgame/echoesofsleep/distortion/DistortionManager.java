package com.williamgame.echoesofsleep.distortion;

import com.williamgame.echoesofsleep.Config;
import com.williamgame.echoesofsleep.entity.*;
import com.williamgame.echoesofsleep.memory.PlayerMemory;
import com.williamgame.echoesofsleep.network.DistortionSyncPacket;
import com.williamgame.echoesofsleep.network.FxPacket;
import com.williamgame.echoesofsleep.network.ModNetwork;
import com.williamgame.echoesofsleep.registry.ModBlocks;
import com.williamgame.echoesofsleep.registry.ModEntities;
import com.williamgame.echoesofsleep.registry.ModItems;
import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.SectionPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.tags.BlockTags;
import net.minecraft.util.RandomSource;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobSpawnType;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.DoorBlock;
import net.minecraft.world.level.block.LeavesBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.DoubleBlockHalf;
import net.minecraft.world.level.chunk.ChunkAccess;
import net.minecraft.world.level.chunk.LevelChunk;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.event.entity.player.PlayerEvent;
import net.minecraftforge.event.level.BlockEvent;
import net.minecraftforge.event.level.ChunkEvent;
import net.minecraftforge.event.level.SleepFinishedTimeEvent;
import net.minecraftforge.event.server.ServerStoppingEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Drives the Distortion: starts it when a night is slept through, ticks it, bends the world around
 * every player (always tracked & reverted), spawns nightmares, sends scares, and keeps every client
 * in sync. Registered on the Forge event bus.
 */
public final class DistortionManager {
    private DistortionManager() {
    }

    // =========================================================================================
    // Sleep -> Distortion
    // =========================================================================================

    @SubscribeEvent
    public static void onSleepFinished(SleepFinishedTimeEvent event) {
        if (!(event.getLevel() instanceof ServerLevel sl)) return;
        List<ServerPlayer> sleepers = new ArrayList<>();
        for (ServerPlayer p : sl.players()) {
            if (p.isSleeping()) sleepers.add(p);
        }
        if (sleepers.isEmpty()) return;

        DistortionData data = DistortionData.get(sl);
        // a previous Distortion that was cleansed (enough Echoes slain) resets the chain of nights
        if (data.cleansing >= 3) data.consecutiveNights = 0;
        data.consecutiveNights++;

        float sum = 0, max = 0;
        for (ServerPlayer p : sleepers) {
            PlayerMemory mem = PlayerMemory.of(p);
            float d = mem.dread();
            sum += d;
            max = Math.max(max, d);
            mem.setNightsWithoutSleep(0);
            mem.setSleptTonight(true);
            mem.archivePathAsDream();
            if (d > 50) mem.addDread(4.0F); // sleeping with high Dread feeds the nightmare
        }
        float avg = sum / sleepers.size();
        float score = avg * 0.6F + max * 0.4F + (sleepers.size() - 1) * 6.0F + (data.consecutiveNights - 1) * 14.0F;
        int level = score >= 55 ? 3 : score >= 25 ? 2 : 1;
        // the deterministic road to the final boss: fall asleep holding a Dream Totem and the dream goes all the way down
        for (ServerPlayer p : sleepers) {
            if (p.getInventory().contains(stack -> stack.is(ModItems.DREAM_TOTEM.get()))) {
                level = 3;
                p.sendSystemMessage(Component.translatable("message.echoesofsleep.totem.dream").withStyle(ChatFormatting.DARK_RED, ChatFormatting.ITALIC));
            }
        }
        start(sl, level, Config.DISTORTION_DURATION.get());

        // the wake-up moment
        for (ServerPlayer p : sl.players()) {
            ModNetwork.sendTo(p, new FxPacket(FxPacket.WAKE_UP, level / 3.0F));
            boolean slept = sleepers.contains(p);
            Component msg = Component.translatable(slept ? "message.echoesofsleep.wake.sleeper" : "message.echoesofsleep.wake.other")
                    .withStyle(ChatFormatting.DARK_PURPLE, ChatFormatting.ITALIC);
            p.sendSystemMessage(msg);
            p.displayClientMessage(Component.translatable("message.echoesofsleep.level." + level).withStyle(levelColor(level)), true);
            if (Config.WHISPER_CHAT.get()) whisperName(p);
        }
    }

    public static ChatFormatting levelColor(int level) {
        return switch (level) {
            case 1 -> ChatFormatting.GRAY;
            case 2 -> ChatFormatting.DARK_PURPLE;
            default -> ChatFormatting.DARK_RED;
        };
    }

    public static void start(ServerLevel sl, int level, int duration) {
        DistortionData data = DistortionData.get(sl);
        data.level = Math.max(0, Math.min(3, level));
        data.ticksLeft = level > 0 ? duration : 0;
        data.totalTicks = level > 0 ? duration : 0;
        data.cleansing = 0;
        data.setDirty();
        sync(sl);
    }

    /** Used by the /echoes distort command. Level 0 ends the Distortion and reverts every block now. */
    public static void setLevel(ServerLevel sl, int level) {
        if (level <= 0) {
            DistortionData data = DistortionData.get(sl);
            data.level = 0;
            data.ticksLeft = 0;
            data.setDirty();
            revertDue(sl, data, Long.MAX_VALUE, true);
            sync(sl);
        } else {
            start(sl, level, Config.DISTORTION_DURATION.get());
        }
    }

    /** The Dreamer keeps the world in the Nightmare while it lives. */
    public static void sustainNightmare(ServerLevel sl) {
        DistortionData data = DistortionData.get(sl);
        if (data.level < 3 || data.ticksLeft < 3000) {
            if (!data.isActive()) {
                start(sl, 3, 3000);
            } else {
                data.level = 3;
                data.ticksLeft = Math.max(data.ticksLeft, 3000);
                data.totalTicks = Math.max(data.totalTicks, data.ticksLeft);
                data.setDirty();
                sync(sl);
            }
        }
    }

    /** The Dreamer died: the world wakes up. */
    public static void wakeUp(ServerLevel sl) {
        DistortionData data = DistortionData.get(sl);
        if (data.isActive()) data.ticksLeft = Math.min(data.ticksLeft, 2400);
        data.consecutiveNights = 0;
        data.cleansing += 10;
        data.setDirty();
        sync(sl);
        for (ServerPlayer p : sl.players()) {
            PlayerMemory.of(p).addDread(-40.0F);
            p.sendSystemMessage(Component.translatable("message.echoesofsleep.dreamer_slain").withStyle(ChatFormatting.GOLD, ChatFormatting.ITALIC));
        }
    }

    // =========================================================================================
    // Sync
    // =========================================================================================

    public static void sync(ServerLevel sl) {
        DistortionData data = DistortionData.get(sl);
        ModNetwork.sendToLevel(sl, new DistortionSyncPacket(data.level, data.ticksLeft, data.totalTicks));
    }

    public static void syncTo(ServerPlayer player) {
        DistortionData data = DistortionData.get(player.serverLevel());
        ModNetwork.sendTo(player, new DistortionSyncPacket(data.level, data.ticksLeft, data.totalTicks));
    }

    @SubscribeEvent
    public static void onLogin(PlayerEvent.PlayerLoggedInEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) syncTo(sp);
    }

    @SubscribeEvent
    public static void onChangeDimension(PlayerEvent.PlayerChangedDimensionEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) syncTo(sp);
    }

    @SubscribeEvent
    public static void onRespawn(PlayerEvent.PlayerRespawnEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) syncTo(sp);
    }

    // =========================================================================================
    // Ticking
    // =========================================================================================

    @SubscribeEvent
    public static void onServerTick(TickEvent.ServerTickEvent.Post event) {
        ServerScheduler.tick(event.getServer());
    }

    @SubscribeEvent
    public static void onLevelTick(TickEvent.LevelTickEvent.Post event) {
        if (event.level.isClientSide || !(event.level instanceof ServerLevel sl)) return;
        DistortionData data = DistortionData.get(sl);
        long time = sl.getGameTime();

        if (data.level > 0) {
            if (data.ticksLeft > 0) data.ticksLeft--;
            if (data.ticksLeft <= 0) {
                data.level = 0;
                data.setDirty();
                sync(sl);
                for (ServerPlayer p : sl.players()) {
                    p.displayClientMessage(Component.translatable("message.echoesofsleep.fade").withStyle(ChatFormatting.GRAY), true);
                }
            } else {
                if (time % 20 == 0) data.setDirty();
                if (time % 200 == 0) sync(sl);
                tickActive(sl, data, time);
            }
        }
        if (time % 10 == 0 && !data.entries.isEmpty()) {
            revertDue(sl, data, time, false);
        }
        if (time % 600 == 300) {
            sleeplessCheck(sl);
        }
        if (sl.dimension() == Level.OVERWORLD && time % 20 == 0) {
            trackNights(sl);
        }
    }

    private static void tickActive(ServerLevel sl, DistortionData data, long time) {
        int lvl = data.level;
        float inten = data.intensity();
        RandomSource r = sl.random;
        for (ServerPlayer p : sl.players()) {
            if (p.isSpectator()) continue;
            if (r.nextInt(lvl >= 3 ? 260 : lvl == 2 ? 450 : 800) == 0) {
                ModNetwork.sendTo(p, new FxPacket(FxPacket.WHISPER_BEHIND, inten));
            }
            if (lvl >= 2 && r.nextInt(700) == 0) {
                ModNetwork.sendTo(p, new FxPacket(FxPacket.FOOTSTEPS, inten));
            }
            if (lvl >= 2 && r.nextInt(lvl >= 3 ? 900 : 1800) == 0) {
                ModNetwork.sendTo(p, new FxPacket(FxPacket.GLITCH, inten));
            }
            if (Config.WHISPER_CHAT.get() && r.nextInt(lvl >= 3 ? 2400 : 4800) == 0) {
                whisperName(p);
            }
            int slot = Math.floorMod(p.getId(), 20);
            if (Config.WORLD_DISTORTION.get() && time % 20 == slot && inten > 0.05F) {
                distortAround(sl, data, p, lvl, inten, time);
            }
            if (time % 100 == Math.floorMod(p.getId(), 100) && !p.isCreative()) {
                trySpawns(sl, data, p, lvl, inten, time);
            }
        }
    }

    // =========================================================================================
    // World distortion
    // =========================================================================================

    private static void distortAround(ServerLevel sl, DistortionData data, ServerPlayer p, int lvl, float inten, long time) {
        RandomSource r = sl.random;
        int attempts = 1 + (int) (lvl * 4 * inten);
        for (int i = 0; i < attempts; i++) {
            BlockPos pos = p.blockPosition().offset(r.nextInt(25) - 12, r.nextInt(9) - 5, r.nextInt(25) - 12);
            if (!sl.isLoaded(pos) || data.isTracked(pos)) continue;
            BlockState st = sl.getBlockState(pos);
            BlockState above = sl.getBlockState(pos.above());
            long revertAt = time + Math.min(Math.max(200, data.ticksLeft - 20), 600 + r.nextInt(2400));

            if (st.is(Blocks.GRASS_BLOCK) && above.isAir()) {
                BlockState repl = (lvl >= 2 && r.nextInt(4) == 0 ? ModBlocks.DREAMROT.get() : ModBlocks.ASHEN_GRASS.get()).defaultBlockState();
                replace(sl, data, pos, st, repl, revertAt);
            } else if (lvl >= 2 && st.getBlock() instanceof LeavesBlock && !st.is(ModBlocks.WEEPING_LEAVES.get())) {
                BlockState repl = ModBlocks.WEEPING_LEAVES.get().defaultBlockState()
                        .setValue(LeavesBlock.PERSISTENT, true)
                        .setValue(LeavesBlock.DISTANCE, st.hasProperty(LeavesBlock.DISTANCE) ? st.getValue(LeavesBlock.DISTANCE) : 1)
                        .setValue(LeavesBlock.WATERLOGGED, st.hasProperty(LeavesBlock.WATERLOGGED) && st.getValue(LeavesBlock.WATERLOGGED));
                replace(sl, data, pos, st, repl, revertAt);
            } else if (lvl >= 2 && above.isAir() && r.nextInt(3) == 0
                    && (st.is(Blocks.STONE) || st.is(Blocks.DEEPSLATE) || st.is(Blocks.DIRT) || st.is(Blocks.COARSE_DIRT))) {
                replace(sl, data, pos, st, ModBlocks.DREAMROT.get().defaultBlockState(), revertAt);
            } else if (lvl >= 2 && (st.is(Blocks.TORCH) || st.is(Blocks.WALL_TORCH) || st.is(Blocks.SOUL_TORCH) || st.is(Blocks.SOUL_WALL_TORCH))) {
                // torches go out... briefly
                replace(sl, data, pos, st, Blocks.AIR.defaultBlockState(), time + 100 + r.nextInt(200));
                sl.playSound(null, pos, SoundEvents.FIRE_EXTINGUISH, SoundSource.BLOCKS, 0.5F, 0.6F);
                sl.sendParticles(ParticleTypes.SMOKE, pos.getX() + 0.5, pos.getY() + 0.7, pos.getZ() + 0.5, 8, 0.05, 0.1, 0.05, 0.01);
            } else if (st.getBlock() instanceof DoorBlock door && DoorBlock.isWoodenDoor(st) && !door.isOpen(st)
                    && st.getValue(BlockStateProperties.DOUBLE_BLOCK_HALF) == DoubleBlockHalf.LOWER && r.nextInt(3) == 0) {
                // doors creak open by themselves, then close again
                door.setOpen(null, sl, st, pos, true);
                sl.playSound(null, pos, ModSounds.CREAK.get(), SoundSource.BLOCKS, 1.0F, 0.7F + r.nextFloat() * 0.2F);
                final BlockPos doorPos = pos.immutable();
                ServerScheduler.schedule(sl, 60 + r.nextInt(80), level -> {
                    BlockState now = level.getBlockState(doorPos);
                    if (now.getBlock() instanceof DoorBlock d && d.isOpen(now)) d.setOpen(null, level, now, doorPos, false);
                });
            } else if (lvl >= 3 && r.nextInt(5) == 0 && isTearable(sl, pos, st)) {
                tear(sl, data, pos, st, time);
            }
        }
    }

    private static void replace(ServerLevel sl, DistortionData data, BlockPos pos, BlockState original, BlockState repl, long revertAt) {
        data.track(pos, original, repl, revertAt);
        sl.setBlock(pos, repl, Block.UPDATE_CLIENTS);
    }

    private static boolean isTearable(ServerLevel sl, BlockPos pos, BlockState st) {
        if (st.isAir() || st.hasBlockEntity() || !st.getFluidState().isEmpty()) return false;
        float hardness = st.getDestroySpeed(sl, pos);
        if (hardness < 0 || hardness > 5.0F) return false;
        if (!st.isCollisionShapeFullBlock(sl, pos)) return false;
        if (!sl.getBlockState(pos.above()).isAir()) return false;
        for (Direction d : Direction.values()) {
            BlockPos n = pos.relative(d);
            BlockState ns = sl.getBlockState(n);
            if (!(ns.isAir() || ns.isCollisionShapeFullBlock(sl, n)) || !ns.getFluidState().isEmpty()) return false;
        }
        for (Player p : sl.players()) {
            double dx = p.getX() - (pos.getX() + 0.5), dz = p.getZ() - (pos.getZ() + 0.5);
            if (dx * dx + dz * dz < 9.0 && Math.abs(p.getY() - pos.getY()) < 3) return false; // never under someone's feet
        }
        return true;
    }

    private static void tear(ServerLevel sl, DistortionData data, BlockPos pos, BlockState st, long time) {
        RealityFragment frag = ModEntities.REALITY_FRAGMENT.get().create(sl);
        if (frag == null) return;
        replace(sl, data, pos, st, Blocks.AIR.defaultBlockState(), time + 400);
        frag.setup(st, pos.immutable(), 2.0F + sl.random.nextFloat() * 2.5F);
        sl.addFreshEntity(frag);
        sl.playSound(null, pos, ModSounds.GLITCH.get(), SoundSource.BLOCKS, 0.8F, 0.6F + sl.random.nextFloat() * 0.4F);
    }

    /** Called by a Reality Fragment that has fallen back into its hole. */
    public static void restoreFragment(ServerLevel sl, BlockPos origin, BlockState state) {
        DistortionData data = DistortionData.get(sl);
        DistortionData.Entry entry = data.entries.remove(origin.asLong());
        data.setDirty();
        if (sl.isLoaded(origin) && sl.getBlockState(origin).isAir()) {
            sl.setBlock(origin, entry != null ? entry.original : state, Block.UPDATE_CLIENTS);
            sl.playSound(null, origin, SoundEvents.STONE_PLACE, SoundSource.BLOCKS, 1.0F, 0.5F);
            sl.sendParticles(ParticleTypes.REVERSE_PORTAL, origin.getX() + 0.5, origin.getY() + 1.0, origin.getZ() + 0.5, 15, 0.4, 0.2, 0.4, 0.05);
        }
    }

    /** Restore every due entry whose chunk is loaded. Entries in unloaded chunks wait for their chunk. */
    static void revertDue(ServerLevel sl, DistortionData data, long time, boolean force) {
        boolean changed = false;
        for (Iterator<Map.Entry<Long, DistortionData.Entry>> it = data.entries.entrySet().iterator(); it.hasNext(); ) {
            Map.Entry<Long, DistortionData.Entry> en = it.next();
            DistortionData.Entry e = en.getValue();
            if (!force && e.revertAt > time) continue;
            BlockPos pos = BlockPos.of(en.getKey());
            if (!sl.isLoaded(pos)) {
                // its chunk was cleaned when it unloaded; don't let entries of never-revisited chunks pile up
                if (!force && time - e.revertAt > 24000L) {
                    it.remove();
                    changed = true;
                }
                continue;
            }
            BlockState cur = sl.getBlockState(pos);
            boolean stillOurs = e.replacement.isAir() ? cur.isAir() : cur.is(e.replacement.getBlock());
            if (stillOurs) {
                sl.setBlock(pos, e.original, e.replacement.isAir() ? Block.UPDATE_CLIENTS : Block.UPDATE_ALL);
            }
            it.remove();
            changed = true;
        }
        if (changed) data.setDirty();
    }

    @SubscribeEvent
    public static void onServerStopping(ServerStoppingEvent event) {
        for (ServerLevel sl : event.getServer().getAllLevels()) {
            DistortionData data = DistortionData.get(sl);
            if (!data.entries.isEmpty()) {
                revertDue(sl, data, Long.MAX_VALUE, true);
            }
        }
        ServerScheduler.clear();
    }

    /**
     * A chunk is unloading: write the original blocks straight into it so the saved chunk is clean.
     * The entries are kept; when the chunk comes back they are simply dropped (block no longer ours).
     * Entries of chunks nobody revisits are pruned by {@link #revertDue} a day after they were due.
     */
    @SubscribeEvent
    public static void onChunkUnload(ChunkEvent.Unload event) {
        if (!(event.getLevel() instanceof ServerLevel sl)) return;
        ChunkAccess chunk = event.getChunk();
        if (!(chunk instanceof LevelChunk)) return;
        DistortionData data = DistortionData.get(sl);
        if (data.entries.isEmpty()) return;
        int cx = chunk.getPos().x, cz = chunk.getPos().z;
        for (Map.Entry<Long, DistortionData.Entry> en : data.entries.entrySet()) {
            long key = en.getKey();
            if (SectionPos.blockToSectionCoord(BlockPos.getX(key)) != cx || SectionPos.blockToSectionCoord(BlockPos.getZ(key)) != cz) continue;
            BlockPos pos = BlockPos.of(key);
            DistortionData.Entry e = en.getValue();
            BlockState cur = chunk.getBlockState(pos);
            boolean stillOurs = e.replacement.isAir() ? cur.isAir() : cur.is(e.replacement.getBlock());
            if (stillOurs) {
                chunk.setBlockState(pos, e.original, false);
                chunk.setUnsaved(true);
            }
        }
    }

    /** Breaking a dream block dissolves it back into what was really there. */
    @SubscribeEvent
    public static void onBreak(BlockEvent.BreakEvent event) {
        if (!(event.getLevel() instanceof ServerLevel sl)) return;
        DistortionData data = DistortionData.get(sl);
        DistortionData.Entry e = data.entries.get(event.getPos().asLong());
        if (e == null || e.replacement.isAir()) return;
        event.setCanceled(true);
        data.entries.remove(event.getPos().asLong());
        data.setDirty();
        sl.setBlock(event.getPos(), e.original, Block.UPDATE_ALL);
        sl.sendParticles(ParticleTypes.ASH, event.getPos().getX() + 0.5, event.getPos().getY() + 1.0, event.getPos().getZ() + 0.5, 20, 0.4, 0.3, 0.4, 0.01);
        sl.playSound(null, event.getPos(), ModSounds.WHISPER.get(), SoundSource.BLOCKS, 0.4F, 1.5F);
    }

    // =========================================================================================
    // Nightmare spawning
    // =========================================================================================

    private static int nightmaresNear(ServerLevel sl, Player p) {
        return sl.getEntitiesOfClass(NightmareMonster.class, new AABB(p.blockPosition()).inflate(64),
                m -> m.isAlive() && !m.isBoss() && !(m instanceof MotherHand) && !(m instanceof Sleepless)).size();
    }

    private static void trySpawns(ServerLevel sl, DistortionData data, ServerPlayer p, int lvl, float inten, long time) {
        double rate = Config.SPAWN_RATE.get();
        if (rate <= 0) return;
        RandomSource r = sl.random;
        PlayerMemory victimMem = PlayerMemory.of(p);

        // The Deep Mother wakes for those who have spent too long in the dark below.
        if (lvl >= 2 && p.getY() < 30 && !sl.canSeeSky(p.blockPosition()) && victimMem.underground() > 1200
                && time - data.lastMotherTime > 24000 && r.nextFloat() < 0.015F * rate * lvl
                && sl.getEntitiesOfClass(DeepMother.class, new AABB(p.blockPosition()).inflate(128)).isEmpty()) {
            DeepMother mother = ModEntities.DEEP_MOTHER.get().create(sl);
            BlockPos spot = mother == null ? null : NightmareUtil.findStandingSpot(sl, mother.getType(), p.position(), 6, 14, 16, r);
            if (spot != null) {
                mother.moveTo(spot.getX() + 0.5, spot.getY(), spot.getZ() + 0.5, r.nextFloat() * 360F, 0);
                mother.finalizeSpawn(sl, sl.getCurrentDifficultyAt(spot), MobSpawnType.EVENT, null);
                sl.addFreshEntity(mother);
                data.lastMotherTime = time;
                data.setDirty();
                for (ServerPlayer near : sl.players()) {
                    if (near.distanceToSqr(p) < 64 * 64) {
                        near.sendSystemMessage(Component.translatable("message.echoesofsleep.mother_wakes").withStyle(ChatFormatting.DARK_RED, ChatFormatting.ITALIC));
                    }
                }
                return;
            }
        }

        if (nightmaresNear(sl, p) >= Config.MAX_NIGHTMARES_PER_PLAYER.get()) return;
        // level 1 is tension only: rare watchers. Real hunts start at level 2.
        float chance = lvl >= 3 ? 0.15F : lvl == 2 ? 0.08F : 0.03F;
        if (r.nextFloat() > chance * inten * rate) return;

        // Echoes made from player A can hunt player B
        List<ServerPlayer> all = sl.players();
        ServerPlayer source = (all.size() > 1 && r.nextBoolean()) ? all.get(r.nextInt(all.size())) : p;
        PlayerMemory mem = PlayerMemory.of(source);
        String dim = sl.dimension().location().toString();

        int wDoppel = 4;
        int wStitch = lvl >= 2 && mem.hostileKills() >= 10 ? 3 : 0;
        int wHollow = lvl >= 2 && mem.villagersHurt() > 0 && (sl.isVillage(p.blockPosition()) || lvl >= 3) ? 3 : 0;
        int roll = r.nextInt(wDoppel + wStitch + wHollow);

        NightmareMonster mob;
        BlockPos spot;
        if (roll < wDoppel) {
            EchoDoppelganger dg = ModEntities.ECHO_DOPPELGANGER.get().create(sl);
            if (dg == null) return;
            List<BlockPos> path = mem.dreamPath(dim);
            spot = null;
            // appear where the source walked yesterday, or where they died
            List<BlockPos> candidates = new ArrayList<>(path);
            candidates.addAll(mem.deathPositions(dim));
            for (int i = 0; i < 8 && !candidates.isEmpty() && spot == null; i++) {
                BlockPos c = candidates.get(r.nextInt(candidates.size()));
                double d2 = c.distSqr(p.blockPosition());
                if (d2 > 14 * 14 && d2 < 56 * 56) spot = NightmareUtil.findGround(sl, dg.getType(), c, 4);
            }
            if (spot == null) spot = hiddenSpot(sl, dg.getType(), p, 18, 34);
            dg.setPath(path);
            dg.setTensionOnly(lvl <= 1);
            mob = dg;
        } else if (roll < wDoppel + wStitch) {
            Stitcher st = ModEntities.STITCHER.get().create(sl);
            if (st == null) return;
            spot = hiddenSpot(sl, st.getType(), p, 18, 32);
            st.applyKillScaling(mem.totalKills());
            mob = st;
        } else {
            HollowVillager hv = ModEntities.HOLLOW_VILLAGER.get().create(sl);
            if (hv == null) return;
            spot = hiddenSpot(sl, hv.getType(), p, 16, 30);
            mob = hv;
        }
        if (spot == null) return;
        mob.moveTo(spot.getX() + 0.5, spot.getY(), spot.getZ() + 0.5, r.nextFloat() * 360F, 0);
        mob.setSource(source);
        mob.setDreamBound(true);
        if (mob instanceof EchoDoppelganger dg) dg.setPath(mem.dreamPath(dim));
        mob.finalizeSpawn(sl, sl.getCurrentDifficultyAt(spot), MobSpawnType.EVENT, null);
        sl.addFreshEntity(mob);
    }

    /** A standing spot that no player can currently see, if possible. */
    private static BlockPos hiddenSpot(ServerLevel sl, EntityType<?> type, Player around, double min, double max) {
        BlockPos fallback = null;
        float h = type.getDimensions().height();
        float w = type.getDimensions().width();
        for (int i = 0; i < 10; i++) {
            BlockPos spot = NightmareUtil.findStandingSpot(sl, type, around.position(), min, max, 1, sl.random);
            if (spot == null) continue;
            Vec3 feet = Vec3.atBottomCenterOf(spot);
            boolean seen = false;
            for (Player p : sl.players()) {
                if (NightmareUtil.couldSee(p, feet, h, w, 96)) {
                    seen = true;
                    break;
                }
            }
            if (!seen) return spot;
            if (fallback == null) fallback = spot;
        }
        return fallback;
    }

    /** The Sleepless comes for those who have not slept for three nights or more. */
    private static void sleeplessCheck(ServerLevel sl) {
        if (!Config.SLEEPLESS_ENABLED.get() || Config.SPAWN_RATE.get() <= 0 || !sl.isNight()) return;
        for (ServerPlayer p : sl.players()) {
            if (!NightmareUtil.isValidVictim(p)) continue;
            int nights = PlayerMemory.of(p).nightsWithoutSleep();
            if (nights < 3) continue;
            if (sl.random.nextFloat() > Math.min(0.8F, 0.2F + 0.1F * (nights - 3)) * Config.SPAWN_RATE.get()) continue;
            boolean exists = !sl.getEntities(ModEntities.SLEEPLESS.get(), s -> p.getUUID().equals(s.getPreyId())).isEmpty();
            if (exists) continue;
            Sleepless s = ModEntities.SLEEPLESS.get().create(sl);
            if (s == null) continue;
            BlockPos spot = hiddenSpot(sl, s.getType(), p, 28, 44);
            if (spot == null) continue;
            s.moveTo(spot.getX() + 0.5, spot.getY(), spot.getZ() + 0.5, 0, 0);
            s.setPrey(p);
            s.finalizeSpawn(sl, sl.getCurrentDifficultyAt(spot), MobSpawnType.EVENT, null);
            sl.addFreshEntity(s);
        }
    }

    // =========================================================================================
    // Nights without sleep (tracked on the overworld clock for every online player)
    // =========================================================================================

    private static void trackNights(ServerLevel overworld) {
        long day = overworld.getDayTime() / 24000L;
        for (ServerPlayer p : overworld.getServer().getPlayerList().getPlayers()) {
            PlayerMemory mem = PlayerMemory.of(p);
            long last = mem.lastDay();
            if (last < 0 || day < last) {
                mem.setLastDay(day);
            } else if (day > last) {
                if (!mem.sleptTonight()) {
                    mem.setNightsWithoutSleep(mem.nightsWithoutSleep() + 1);
                    mem.addDread(4.0F);
                    if (mem.nightsWithoutSleep() >= 3) {
                        p.displayClientMessage(Component.translatable("message.echoesofsleep.insomnia", mem.nightsWithoutSleep())
                                .withStyle(ChatFormatting.DARK_GRAY, ChatFormatting.ITALIC), true);
                    }
                }
                mem.setSleptTonight(false);
                mem.setLastDay(day);
            }
        }
    }

    // =========================================================================================
    // Whispers
    // =========================================================================================

    public static void whisperName(ServerPlayer p) {
        String name = p.getGameProfile().getName();
        MutableComponent noise = Component.literal("~~~~").withStyle(ChatFormatting.OBFUSCATED, ChatFormatting.DARK_GRAY);
        MutableComponent msg = Component.empty()
                .append(noise.copy())
                .append(Component.literal(" " + name.toLowerCase() + "... ").withStyle(ChatFormatting.DARK_GRAY, ChatFormatting.ITALIC))
                .append(Component.translatable("chat.echoesofsleep.whisper." + p.getRandom().nextInt(6)).withStyle(ChatFormatting.DARK_GRAY, ChatFormatting.ITALIC))
                .append(noise.copy());
        p.sendSystemMessage(msg);
        ModNetwork.sendTo(p, new FxPacket(FxPacket.WHISPER_BEHIND, 1.0F));
    }
}
