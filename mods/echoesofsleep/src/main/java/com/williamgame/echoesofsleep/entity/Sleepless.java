package com.williamgame.echoesofsleep.entity;

import com.williamgame.echoesofsleep.network.FxPacket;
import com.williamgame.echoesofsleep.network.ModNetwork;
import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.FloatGoal;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

import java.util.UUID;

/**
 * The Sleepless: four blocks tall and impossibly thin. It cannot move while ANY player looks at it
 * (per-player view cone + ray cast). The moment nobody is looking, it is closer.
 * Comes for players who have not slept for three nights or more. Fears the Insomnia Lantern.
 */
public class Sleepless extends NightmareMonster {
    private static final EntityDataAccessor<Boolean> DATA_WATCHED = SynchedEntityData.defineId(Sleepless.class, EntityDataSerializers.BOOLEAN);
    private static final EntityDataAccessor<Boolean> DATA_REACHING = SynchedEntityData.defineId(Sleepless.class, EntityDataSerializers.BOOLEAN);
    public static final double LANTERN_RADIUS = 14.0;

    private UUID preyId;
    private int teleportCooldown = 60;
    private int attackCooldown;
    private int watchedTicks;
    private int idleTicks;
    private float frozenYRot;
    private boolean frozenInit;
    /** Client-side animation clock: it only runs while nobody is looking. */
    public float clientAnimTicks;

    public Sleepless(EntityType<? extends Monster> type, Level level) {
        super(type, level);
        this.xpReward = 20;
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Monster.createMonsterAttributes()
                .add(Attributes.MAX_HEALTH, 60.0)
                .add(Attributes.MOVEMENT_SPEED, 0.22)
                .add(Attributes.ATTACK_DAMAGE, 11.0)
                .add(Attributes.FOLLOW_RANGE, 96.0)
                .add(Attributes.ARMOR, 4.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 1.0)
                .add(Attributes.STEP_HEIGHT, 1.5);
    }

    @Override
    protected void defineSynchedData(SynchedEntityData.Builder builder) {
        super.defineSynchedData(builder);
        builder.define(DATA_WATCHED, false);
        builder.define(DATA_REACHING, false);
    }

    @Override
    protected void registerGoals() {
        goalSelector.addGoal(0, new FloatGoal(this));
    }

    @Override
    public void tick() {
        super.tick();
        if (level().isClientSide && !isWatched()) {
            clientAnimTicks += 1.0F;
        }
    }

    public boolean isWatched() {
        return entityData.get(DATA_WATCHED);
    }

    public boolean isReaching() {
        return entityData.get(DATA_REACHING);
    }

    public void setPrey(Player player) {
        this.preyId = player.getUUID();
        setSource(player);
    }

    public UUID getPreyId() {
        return preyId;
    }

    @Override
    public boolean isPushable() {
        return !isWatched() && super.isPushable();
    }

    @Override
    public void knockback(double strength, double x, double z) {
        // it does not flinch
    }

    private Player resolvePrey() {
        Player prey = preyId != null ? level().getPlayerByUUID(preyId) : null;
        if (prey == null || !NightmareUtil.isValidVictim(prey) || prey.distanceToSqr(this) > 128 * 128) {
            prey = null;
            double best = 96 * 96;
            for (Player p : level().players()) {
                if (!NightmareUtil.isValidVictim(p)) continue;
                double d = p.distanceToSqr(this);
                if (d < best) {
                    best = d;
                    prey = p;
                }
            }
            if (prey != null) preyId = prey.getUUID();
        }
        return prey;
    }

    @Override
    protected void customServerAiStep() {
        super.customServerAiStep();
        if (!(level() instanceof ServerLevel sl) || isStunned()) return;
        if (attackCooldown > 0) attackCooldown--;
        if (entityData.get(DATA_REACHING) && attackCooldown < 180) entityData.set(DATA_REACHING, false);

        // dawn burns the dream away
        if (sl.isDay() && sl.canSeeSky(blockPosition()) && tickCount % 20 == 0 && !isWatched()) {
            vanish(sl);
            return;
        }

        Player prey = resolvePrey();
        if (prey == null) {
            if (++idleTicks > 600) vanish(sl);
            return;
        }
        idleTicks = 0;
        setTarget(prey);

        boolean watched = NightmareUtil.isWatchedByAnyone(this, 128.0);
        entityData.set(DATA_WATCHED, watched);
        if (!frozenInit) {
            frozenYRot = getYRot();
            frozenInit = true;
        }

        if (watched) {
            // absolutely still: no path, no turning, no drifting
            getNavigation().stop();
            setDeltaMovement(0.0, Math.min(0.0, getDeltaMovement().y), 0.0);
            setYRot(frozenYRot);
            yBodyRot = frozenYRot;
            yHeadRot = frozenYRot;
            setXxa(0.0F);
            setZza(0.0F);
            watchedTicks++;
            if (watchedTicks % 40 == 0 && prey instanceof ServerPlayer sp && distanceTo(prey) < 10.0
                    && NightmareUtil.isLookedAtBy(prey, this, 10.0)) {
                ModNetwork.sendTo(sp, new FxPacket(FxPacket.HEARTBEAT, 1.0F - distanceTo(prey) / 10.0F));
            }
            return;
        }
        watchedTicks = 0;

        // nobody is looking: face the prey (snapping, not turning)
        Vec3 d = prey.position().subtract(position());
        frozenYRot = (float) (Mth.atan2(d.z, d.x) * Mth.RAD_TO_DEG) - 90.0F;
        setYRot(frozenYRot);
        yBodyRot = frozenYRot;
        yHeadRot = frozenYRot;

        // the Insomnia Lantern keeps it away
        Player lanternHolder = null;
        for (Player p : level().players()) {
            if (NightmareUtil.holdsLantern(p) && p.distanceToSqr(this) < LANTERN_RADIUS * LANTERN_RADIUS) {
                lanternHolder = p;
                break;
            }
        }
        if (lanternHolder != null) {
            relocateNear(sl, lanternHolder, LANTERN_RADIUS + 6.0, LANTERN_RADIUS + 14.0);
            teleportCooldown = 60;
            return;
        }

        double dist = distanceTo(prey);
        if (dist < 2.8 && attackCooldown <= 0) {
            strike(sl, prey);
            return;
        }
        if (--teleportCooldown <= 0) {
            double next = Math.max(1.6, dist * 0.55 - 2.0);
            relocateNear(sl, prey, next, next + 1.5);
            teleportCooldown = 25 + random.nextInt(40);
        } else if (dist < 12.0) {
            getNavigation().moveTo(prey, 0.9);
        }
    }

