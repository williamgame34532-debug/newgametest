package com.williamgame.echoesofsleep.entity;

import com.williamgame.echoesofsleep.distortion.DistortionManager;
import com.williamgame.echoesofsleep.memory.PlayerMemory;
import com.williamgame.echoesofsleep.network.FxPacket;
import com.williamgame.echoesofsleep.network.ModNetwork;
import com.williamgame.echoesofsleep.registry.ModEntities;
import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerBossEvent;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.util.Mth;
import net.minecraft.world.BossEvent;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.damagesource.DamageTypes;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobSpawnType;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import java.util.ArrayList;
import java.util.List;

/**
 * The Dreamer (Тот, кто снится) - final boss. Summoned with a Dream Totem when the world is in the
 * Nightmare. Floats, circles its prey, unleashes dream pulses; in phase two it opens its eye,
 * blinks behind you and calls your own Echoes; in phase three it drags everyone towards itself.
 */
public class TheDreamer extends NightmareMonster {
    public static final byte CAST_NONE = 0, CAST_PULSE = 1, CAST_SUMMON = 2, CAST_SWIPE = 3, CAST_PULL = 4;
    private static final EntityDataAccessor<Integer> DATA_PHASE = SynchedEntityData.defineId(TheDreamer.class, EntityDataSerializers.INT);
    private static final EntityDataAccessor<Byte> DATA_CAST = SynchedEntityData.defineId(TheDreamer.class, EntityDataSerializers.BYTE);

    private final ServerBossEvent bossEvent = (ServerBossEvent) new ServerBossEvent(getDisplayName(),
            BossEvent.BossBarColor.PURPLE, BossEvent.BossBarOverlay.NOTCHED_20).setDarkenScreen(true).setCreateWorldFog(true);

    private int pulseCooldown = 80;
    private int swipeCooldown = 60;
    private int summonCooldown = 160;
    private int teleportCooldown = 120;
    private int pullCooldown = 200;
    private int castTicks;
    private int transitionTicks;
    private float orbitAngle;

    public int clientCastStart;
    public int clientPhaseStart;

    public TheDreamer(EntityType<? extends Monster> type, Level level) {
        super(type, level);
        this.xpReward = 300;
        setNoGravity(true);
        setPersistenceRequired();
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Monster.createMonsterAttributes()
                .add(Attributes.MAX_HEALTH, 520.0)
                .add(Attributes.MOVEMENT_SPEED, 0.3)
                .add(Attributes.FLYING_SPEED, 0.6)
                .add(Attributes.ATTACK_DAMAGE, 13.0)
                .add(Attributes.FOLLOW_RANGE, 64.0)
                .add(Attributes.ARMOR, 12.0)
                .add(Attributes.ARMOR_TOUGHNESS, 6.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 1.0);
    }

    @Override
    protected void defineSynchedData(SynchedEntityData.Builder builder) {
        super.defineSynchedData(builder);
        builder.define(DATA_PHASE, 1);
        builder.define(DATA_CAST, CAST_NONE);
    }

    @Override
    public void onSyncedDataUpdated(EntityDataAccessor<?> key) {
        super.onSyncedDataUpdated(key);
        if (DATA_CAST.equals(key)) clientCastStart = tickCount;
        if (DATA_PHASE.equals(key)) clientPhaseStart = tickCount;
    }

    @Override
    public boolean isBoss() {
        return true;
    }

    public int getPhase() {
        return entityData.get(DATA_PHASE);
    }

    public byte getCast() {
        return entityData.get(DATA_CAST);
    }

    private void setCast(byte cast, int ticks) {
        entityData.set(DATA_CAST, cast);
        castTicks = ticks;
    }

    @Override
    protected void registerGoals() {
    }

    @Override
    public boolean isPushable() {
        return false;
    }

    @Override
    public void knockback(double strength, double x, double z) {
    }

    @Override
    public void tick() {
        super.tick();
        setNoGravity(true);
        if (level().isClientSide) {
            for (int i = 0; i < 2; i++) {
                level().addParticle(ParticleTypes.REVERSE_PORTAL, getRandomX(1.2), getY() + random.nextDouble() * 1.2, getRandomZ(1.2), 0, -0.05, 0);
            }
            if (getPhase() >= 3 && random.nextInt(3) == 0) {
                level().addParticle(ParticleTypes.SCULK_SOUL, getRandomX(1.0), getRandomY(), getRandomZ(1.0), 0, 0.05, 0);
            }
        }
    }

