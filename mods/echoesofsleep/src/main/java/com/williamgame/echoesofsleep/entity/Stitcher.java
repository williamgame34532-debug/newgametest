package com.williamgame.echoesofsleep.entity;

import com.williamgame.echoesofsleep.entity.ai.NightmareTargetGoal;
import com.williamgame.echoesofsleep.memory.PlayerMemory;
import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;
import net.minecraft.world.DifficultyInstance;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.MobSpawnType;
import net.minecraft.world.entity.SpawnGroupData;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.FloatGoal;
import net.minecraft.world.entity.ai.goal.Goal;
import net.minecraft.world.entity.ai.goal.LookAtPlayerGoal;
import net.minecraft.world.entity.ai.goal.WaterAvoidingRandomStrollGoal;
import net.minecraft.world.entity.ai.goal.target.HurtByTargetGoal;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.ServerLevelAccessor;
import net.minecraft.world.phys.Vec3;

import java.util.EnumSet;

/**
 * Stitcher: a tall thing sewn together from the creatures its source player killed.
 * The more you killed, the bigger and stronger it is. Moves in jerky stop-motion bursts,
 * grabs its victim, holds it up... and throws it.
 */
public class Stitcher extends NightmareMonster {
    private static final EntityDataAccessor<Integer> DATA_KILLS = SynchedEntityData.defineId(Stitcher.class, EntityDataSerializers.INT);
    private static final EntityDataAccessor<Boolean> DATA_MOVING = SynchedEntityData.defineId(Stitcher.class, EntityDataSerializers.BOOLEAN);
    private static final EntityDataAccessor<Boolean> DATA_GRABBING = SynchedEntityData.defineId(Stitcher.class, EntityDataSerializers.BOOLEAN);

    public Stitcher(EntityType<? extends Monster> type, Level level) {
        super(type, level);
        this.xpReward = 15;
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Monster.createMonsterAttributes()
                .add(Attributes.MAX_HEALTH, 45.0)
                .add(Attributes.MOVEMENT_SPEED, 0.27)
                .add(Attributes.ATTACK_DAMAGE, 8.0)
                .add(Attributes.FOLLOW_RANGE, 36.0)
                .add(Attributes.ARMOR, 6.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 0.6)
                .add(Attributes.STEP_HEIGHT, 1.1);
    }

    @Override
    protected void defineSynchedData(SynchedEntityData.Builder builder) {
        super.defineSynchedData(builder);
        builder.define(DATA_KILLS, 0);
        builder.define(DATA_MOVING, false);
        builder.define(DATA_GRABBING, false);
    }

    @Override
    protected void registerGoals() {
        goalSelector.addGoal(0, new FloatGoal(this));
        goalSelector.addGoal(1, new StitcherHuntGoal(this));
        goalSelector.addGoal(5, new WaterAvoidingRandomStrollGoal(this, 0.7));
        goalSelector.addGoal(6, new LookAtPlayerGoal(this, Player.class, 16.0F));
        targetSelector.addGoal(1, new HurtByTargetGoal(this));
        targetSelector.addGoal(2, new NightmareTargetGoal(this, false));
    }

    public int getKills() {
        return entityData.get(DATA_KILLS);
    }

    public boolean isMovingBurst() {
        return entityData.get(DATA_MOVING);
    }

    public boolean isGrabbing() {
        return entityData.get(DATA_GRABBING);
    }

    private void setMovingBurst(boolean moving) {
        entityData.set(DATA_MOVING, moving);
    }

    private void setGrabbing(boolean grabbing) {
        entityData.set(DATA_GRABBING, grabbing);
    }

    /** Size and strength scale with how much the source player has killed. */
    public void applyKillScaling(int kills) {
        entityData.set(DATA_KILLS, kills);
        setAttr(Attributes.SCALE, 1.0 + Math.min(0.55, kills / 300.0));
        setAttr(Attributes.MAX_HEALTH, 45.0 + Math.min(95.0, kills * 0.6));
        setAttr(Attributes.ATTACK_DAMAGE, 8.0 + Math.min(8.0, kills / 30.0));
        setHealth(getMaxHealth());
        refreshDimensions();
    }

    private void setAttr(net.minecraft.core.Holder<net.minecraft.world.entity.ai.attributes.Attribute> attr, double value) {
        AttributeInstance inst = getAttribute(attr);
        if (inst != null) inst.setBaseValue(value);
    }

    @Override
    public SpawnGroupData finalizeSpawn(ServerLevelAccessor level, DifficultyInstance difficulty, MobSpawnType spawnType, SpawnGroupData data) {
        SpawnGroupData result = super.finalizeSpawn(level, difficulty, spawnType, data);
        if (getSourceId().isEmpty()) {
            Player nearest = level.getNearestPlayer(this, 32.0);
            if (nearest != null) {
                setSource(nearest);
                applyKillScaling(PlayerMemory.of(nearest).totalKills());
            }
        }
        return result;
    }

    @Override
    protected SoundEvent getAmbientSound() {
        return ModSounds.STITCHER_AMBIENT.get();
    }

    @Override
    protected SoundEvent getHurtSound(DamageSource source) {
        return ModSounds.STITCHER_HURT.get();
    }

    @Override
    protected SoundEvent getDeathSound() {
        return ModSounds.STITCHER_DEATH.get();
    }

