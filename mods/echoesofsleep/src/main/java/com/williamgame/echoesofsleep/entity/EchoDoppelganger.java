package com.williamgame.echoesofsleep.entity;

import com.williamgame.echoesofsleep.memory.PlayerMemory;
import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.DifficultyInstance;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.MobSpawnType;
import net.minecraft.world.entity.SpawnGroupData;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.FloatGoal;
import net.minecraft.world.entity.ai.goal.Goal;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.ServerLevelAccessor;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;

/**
 * Echo Doppelganger: a faceless, stretched copy of a player. It re-walks the path its source player
 * walked yesterday. When someone notices it, it freezes, tilts its head... and then sprints.
 */
public class EchoDoppelganger extends NightmareMonster {
    public static final byte STATE_WANDER = 0;
    public static final byte STATE_STARE = 1;
    public static final byte STATE_HUNT = 2;
    /** Hunt speed multiplier: fast and frightening, but a sprinting player can still get away. */
    public static final double HUNT_SPEED = 1.35;
    private static final EntityDataAccessor<Byte> DATA_STATE = SynchedEntityData.defineId(EchoDoppelganger.class, EntityDataSerializers.BYTE);

    private final List<BlockPos> path = new ArrayList<>();
    private int pathIndex;
    private int pathDirection = 1;
    /** Level-1 echoes only watch: they never hunt, and dissolve when someone comes close. */
    private boolean tensionOnly;

    /** Client-side: tick at which the current state started (for animation). */
    public int clientStateStart;

    public EchoDoppelganger(EntityType<? extends Monster> type, Level level) {
        super(type, level);
        this.xpReward = 12;
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Monster.createMonsterAttributes()
                .add(Attributes.MAX_HEALTH, 34.0)
                .add(Attributes.MOVEMENT_SPEED, 0.31)
                .add(Attributes.ATTACK_DAMAGE, 7.0)
                .add(Attributes.FOLLOW_RANGE, 40.0)
                .add(Attributes.ARMOR, 3.0)
                .add(Attributes.STEP_HEIGHT, 1.0);
    }

    @Override
    protected void defineSynchedData(SynchedEntityData.Builder builder) {
        super.defineSynchedData(builder);
        builder.define(DATA_STATE, STATE_WANDER);
    }

    @Override
    public void onSyncedDataUpdated(EntityDataAccessor<?> key) {
        super.onSyncedDataUpdated(key);
        if (DATA_STATE.equals(key)) {
            clientStateStart = tickCount;
        }
    }

    public void setTensionOnly(boolean tensionOnly) {
        this.tensionOnly = tensionOnly;
    }

    public boolean isTensionOnly() {
        return tensionOnly;
    }

    /** Fades away like a dream you just woke from. */
    void dissolve() {
        if (level() instanceof ServerLevel sl) {
            sl.sendParticles(ParticleTypes.LARGE_SMOKE, getX(), getY() + 1.1, getZ(), 30, 0.25, 0.8, 0.25, 0.02);
            sl.sendParticles(ParticleTypes.ASH, getX(), getY() + 1.1, getZ(), 40, 0.4, 0.9, 0.4, 0.01);
            sl.playSound(null, getX(), getY(), getZ(), ModSounds.WHISPER.get(), SoundSource.HOSTILE, 0.8F, 0.6F);
        }
        discard();
    }

    public byte getState() {
        return entityData.get(DATA_STATE);
    }

    void setState(byte state) {
        entityData.set(DATA_STATE, state);
    }

    @Override
    protected void registerGoals() {
        goalSelector.addGoal(0, new FloatGoal(this));
        goalSelector.addGoal(1, new EchoBehaviourGoal(this));
    }

    /** Give this echo the remembered path of a player. */
    public void setPath(List<BlockPos> points) {
        path.clear();
        path.addAll(points);
        // start at the remembered point nearest to where we appeared
        double best = Double.MAX_VALUE;
        for (int i = 0; i < path.size(); i++) {
            double d = path.get(i).distSqr(blockPosition());
            if (d < best) {
                best = d;
                pathIndex = i;
            }
        }
    }