    private Player findTarget(ServerLevel sl) {
        Player best = null;
        double bestD = 48 * 48;
        for (Player p : sl.players()) {
            if (!NightmareUtil.isValidVictim(p)) continue;
            double d = p.distanceToSqr(this);
            if (d < bestD) {
                bestD = d;
                best = p;
            }
        }
        return best;
    }

    @Override
    protected void customServerAiStep() {
        super.customServerAiStep();
        bossEvent.setProgress(getHealth() / getMaxHealth());
        if (!(level() instanceof ServerLevel sl)) return;
        if (tickCount % 100 == 0) DistortionManager.sustainNightmare(sl);

        // phase changes
        int phase = getPhase();
        float hp = getHealth() / getMaxHealth();
        int wanted = hp < 0.33F ? 3 : hp < 0.66F ? 2 : 1;
        if (wanted > phase) {
            entityData.set(DATA_PHASE, wanted);
            transitionTicks = 40;
            bossEvent.setColor(wanted == 2 ? BossEvent.BossBarColor.RED : BossEvent.BossBarColor.WHITE);
            playSound(ModSounds.DREAMER_DEATH.get(), 4.0F, 1.5F);
            pulse(sl, 0.6F);
        }
        if (transitionTicks > 0) {
            transitionTicks--;
            setDeltaMovement(getDeltaMovement().scale(0.8));
            return;
        }
        phase = getPhase();

        Player target = findTarget(sl);
        setTarget(target);
        if (target == null) {
            setDeltaMovement(getDeltaMovement().scale(0.9).add(0, Mth.sin(tickCount * 0.05F) * 0.01, 0));
            return;
        }
        getLookControl().setLookAt(target, 30.0F, 30.0F);
        faceTarget(target);

        if (pulseCooldown > 0) pulseCooldown--;
        if (swipeCooldown > 0) swipeCooldown--;
        if (summonCooldown > 0) summonCooldown--;
        if (teleportCooldown > 0) teleportCooldown--;
        if (pullCooldown > 0) pullCooldown--;

        if (castTicks > 0) {
            tickCast(sl, target);
            return;
        }

        hoverAround(target, phase);

        if (phase >= 3 && pullCooldown <= 0) {
            setCast(CAST_PULL, 40);
            pullCooldown = 220;
            playSound(ModSounds.DREAMER_PULSE.get(), 3.0F, 0.5F);
        } else if (phase >= 2 && summonCooldown <= 0) {
            setCast(CAST_SUMMON, 30);
            summonCooldown = phase >= 3 ? 260 : 340;
        } else if (phase >= 2 && teleportCooldown <= 0) {
            blinkBehind(sl, target);
            teleportCooldown = phase >= 3 ? 90 : 140;
            swipeCooldown = 0;
        } else if (pulseCooldown <= 0 && distanceTo(target) < 12) {
            setCast(CAST_PULSE, 24);
            pulseCooldown = phase >= 3 ? 70 : 110;
        } else if (swipeCooldown <= 0) {
            setCast(CAST_SWIPE, 18);
            swipeCooldown = phase >= 2 ? 45 : 70;
        }
    }

    private void faceTarget(Player target) {
        Vec3 d = target.position().subtract(position());
        float yaw = (float) (Mth.atan2(d.z, d.x) * Mth.RAD_TO_DEG) - 90.0F;
        setYRot(yaw);
        yBodyRot = yaw;
    }

    private void hoverAround(Player target, int phase) {
        orbitAngle += phase >= 3 ? 0.045F : 0.025F;
        double radius = phase >= 3 ? 4.5 : 7.0;
        Vec3 want = target.position().add(Math.cos(orbitAngle) * radius, 3.0 + Mth.sin(tickCount * 0.08F) * 0.6, Math.sin(orbitAngle) * radius);
        Vec3 diff = want.subtract(position());
        Vec3 vel = diff.scale(0.06);
        double max = phase >= 3 ? 0.7 : 0.45;
        if (vel.length() > max) vel = vel.normalize().scale(max);
        setDeltaMovement(getDeltaMovement().scale(0.6).add(vel.scale(0.4)));
    }

