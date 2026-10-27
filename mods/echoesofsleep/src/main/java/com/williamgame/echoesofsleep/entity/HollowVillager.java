package com.williamgame.echoesofsleep.entity;

import com.williamgame.echoesofsleep.Config;
import com.williamgame.echoesofsleep.entity.ai.NightmareTargetGoal;
import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.*;
import net.minecraft.world.entity.ai.goal.target.HurtByTargetGoal;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;

import java.util.EnumSet;

/**
 * Hollow Villager: an eyeless villager with a mouth that never closes. Appears near villages the
 * player harmed, stands perfectly still while watched, and whispers the names of the living.
 */
public class HollowVillager extends NightmareMonster {
    private static final EntityDataAccessor<Boolean> DATA_STARING = SynchedEntityData.defineId(HollowVillager.class, EntityDataSerializers.BOOLEAN);
    private int whisperCooldown = 100;

    public HollowVillager(EntityType<? extends Monster> type, Level level) {
        super(type, level);
        this.xpReward = 8;
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Monster.createMonsterAttributes()
                .add(Attributes.MAX_HEALTH, 28.0)
                .add(Attributes.MOVEMENT_SPEED, 0.29)
                .add(Attributes.ATTACK_DAMAGE, 6.0)
                .add(Attributes.FOLLOW_RANGE, 32.0)
                .add(Attributes.ARMOR, 2.0);
    }

    @Override
    protected void defineSynchedData(SynchedEntityData.Builder builder) {
        super.defineSynchedData(builder);
        builder.define(DATA_STARING, false);
    }

    public boolean isStaring() {
        return entityData.get(DATA_STARING);
    }

    private void setStaring(boolean staring) {
        entityData.set(DATA_STARING, staring);
    }

    @Override
    protected void registerGoals() {
        goalSelector.addGoal(0, new FloatGoal(this));
        goalSelector.addGoal(1, new StareBackGoal(this));
        goalSelector.addGoal(2, new MeleeAttackGoal(this, 1.15, false));
        goalSelector.addGoal(6, new WaterAvoidingRandomStrollGoal(this, 0.6));
        goalSelector.addGoal(7, new LookAtPlayerGoal(this, Player.class, 24.0F));
        targetSelector.addGoal(1, new HurtByTargetGoal(this));
        targetSelector.addGoal(2, new NightmareTargetGoal(this, false));
    }

    @Override
    protected void customServerAiStep() {
        super.customServerAiStep();
        if (--whisperCooldown <= 0) {
            whisperCooldown = 160 + random.nextInt(200);
            Player near = level().getNearestPlayer(this, 18.0);
            if (near instanceof ServerPlayer sp && NightmareUtil.isValidVictim(sp)) {
                // whisper the name of someone alive... not always the one listening
                Player named = near;
                if (!level().players().isEmpty() && random.nextInt(3) == 0) {
                    named = level().players().get(random.nextInt(level().players().size()));
                }
                level().playSound(null, getX(), getY(), getZ(), ModSounds.WHISPER.get(), SoundSource.HOSTILE, 1.0F, 0.75F);
                if (Config.WHISPER_CHAT.get()) {
                    sp.sendSystemMessage(Component.translatable("chat.echoesofsleep.hollow_whisper",
                            named.getGameProfile().getName()).withStyle(ChatFormatting.DARK_GRAY, ChatFormatting.ITALIC));
                }
            }
        }
    }

    @Override
    protected SoundEvent getAmbientSound() {
        return ModSounds.HOLLOW_AMBIENT.get();
    }

    @Override
    protected SoundEvent getHurtSound(DamageSource source) {
        return ModSounds.HOLLOW_HURT.get();
    }

    @Override
    protected SoundEvent getDeathSound() {
        return ModSounds.HOLLOW_DEATH.get();
    }

    /** While its target watches it from afar, it stops dead and stares back with its empty face. */
    static class StareBackGoal extends Goal {
        private final HollowVillager mob;

        StareBackGoal(HollowVillager mob) {
            this.mob = mob;
            setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.LOOK));
        }

        @Override
        public boolean canUse() {
            LivingEntity t = mob.getTarget();
            return t instanceof Player p && mob.distanceToSqr(p) > 36.0 && NightmareUtil.isLookedAtBy(p, mob, 40.0);
        }

        @Override
        public void start() {
            mob.getNavigation().stop();
            mob.setStaring(true);
        }

        @Override
        public void stop() {
            mob.setStaring(false);
        }

        @Override
        public void tick() {
            LivingEntity t = mob.getTarget();
            if (t != null) mob.getLookControl().setLookAt(t, 90.0F, 90.0F);
        }
    }
}