    private void strike(ServerLevel sl, Player prey) {
        attackCooldown = 200;
        entityData.set(DATA_REACHING, true);
        prey.hurt(damageSources().mobAttack(this), (float) getAttributeValue(Attributes.ATTACK_DAMAGE));
        prey.addEffect(new MobEffectInstance(MobEffects.DARKNESS, 120, 0), this);
        prey.addEffect(new MobEffectInstance(MobEffects.MOVEMENT_SLOWDOWN, 60, 1), this);
        sl.playSound(null, getX(), getY(), getZ(), ModSounds.SLEEPLESS_STING.get(), SoundSource.HOSTILE, 2.0F, 0.7F);
        if (prey instanceof ServerPlayer sp) {
            ModNetwork.sendTo(sp, new FxPacket(FxPacket.GLITCH, 1.0F));
            ModNetwork.sendTo(sp, new FxPacket(FxPacket.HEARTBEAT, 1.0F));
        }
        // then it is gone again... somewhere behind the treeline
        relocateNear(sl, prey, 24.0, 36.0);
        teleportCooldown = 80;
    }

    /** Teleport to a spot near the target, preferring places that no player can currently see. */
    private void relocateNear(ServerLevel sl, Player around, double minDist, double maxDist) {
        BlockPos fallback = null;
        for (int i = 0; i < 16; i++) {
            BlockPos spot = NightmareUtil.findStandingSpot(sl, getType(), around.position(), minDist, maxDist, 1, random);
            if (spot == null) continue;
            Vec3 feet = Vec3.atBottomCenterOf(spot);
            if (lanternBlocks(sl, feet)) continue;
            boolean seen = false;
            for (Player p : sl.players()) {
                if (NightmareUtil.couldSee(p, feet, getBbHeight(), getBbWidth(), 128.0)) {
                    seen = true;
                    break;
                }
            }
            if (!seen) {
                teleportToSpot(sl, feet, around);
                return;
            }
            if (fallback == null) fallback = spot;
        }
        if (fallback != null && random.nextInt(4) == 0) {
            teleportToSpot(sl, Vec3.atBottomCenterOf(fallback), around);
        }
    }

    private boolean lanternBlocks(ServerLevel sl, Vec3 feet) {
        for (Player p : sl.players()) {
            if (NightmareUtil.holdsLantern(p) && p.position().distanceToSqr(feet) < LANTERN_RADIUS * LANTERN_RADIUS) return true;
        }
        return false;
    }

    private void teleportToSpot(ServerLevel sl, Vec3 feet, Player around) {
        sl.sendParticles(ParticleTypes.LARGE_SMOKE, getX(), getY() + 2.0, getZ(), 12, 0.2, 1.2, 0.2, 0.01);
        teleportTo(feet.x, feet.y, feet.z);
        getNavigation().stop();
        Vec3 d = around.position().subtract(feet);
        frozenYRot = (float) (Mth.atan2(d.z, d.x) * Mth.RAD_TO_DEG) - 90.0F;
        setYRot(frozenYRot);
        yBodyRot = frozenYRot;
        yHeadRot = frozenYRot;
        if (around.distanceToSqr(this) < 12 * 12 && random.nextInt(3) == 0) {
            sl.playSound(null, feet.x, feet.y, feet.z, ModSounds.SLEEPLESS_AMBIENT.get(), SoundSource.HOSTILE, 0.6F, 0.6F + random.nextFloat() * 0.2F);
        }
    }

    private void vanish(ServerLevel sl) {
        sl.sendParticles(ParticleTypes.LARGE_SMOKE, getX(), getY() + 2.0, getZ(), 30, 0.2, 1.4, 0.2, 0.02);
        discard();
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        boolean hurt = super.hurt(source, amount);
        if (hurt && !level().isClientSide && isAlive() && level() instanceof ServerLevel sl
                && source.getEntity() instanceof Player p && random.nextInt(3) == 0) {
            relocateNear(sl, p, 10.0, 18.0);
        }
        return hurt;
    }

    @Override
    protected SoundEvent getAmbientSound() {
        return isWatched() ? null : ModSounds.SLEEPLESS_AMBIENT.get();
    }

    @Override
    protected SoundEvent getHurtSound(DamageSource source) {
        return ModSounds.SLEEPLESS_HURT.get();
    }

    @Override
    protected SoundEvent getDeathSound() {
        return ModSounds.SLEEPLESS_DEATH.get();
    }

    @Override
    public int getAmbientSoundInterval() {
        return 400;
    }

    @Override
    public boolean removeWhenFarAway(double distance) {
        return distance > 160 * 160;
    }

    @Override
    public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        if (preyId != null) tag.putUUID("Prey", preyId);
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        if (tag.hasUUID("Prey")) preyId = tag.getUUID("Prey");
    }
}
