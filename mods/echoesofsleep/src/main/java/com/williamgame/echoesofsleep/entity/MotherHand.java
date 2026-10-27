package com.williamgame.echoesofsleep.entity;

import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.core.particles.BlockParticleOption;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvent;
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
import net.minecraft.world.level.block.state.BlockState;

/**
 * One of the Deep Mother's hands bursting out of the floor. It rises, slams, clutches, and sinks
 * back into the stone. Wounds dealt to it reach the Mother.
 */
public class MotherHand extends NightmareMonster {
    public static final int LIFETIME = 110;
    public static final int EMERGE = 14;
    public static final int SLAM_AT = 26;
    public static final int CLUTCH_AT = 62;
    public static final int SINK_FROM = 92;

    private int ownerId = -1;

    public MotherHand(EntityType<? extends Monster> type, Level level) {
        super(type, level);
        this.xpReward = 0;
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Monster.createMonsterAttributes()
                .add(Attributes.MAX_HEALTH, 40.0)
                .add(Attributes.MOVEMENT_SPEED, 0.0)
                .add(Attributes.ATTACK_DAMAGE, 9.0)
                .add(Attributes.ARMOR, 6.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 1.0);
    }

    public void setOwner(DeepMother mother) {
        this.ownerId = mother.getId();
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
    protected void customServerAiStep() {
        super.customServerAiStep();
        if (!(level() instanceof ServerLevel sl)) return;
        int age = tickCount;
        if (age == 1) {
            playSound(ModSounds.MOTHER_EMERGE.get(), 1.5F, 1.4F + random.nextFloat() * 0.3F);
            BlockState below = sl.getBlockState(blockPosition().below());
            if (!below.isAir()) {
                sl.sendParticles(new BlockParticleOption(ParticleTypes.BLOCK, below), getX(), getY() + 0.1, getZ(), 40, 0.6, 0.1, 0.6, 0.15);
            }
        }
        if (age == SLAM_AT) slam(sl, 1.0F, true);
        if (age == CLUTCH_AT) slam(sl, 0.7F, false);
        if (age >= LIFETIME) discard();
        // the hand never moves sideways
        setDeltaMovement(0, Math.min(0, getDeltaMovement().y), 0);
    }

    private void slam(ServerLevel sl, float mult, boolean knockUp) {
        playSound(ModSounds.STITCHER_HURT.get(), 1.2F, 0.5F);
        BlockState below = sl.getBlockState(blockPosition().below());
        if (!below.isAir()) {
            sl.sendParticles(new BlockParticleOption(ParticleTypes.BLOCK, below), getX(), getY() + 0.1, getZ(), 30, 1.2, 0.1, 1.2, 0.1);
        }
        for (Player p : sl.players()) {
            if (!NightmareUtil.isValidVictim(p)) continue;
            double dx = p.getX() - getX(), dz = p.getZ() - getZ();
            if (dx * dx + dz * dz > 2.6 * 2.6 || Math.abs(p.getY() - getY()) > 3.0) continue;
            p.hurt(damageSources().mobAttack(this), (float) getAttributeValue(Attributes.ATTACK_DAMAGE) * mult);
            if (knockUp) {
                p.setDeltaMovement(p.getDeltaMovement().add(0, 0.7, 0));
                p.hurtMarked = true;
            } else {
                p.addEffect(new MobEffectInstance(MobEffects.MOVEMENT_SLOWDOWN, 50, 3), this);
            }
        }
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        if (tickCount < EMERGE / 2) return false;
        boolean hurt = super.hurt(source, amount);
        if (hurt && !level().isClientSide && ownerId >= 0) {
            Entity owner = level().getEntity(ownerId);
            if (owner instanceof DeepMother mother && mother.isAlive()) {
                mother.hurtThroughHand(source, amount * 0.6F);
            }
        }
        return hurt;
    }

    @Override
    protected void tickDeath() {
        // sink instead of tipping over
        ++deathTime;
        if (deathTime >= 12 && !level().isClientSide()) {
            remove(RemovalReason.KILLED);
        }
    }

    @Override
    protected SoundEvent getAmbientSound() {
        return null;
    }

    @Override
    protected SoundEvent getHurtSound(DamageSource source) {
        return ModSounds.MOTHER_HURT.get();
    }

    @Override
    protected SoundEvent getDeathSound() {
        return ModSounds.STITCHER_DEATH.get();
    }

    @Override
    public boolean removeWhenFarAway(double distance) {
        return true;
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
    }
}
