package com.zone19.scp.entity;

import com.zone19.scp.registry.ModSounds;
import net.minecraft.commands.arguments.EntityAnchorArgument;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

/**
 * SCP-106, "The Old Man". Slow, unkillable, walks through walls and leaves corrosion behind.
 * Enough gunfire makes it sink into the floor for a while before it resurfaces near its prey.
 */
public class Scp106Entity extends Monster {
    private int retreat;
    private int attackCooldown;
    private int voiceCooldown = 100;
    private float soaked;

    public Scp106Entity(EntityType<? extends Monster> type, Level level) {
        super(type, level);
        setPersistenceRequired();
        setNoGravity(true);
        xpReward = 0;
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Monster.createMonsterAttributes()
                .add(Attributes.MAX_HEALTH, 800.0)
                .add(Attributes.MOVEMENT_SPEED, 0.12)
                .add(Attributes.ATTACK_DAMAGE, 7.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 1.0)
                .add(Attributes.FOLLOW_RANGE, 64.0);
    }

    @Override
    protected void registerGoals() {
    }

    @Override
    public void tick() {
        noPhysics = true;
        super.tick();
        noPhysics = false;
        setNoGravity(true);
    }

    @Override
    public void aiStep() {
        super.aiStep();
        if (level().isClientSide && !isInvisible() && random.nextFloat() < 0.6F) {
            level().addParticle(ParticleTypes.SQUID_INK, getRandomX(0.6), getY() + random.nextDouble() * 0.3,
                    getRandomZ(0.6), 0.0, -0.02, 0.0);
        }
    }

    @Override
    protected void customServerAiStep() {
        super.customServerAiStep();
        if (attackCooldown > 0) attackCooldown--;
        if (retreat > 0) {
            setDeltaMovement(Vec3.ZERO);
            if (--retreat == 0) resurface();
            return;
        }
        Player target = ScpUtil.nearestHuntable(this, 64.0);
        if (target == null) {
            setDeltaMovement(getDeltaMovement().scale(0.5));
            return;
        }
        Vec3 to = target.position().add(0, 0.05, 0).subtract(position());
        double dist = to.length();
        if (dist > 1.0E-3) {
            setDeltaMovement(to.scale(0.11 / dist));
        }
        lookAt(EntityAnchorArgument.Anchor.EYES, target.getEyePosition());
        yBodyRot = getYRot();
        yHeadRot = getYRot();
        if (dist < 1.4 && attackCooldown <= 0) {
            target.hurt(damageSources().mobAttack(this), 7.0F);
            target.addEffect(new MobEffectInstance(MobEffects.WITHER, 100, 1));
            target.addEffect(new MobEffectInstance(MobEffects.MOVEMENT_SLOWDOWN, 80, 2));
            playSound(ModSounds.SCP106_DECAY.get(), 1.2F, 1.0F);
            attackCooldown = 30;
        }
        if (--voiceCooldown <= 0) {
            playSound(random.nextBoolean() ? ModSounds.SCP106_LAUGH.get() : ModSounds.SCP106_BREATHING.get(), 1.6F, 1.0F);
            voiceCooldown = 200 + random.nextInt(200);
        }
    }

    private void resurface() {
        setInvisible(false);
        Player target = ScpUtil.nearestHuntable(this, 96.0);
        if (target != null) {
            double a = random.nextDouble() * Math.PI * 2;
            teleportTo(target.getX() + Math.cos(a) * 10, target.getY(), target.getZ() + Math.sin(a) * 10);
        }
        playSound(ModSounds.SCP106_LAUGH.get(), 2.0F, 0.9F);
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        if (source.is(DamageTypeTags.BYPASSES_INVULNERABILITY)) return super.hurt(source, amount);
        if (level().isClientSide || retreat > 0) return false;
        if (source.getEntity() instanceof Player) {
            soaked += amount;
            if (soaked >= 30.0F) {
                soaked = 0;
                retreat = 240;
                setInvisible(true);
                playSound(ModSounds.SCP106_DECAY.get(), 1.5F, 0.6F);
            }
        }
        return false;
    }

    @Override
    public boolean isPushable() {
        return false;
    }

    @Override
    protected void doPush(Entity entity) {
    }

    @Override
    public boolean removeWhenFarAway(double distance) {
        return false;
    }

    @Override
    protected boolean shouldDespawnInPeaceful() {
        return false;
    }
}