    private void tickCast(ServerLevel sl, Player target) {
        castTicks--;
        byte cast = getCast();
        switch (cast) {
            case CAST_PULSE -> {
                setDeltaMovement(getDeltaMovement().scale(0.7));
                if (castTicks == 4) pulse(sl, 1.0F);
            }
            case CAST_SWIPE -> {
                Vec3 to = target.getEyePosition().subtract(position().add(0, 2, 0));
                if (castTicks > 10) {
                    setDeltaMovement(getDeltaMovement().scale(0.5));
                } else {
                    setDeltaMovement(to.normalize().scale(0.9));
                    if (distanceTo(target) < 4.2) {
                        target.hurt(damageSources().mobAttack(this), (float) getAttributeValue(Attributes.ATTACK_DAMAGE));
                        target.addEffect(new MobEffectInstance(MobEffects.WITHER, 60, 1), this);
                        castTicks = 0;
                    }
                }
            }
            case CAST_SUMMON -> {
                setDeltaMovement(getDeltaMovement().scale(0.6));
                if (castTicks == 5) summonEchoes(sl);
            }
            case CAST_PULL -> {
                setDeltaMovement(getDeltaMovement().scale(0.5));
                for (Player p : sl.players()) {
                    if (!NightmareUtil.isValidVictim(p) || p.distanceToSqr(this) > 26 * 26) continue;
                    Vec3 pull = position().add(0, 1, 0).subtract(p.position()).normalize().scale(0.12);
                    p.setDeltaMovement(p.getDeltaMovement().add(pull));
                    p.hurtMarked = true;
                }
                if (castTicks % 5 == 0) {
                    sl.sendParticles(ParticleTypes.SQUID_INK, getX(), getY() + 2, getZ(), 20, 3, 2, 3, 0.05);
                }
                if (castTicks == 0) pulse(sl, 1.4F);
            }
            default -> castTicks = 0;
        }
        if (castTicks <= 0) setCast(CAST_NONE, 0);
    }

    /** Dream pulse: a shock wave of nightmare that knocks everyone back and darkens their sight. */
    private void pulse(ServerLevel sl, float strength) {
        playSound(ModSounds.DREAMER_PULSE.get(), 4.0F, 0.8F);
        for (int i = 0; i < 40; i++) {
            double a = i / 40.0 * Math.PI * 2;
            sl.sendParticles(ParticleTypes.SONIC_BOOM, getX() + Math.cos(a) * 3, getY() + 1.5, getZ() + Math.sin(a) * 3, 1, 0, 0, 0, 0);
        }
        for (Player p : sl.players()) {
            if (!NightmareUtil.isValidVictim(p)) continue;
            double d = p.distanceTo(this);
            if (d > 14) continue;
            float dmg = (float) (10.0 * strength * (1.0 - d / 18.0));
            p.hurt(damageSources().indirectMagic(this, this), dmg);
            Vec3 push = p.position().subtract(position()).normalize().scale(1.4 * strength);
            p.setDeltaMovement(push.x, 0.55, push.z);
            p.hurtMarked = true;
            p.addEffect(new MobEffectInstance(MobEffects.DARKNESS, 100, 0), this);
            if (p instanceof ServerPlayer sp) ModNetwork.sendTo(sp, new FxPacket(FxPacket.DREAMER_PULSE, strength));
        }
    }

    private void blinkBehind(ServerLevel sl, Player target) {
        Vec3 back = target.getViewVector(1.0F).multiply(1, 0, 1).normalize().scale(-3.0);
        Vec3 dest = target.position().add(back).add(0, 1.0, 0);
        sl.sendParticles(ParticleTypes.REVERSE_PORTAL, getX(), getY() + 2, getZ(), 60, 0.6, 1.5, 0.6, 0.2);
        teleportTo(dest.x, dest.y, dest.z);
        playSound(ModSounds.SLEEPLESS_STING.get(), 2.0F, 1.2F);
        sl.sendParticles(ParticleTypes.REVERSE_PORTAL, dest.x, dest.y + 2, dest.z, 60, 0.6, 1.5, 0.6, 0.2);
    }

