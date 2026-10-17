package com.zone19.scp.entity;

import com.zone19.scp.block.KeycardDoorBlock;
import com.zone19.scp.network.Net;
import com.zone19.scp.network.StoryEventPacket;
import com.zone19.scp.registry.ModSounds;
import com.zone19.scp.world.BlinkManager;
import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.WaterAvoidingRandomStrollGoal;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;
import org.jetbrains.annotations.Nullable;

import java.util.UUID;

/**
 * SCP-096, "The Shy Guy". Harmless until someone sees its face; then it screams, winds up
 * and runs that person down through anything in the way.
 */
public class Scp096Entity extends Monster {
    public static final int CALM = 0, TRIGGERED = 1, RAGE = 2;
    private static final EntityDataAccessor<Integer> STATE = SynchedEntityData.defineId(Scp096Entity.class, EntityDataSerializers.INT);

    @Nullable
    private UUID targetId;
    private int timer;

    public Scp096Entity(EntityType<? extends Monster> type, Level level) {
        super(type, level);
        setPersistenceRequired();
        xpReward = 0;
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Monster.createMonsterAttributes()
                .add(Attributes.MAX_HEALTH, 600.0)
                .add(Attributes.MOVEMENT_SPEED, 0.3)
                .add(Attributes.ATTACK_DAMAGE, 1000.0)
                .add(Attributes.ARMOR, 10.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 1.0)
                .add(Attributes.FOLLOW_RANGE, 128.0);
    }

    @Override
    protected void defineSynchedData() {
        super.defineSynchedData();
        entityData.define(STATE, CALM);
    }

    public int getState() {
        return entityData.get(STATE);
    }

    private void setState(int s) {
        entityData.set(STATE, s);
    }

    @Override
    protected void registerGoals() {
        goalSelector.addGoal(5, new WaterAvoidingRandomStrollGoal(this, 0.4) {
            @Override
            public boolean canUse() {
                return getState() == CALM && super.canUse();
            }
        });
    }

    private boolean seesFace(Player p) {
        if (!ScpUtil.huntable(p) || BlinkManager.isBlinking(p)) return false;
        Vec3 to = getEyePosition().subtract(p.getEyePosition());
        double d = to.length();
        if (d > 40.0 || d < 1.0E-3) return false;
        Vec3 dir = to.scale(1.0 / d);
        if (p.getViewVector(1.0F).dot(dir) < 0.93) return false;
        if (getViewVector(1.0F).dot(dir.scale(-1)) < 0.1) return false;
        return p.hasLineOfSight(this);
    }

    private void trigger(Player p) {
        targetId = p.getUUID();
        timer = 100;
        setState(TRIGGERED);
        getNavigation().stop();
        playSound(ModSounds.SCP096_TRIGGERED.get(), 2.5F, 1.0F);
        if (p instanceof ServerPlayer sp) {
            Net.toPlayer(sp, StoryEventPacket.music("chase096"));
        }
    }

    @Nullable
    private Player target() {
        return targetId == null ? null : level().getPlayerByUUID(targetId);
    }

    private void calmDown() {
        targetId = null;
        setState(CALM);
        getNavigation().stop();
    }

    @Override
    protected void customServerAiStep() {
        super.customServerAiStep();
        switch (getState()) {
            case CALM -> {
                if (tickCount % 4 == 0) {
                    for (Player p : level().getEntitiesOfClass(Player.class, getBoundingBox().inflate(40.0))) {
                        if (seesFace(p)) {
                            trigger(p);
                            break;
                        }
                    }
                }
            }
            case TRIGGERED -> {
                getNavigation().stop();
                Player t = target();
                if (t != null) getLookControl().setLookAt(t, 30.0F, 30.0F);
                if (--timer <= 0) {
                    setState(RAGE);
                    playSound(ModSounds.SCP096_SCREAM.get(), 3.0F, 1.0F);
                }
            }
            case RAGE -> {
                Player t = target();
                if (t == null || !ScpUtil.huntable(t) || t.level() != level() || distanceToSqr(t) > 160 * 160) {
                    calmDown();
                    return;
                }
                getNavigation().moveTo(t, 2.6);
                getLookControl().setLookAt(t, 60.0F, 60.0F);
                if (horizontalCollision) {
                    BlockPos ahead = blockPosition().relative(getDirection());
                    KeycardDoorBlock.forceOpen(level(), ahead);
                    KeycardDoorBlock.forceOpen(level(), ahead.above());
                }
                if (getBoundingBox().inflate(0.6).intersects(t.getBoundingBox())) {
                    t.hurt(damageSources().mobAttack(this), 1000.0F);
                    calmDown();
                }
            }
            default -> calmDown();
        }
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        if (source.is(DamageTypeTags.BYPASSES_INVULNERABILITY)) return super.hurt(source, amount);
        if (!level().isClientSide && getState() == CALM && source.getEntity() instanceof Player p && ScpUtil.huntable(p)) {
            trigger(p);
        }
        return super.hurt(source, amount * 0.2F);
    }

    @Override
    public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        tag.putInt("Rage", getState());
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        setState(CALM);
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