    @Override
    public SpawnGroupData finalizeSpawn(ServerLevelAccessor level, DifficultyInstance difficulty, MobSpawnType spawnType, SpawnGroupData data) {
        SpawnGroupData result = super.finalizeSpawn(level, difficulty, spawnType, data);
        if (getSourceId().isEmpty()) {
            Player nearest = level.getNearestPlayer(this, 32.0);
            if (nearest != null) {
                setSource(nearest);
                setPath(PlayerMemory.of(nearest).dreamPath(level().dimension().location().toString()));
            }
        }
        return result;
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        boolean hurt = super.hurt(source, amount);
        if (hurt && !level().isClientSide && tensionOnly && isAlive()) {
            dissolve();
            return true;
        }
        if (hurt && !level().isClientSide && source.getEntity() instanceof Player p && NightmareUtil.isValidVictim(p)
                && getState() == STATE_WANDER) {
            setTarget(p);
            setState(STATE_HUNT);
        }
        return hurt;
    }

    @Override
    public boolean doHurtTarget(Entity target) {
        boolean hit = super.doHurtTarget(target);
        if (hit && target instanceof LivingEntity living) {
            living.addEffect(new MobEffectInstance(MobEffects.DARKNESS, 60, 0), this);
        }
        return hit;
    }

    @Override
    protected SoundEvent getAmbientSound() {
        return getState() == STATE_HUNT ? null : ModSounds.DOPPEL_AMBIENT.get();
    }

    @Override
    protected SoundEvent getHurtSound(DamageSource source) {
        return ModSounds.DOPPEL_HURT.get();
    }

    @Override
    protected SoundEvent getDeathSound() {
        return ModSounds.DOPPEL_DEATH.get();
    }

    @Override
    public int getAmbientSoundInterval() {
        return 240;
    }