    /** Calls the Echoes of the players fighting it: their own doppelgangers and stitched kills. */
    private void summonEchoes(ServerLevel sl) {
        int existing = sl.getEntitiesOfClass(NightmareMonster.class, new AABB(blockPosition()).inflate(32),
                m -> !m.isBoss() && m.isAlive()).size();
        if (existing >= 6) return;
        List<Player> players = new ArrayList<>();
        for (Player p : sl.players()) {
            if (NightmareUtil.isValidVictim(p) && p.distanceToSqr(this) < 40 * 40) players.add(p);
        }
        if (players.isEmpty()) return;
        playSound(ModSounds.DREAMER_AMBIENT.get(), 3.0F, 0.6F);
        int count = getPhase() >= 3 ? 3 : 2;
        for (int i = 0; i < count; i++) {
            Player source = players.get(random.nextInt(players.size()));
            NightmareMonster echo;
            if (i == 2) {
                Stitcher st = ModEntities.STITCHER.get().create(sl);
                if (st == null) continue;
                st.applyKillScaling(PlayerMemory.of(source).totalKills());
                echo = st;
            } else {
                EchoDoppelganger dg = ModEntities.ECHO_DOPPELGANGER.get().create(sl);
                if (dg == null) continue;
                echo = dg;
            }
            BlockPos spot = NightmareUtil.findStandingSpot(sl, echo.getType(), position(), 2, 6, 10, random);
            if (spot == null) continue;
            echo.moveTo(spot.getX() + 0.5, spot.getY(), spot.getZ() + 0.5, random.nextFloat() * 360F, 0);
            echo.setSource(source);
            echo.setDreamBound(true);
            echo.setTarget(source);
            if (echo instanceof EchoDoppelganger dg) {
                dg.setPath(PlayerMemory.of(source).dreamPath(sl.dimension().location().toString()));
            }
            echo.finalizeSpawn(sl, sl.getCurrentDifficultyAt(spot), MobSpawnType.MOB_SUMMONED, null);
            sl.addFreshEntity(echo);
            sl.sendParticles(ParticleTypes.LARGE_SMOKE, spot.getX() + 0.5, spot.getY() + 1, spot.getZ() + 0.5, 25, 0.3, 0.8, 0.3, 0.02);
        }
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        if (transitionTicks > 0 && !source.is(DamageTypeTags.BYPASSES_INVULNERABILITY)) return false;
        if (source.is(DamageTypeTags.IS_FALL) || source.is(DamageTypeTags.IS_DROWNING) || source.is(DamageTypes.IN_WALL)) return false;
        return super.hurt(source, amount);
    }

    @Override
    public void die(DamageSource source) {
        boolean first = !dead && !isRemoved();
        super.die(source);
        if (first && level() instanceof ServerLevel sl) {
            DistortionManager.wakeUp(sl);
        }
    }

    @Override
    public void startSeenByPlayer(ServerPlayer player) {
        super.startSeenByPlayer(player);
        bossEvent.addPlayer(player);
    }

    @Override
    public void stopSeenByPlayer(ServerPlayer player) {
        super.stopSeenByPlayer(player);
        bossEvent.removePlayer(player);
    }

    @Override
    protected SoundEvent getAmbientSound() {
        return ModSounds.DREAMER_AMBIENT.get();
    }

    @Override
    protected SoundEvent getHurtSound(DamageSource source) {
        return ModSounds.DREAMER_HURT.get();
    }

    @Override
    protected SoundEvent getDeathSound() {
        return ModSounds.DREAMER_DEATH.get();
    }

    @Override
    protected float getSoundVolume() {
        return 3.0F;
    }

    @Override
    public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        tag.putInt("Phase", getPhase());
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        entityData.set(DATA_PHASE, Math.max(1, tag.getInt("Phase")));
        if (hasCustomName()) bossEvent.setName(getDisplayName());
        int phase = getPhase();
        bossEvent.setColor(phase >= 3 ? BossEvent.BossBarColor.WHITE : phase == 2 ? BossEvent.BossBarColor.RED : BossEvent.BossBarColor.PURPLE);
    }
}