    @Override
    public int getAmbientSoundInterval() {
        return 200;
    }

    @Override
    public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        tag.putInt("Kills", getKills());
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        entityData.set(DATA_KILLS, tag.getInt("Kills"));
    }

    /** Stop-motion chase + grab-and-throw. */
    static class StitcherHuntGoal extends Goal {
        private final Stitcher mob;
        private int phaseTicks;
        private boolean moving;
        private int attackCooldown;
        private int grabCooldown = 60;
        private int grabTicks;
        private LivingEntity grabbed;

        StitcherHuntGoal(Stitcher mob) {
            this.mob = mob;
            setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.LOOK));
        }

        @Override
        public boolean canUse() {
            LivingEntity t = mob.getTarget();
            return t != null && t.isAlive() && !mob.isStunned() && !mob.isBlinded();
        }

        @Override
        public boolean canContinueToUse() {
            return (canUse() || grabTicks > 0) && !mob.isStunned();
        }

        @Override
        public boolean requiresUpdateEveryTick() {
            return true;
        }

        @Override
        public void stop() {
            release(false);
            mob.setMovingBurst(false);
            mob.getNavigation().stop();
        }

        private void release(boolean doThrow) {
            if (grabbed != null && doThrow && grabbed.isAlive()) {
                Vec3 look = Vec3.directionFromRotation(0, mob.getYRot()).normalize();
                grabbed.setDeltaMovement(look.x * 1.9, 0.75, look.z * 1.9);
                grabbed.hurtMarked = true;
                grabbed.hurt(mob.damageSources().mobAttack(mob), (float) mob.getAttributeValue(Attributes.ATTACK_DAMAGE) * 0.75F);
                mob.level().playSound(null, mob.getX(), mob.getY(), mob.getZ(), SoundEvents.PLAYER_ATTACK_KNOCKBACK, SoundSource.HOSTILE, 1.5F, 0.6F);
            }
            grabbed = null;
            grabTicks = 0;
            mob.setGrabbing(false);
        }

        @Override
        public void tick() {
            if (attackCooldown > 0) attackCooldown--;
            if (grabCooldown > 0) grabCooldown--;
            LivingEntity target = mob.getTarget();

            if (grabTicks > 0) {
                tickGrab();
                return;
            }
            if (target == null) return;
            double dist = mob.distanceToSqr(target);
            float scale = mob.getScale();

            // jerky stop-motion: bursts of movement, then a twitching pause
            if (--phaseTicks <= 0) {
                moving = !moving;
                phaseTicks = moving ? 8 + mob.getRandom().nextInt(8) : 5 + mob.getRandom().nextInt(12);
                mob.setMovingBurst(moving);
                if (!moving) {
                    mob.getNavigation().stop();
                    mob.playSound(SoundEvents.SKELETON_STEP, 0.8F, 0.5F);
                }
            }
            if (moving) {
                mob.getNavigation().moveTo(target, 1.45);
                mob.getLookControl().setLookAt(target, 30.0F, 30.0F);
            } else {
                mob.getLookControl().setLookAt(target.getX() + (mob.getRandom().nextDouble() - 0.5) * 3.0,
                        target.getEyeY() + (mob.getRandom().nextDouble() - 0.5) * 2.0,
                        target.getZ() + (mob.getRandom().nextDouble() - 0.5) * 3.0, 60.0F, 60.0F);
            }

            double reach = Mth.square(1.6 * scale + target.getBbWidth());
            if (dist < reach * 1.4 && grabCooldown <= 0 && mob.hasLineOfSight(target)) {
                grabbed = target;
                grabTicks = 30;
                grabCooldown = 140;
                mob.setGrabbing(true);
                mob.getNavigation().stop();
                mob.playSound(ModSounds.STITCHER_AMBIENT.get(), 1.4F, 0.6F);
                return;
            }
            if (dist < reach && attackCooldown <= 0) {
                attackCooldown = 22;
                mob.swing(InteractionHand.MAIN_HAND);
                mob.doHurtTarget(target);
            }
        }

        private void tickGrab() {
            grabTicks--;
            if (grabbed == null || !grabbed.isAlive() || (grabbed instanceof Player p && !NightmareUtil.isValidVictim(p))) {
                release(false);
                return;
            }
            mob.getNavigation().stop();
            mob.getLookControl().setLookAt(grabbed, 30.0F, 30.0F);
            float scale = mob.getScale();
            Vec3 look = Vec3.directionFromRotation(0, mob.getYRot()).normalize();
            Vec3 hold = mob.position().add(look.scale(1.3 * scale)).add(0, 2.1 * scale, 0);
            Vec3 diff = hold.subtract(grabbed.position());
            grabbed.setDeltaMovement(diff.scale(0.45));
            grabbed.hurtMarked = true;
            grabbed.resetFallDistance();
            if (grabTicks % 10 == 0) {
                grabbed.hurt(mob.damageSources().mobAttack(mob), 2.5F);
                if (mob.level() instanceof ServerLevel sl) {
                    sl.sendParticles(ParticleTypes.DAMAGE_INDICATOR, grabbed.getX(), grabbed.getY() + 1, grabbed.getZ(), 3, 0.2, 0.2, 0.2, 0.1);
                }
            }
            if (grabTicks <= 0) {
                release(true);
            }
        }
    }
}