    @Override
    public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        long[] arr = new long[path.size()];
        for (int i = 0; i < arr.length; i++) arr[i] = path.get(i).asLong();
        tag.putLongArray("EchoPath", arr);
        tag.putInt("EchoPathIndex", pathIndex);
        tag.putBoolean("TensionOnly", tensionOnly);
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        path.clear();
        for (long l : tag.getLongArray("EchoPath")) path.add(BlockPos.of(l));
        pathIndex = Math.min(tag.getInt("EchoPathIndex"), Math.max(0, path.size() - 1));
        tensionOnly = tag.getBoolean("TensionOnly");
    }

    /** Wander the remembered path -> freeze and stare when noticed -> sprint. */
    static class EchoBehaviourGoal extends Goal {
        private final EchoDoppelganger mob;
        private Player victim;
        private int stareTicks;
        private int lostTicks;
        private int attackCooldown;
        private int stuckTicks;
        private int repathTicks;

        EchoBehaviourGoal(EchoDoppelganger mob) {
            this.mob = mob;
            setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.LOOK));
        }

        @Override
        public boolean canUse() {
            return mob.isAlive() && !mob.isStunned();
        }

        @Override
        public boolean requiresUpdateEveryTick() {
            return true;
        }

        @Override
        public void stop() {
            mob.getNavigation().stop();
        }

        @Override
        public void tick() {
            if (attackCooldown > 0) attackCooldown--;
            byte state = mob.getState();
            if (state == STATE_HUNT && victim == null && mob.getTarget() instanceof Player p) {
                victim = p;
            }
            switch (state) {
                case STATE_STARE -> tickStare();
                case STATE_HUNT -> tickHunt();
                default -> tickWander();
            }
        }

        private Player findWatcher() {
            Player best = null;
            double bestDist = Double.MAX_VALUE;
            for (Player p : mob.level().players()) {
                if (!NightmareUtil.isValidVictim(p)) continue;
                double d = p.distanceToSqr(mob);
                if (d > 32 * 32) continue;
                boolean noticed = NightmareUtil.isLookedAtBy(p, mob, 32.0) || (d < 64 && mob.hasLineOfSight(p));
                if (noticed && d < bestDist && !mob.isBlinded()) {
                    best = p;
                    bestDist = d;
                }
            }
            return best;
        }

        private boolean someoneClose(double radius) {
            for (Player p : mob.level().players()) {
                if (NightmareUtil.isValidVictim(p) && p.distanceToSqr(mob) < radius * radius) return true;
            }
            return false;
        }

        private void tickWander() {
            if (mob.tensionOnly && mob.tickCount % 5 == 0 && someoneClose(6.0)) {
                mob.dissolve();
                return;
            }
            if (mob.tickCount % 5 == 0) {
                Player seen = findWatcher();
                if (seen != null) {
                    victim = seen;
                    stareTicks = 30 + mob.getRandom().nextInt(30);
                    mob.getNavigation().stop();
                    mob.setState(STATE_STARE);
                    return;
                }
            }
            List<BlockPos> path = mob.path;
            if (path.isEmpty()) {
                if (mob.getNavigation().isDone() && mob.getRandom().nextInt(60) == 0 && mob.level() instanceof ServerLevel sl) {
                    BlockPos spot = NightmareUtil.findStandingSpot(sl, mob.getType(), mob.position(), 4, 12, 4, mob.getRandom());
                    if (spot != null) mob.getNavigation().moveTo(spot.getX() + 0.5, spot.getY(), spot.getZ() + 0.5, 0.55);
                }
                return;
            }
            BlockPos target = path.get(Math.max(0, Math.min(mob.pathIndex, path.size() - 1)));
            if (mob.blockPosition().distSqr(target) < 4.0 || ++stuckTicks > 160) {
                stuckTicks = 0;
                mob.pathIndex += mob.pathDirection;
                if (mob.pathIndex >= path.size() || mob.pathIndex < 0) {
                    mob.pathDirection = -mob.pathDirection;
                    mob.pathIndex = Math.max(0, Math.min(path.size() - 1, mob.pathIndex + mob.pathDirection * 2));
                }
                target = path.get(mob.pathIndex);
                mob.getNavigation().moveTo(target.getX() + 0.5, target.getY(), target.getZ() + 0.5, 0.6);
            } else if (mob.getNavigation().isDone() && --repathTicks <= 0) {
                repathTicks = 20;
                mob.getNavigation().moveTo(target.getX() + 0.5, target.getY(), target.getZ() + 0.5, 0.6);
            }
        }

        private void tickStare() {
            mob.getNavigation().stop();
            if (victim == null || !NightmareUtil.isValidVictim(victim)) {
                mob.setState(STATE_WANDER);
                return;
            }
            mob.getLookControl().setLookAt(victim, 6.0F, 6.0F);
            if (mob.tensionOnly) {
                // it only watches. Come closer and it is gone; walk away and it goes back to its path
                if (someoneClose(6.0)) {
                    mob.dissolve();
                } else if (victim.distanceToSqr(mob) > 34 * 34) {
                    mob.setState(STATE_WANDER);
                }
                return;
            }
            if (--stareTicks <= 0) {
                mob.setTarget(victim);
                mob.setState(STATE_HUNT);
                mob.level().playSound(null, mob.getX(), mob.getY(), mob.getZ(), ModSounds.DOPPEL_SCREAM.get(),
                        SoundSource.HOSTILE, 1.6F, 0.8F + mob.getRandom().nextFloat() * 0.3F);
            }
        }

        private void tickHunt() {
            if (victim == null || !NightmareUtil.isValidVictim(victim) || victim.level() != mob.level()) {
                victim = null;
                mob.setTarget(null);
                mob.setState(STATE_WANDER);
                return;
            }
            if (mob.isBlinded()) {
                mob.getNavigation().stop();
                return;
            }
            double d = mob.distanceToSqr(victim);
            if (d > 48 * 48 || !mob.hasLineOfSight(victim)) {
                if (++lostTicks > 120) {
                    victim = null;
                    mob.setTarget(null);
                    mob.setState(STATE_WANDER);
                    lostTicks = 0;
                    return;
                }
            } else {
                lostTicks = 0;
            }
            mob.getLookControl().setLookAt(victim, 30.0F, 30.0F);
            if (mob.tickCount % 4 == 0 || mob.getNavigation().isDone()) {
                mob.getNavigation().moveTo(victim, HUNT_SPEED);
            }
            double reach = mob.getBbWidth() * 2.0F * mob.getBbWidth() * 2.0F + victim.getBbWidth() + 1.2;
            if (d <= reach && attackCooldown <= 0) {
                attackCooldown = 16;
                mob.swing(InteractionHand.MAIN_HAND);
                mob.doHurtTarget(victim);
            }
        }
    }
}
