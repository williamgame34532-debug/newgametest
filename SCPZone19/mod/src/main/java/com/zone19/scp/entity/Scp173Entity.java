package com.zone19.scp.entity;

import com.zone19.scp.registry.ModSounds;
import com.zone19.scp.world.BlinkManager;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

/**
 * SCP-173, "The Sculpture". Cannot move while anyone has eyes on it; the moment every
 * observer blinks or looks away it closes the distance and snaps a neck.
 */
public class Scp173Entity extends Monster {
    private int dragCooldown;
    private boolean watched;

    public Scp173Entity(EntityType<? extends Monster> type, Level level) {
        super(type, level);
        setPersistenceRequired();
        xpReward = 0;
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Monster.createMonsterAttributes()
                .add(Attributes.MAX_HEALTH, 500.0)
                .add(Attributes.MOVEMENT_SPEED, 0.5)
                .add(Attributes.ATTACK_DAMAGE, 1000.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 1.0)
                .add(Attributes.FOLLOW_RANGE, 64.0);
    }

    @Override
    protected void registerGoals() {
        // no goals: movement is driven entirely by line-of-sight in customServerAiStep
    }

    public boolean isWatched() {
        return watched;
    }

    public boolean isWatchedBy(Player p) {
        if (!p.isAlive() || p.isSpectator() || BlinkManager.isBlinking(p)) return false;
        Vec3 eye = p.getEyePosition();
        Vec3 to = position().add(0, getBbHeight() * 0.6, 0).subtract(eye);
        double dist = to.length();
        if (dist > 48.0) return false;
        if (dist > 1.0E-3 && p.getViewVector(1.0F).dot(to.scale(1.0 / dist)) < 0.55) return false;
        return p.hasLineOfSight(this);
    }

    @Override
    protected void customServerAiStep() {
        super.customServerAiStep();
        watched = false;
        for (Player p : level().getEntitiesOfClass(Player.class, getBoundingBox().inflate(48.0))) {
            if (isWatchedBy(p)) {
                watched = true;
                break;
            }
        }
        if (watched) {
            getNavigation().stop();
            setDeltaMovement(0, getDeltaMovement().y, 0);
            setYRot(yRotO);
            yBodyRot = yBodyRotO;
            yHeadRot = yHeadRotO;
            return;
        }
        Player target = ScpUtil.nearestHuntable(this, 40.0);
        if (target == null) return;
        getNavigation().moveTo(target, 1.8);
        getLookControl().setLookAt(target, 360.0F, 360.0F);
        if (getBoundingBox().inflate(0.45).intersects(target.getBoundingBox())) {
            if (target.hurt(damageSources().mobAttack(this), 1000.0F)) {
                playSound(ModSounds.SCP173_SNAP.get(), 1.5F, 1.0F);
            }
        }
        if (getDeltaMovement().horizontalDistanceSqr() > 1.0E-3 && --dragCooldown <= 0) {
            playSound(ModSounds.SCP173_DRAG.get(), 1.0F, 0.9F + random.nextFloat() * 0.2F);
            dragCooldown = 14;
        }
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        if (source.is(DamageTypeTags.BYPASSES_INVULNERABILITY)) return super.hurt(source, amount);
        if (!level().isClientSide && tickCount % 8 == 0) {
            playSound(ModSounds.SCP173_RATTLE.get(), 0.8F, 1.0F);
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
