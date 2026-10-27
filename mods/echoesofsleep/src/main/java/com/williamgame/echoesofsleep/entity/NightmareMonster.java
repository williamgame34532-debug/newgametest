package com.williamgame.echoesofsleep.entity;

import com.williamgame.echoesofsleep.distortion.DistortionData;
import com.williamgame.echoesofsleep.memory.PlayerMemory;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;

import java.util.Optional;
import java.util.UUID;

/**
 * Base class for every nightmare: they can be lulled to sleep (Lullaby Staff), blinded (Dawn Blade),
 * they remember which player's memory they were made from, and dream-bound ones dissolve when the
 * Distortion that created them ends.
 */
public abstract class NightmareMonster extends Monster {
    private static final EntityDataAccessor<Boolean> DATA_STUNNED = SynchedEntityData.defineId(NightmareMonster.class, EntityDataSerializers.BOOLEAN);
    protected static final EntityDataAccessor<Optional<UUID>> DATA_SOURCE = SynchedEntityData.defineId(NightmareMonster.class, EntityDataSerializers.OPTIONAL_UUID);
    protected static final EntityDataAccessor<String> DATA_SOURCE_NAME = SynchedEntityData.defineId(NightmareMonster.class, EntityDataSerializers.STRING);

    private int stunTicks;
    /** Spawned by a Distortion: fades away when the world stops dreaming. */
    private boolean dreamBound;
    private int dissolveTicks = -1;

    protected NightmareMonster(EntityType<? extends Monster> type, Level level) {
        super(type, level);
    }

    @Override
    protected void defineSynchedData(SynchedEntityData.Builder builder) {
        super.defineSynchedData(builder);
        builder.define(DATA_STUNNED, false);
        builder.define(DATA_SOURCE, Optional.empty());
        builder.define(DATA_SOURCE_NAME, "");
    }

    // ---- Source player (whose memory this echo was built from) --------------------------------
    public void setSource(Player player) {
        entityData.set(DATA_SOURCE, Optional.of(player.getUUID()));
        entityData.set(DATA_SOURCE_NAME, player.getGameProfile().getName());
    }

    public Optional<UUID> getSourceId() {
        return entityData.get(DATA_SOURCE);
    }

    public String getSourceName() {
        return entityData.get(DATA_SOURCE_NAME);
    }

    public void setDreamBound(boolean dreamBound) {
        this.dreamBound = dreamBound;
    }

    public boolean isDreamBound() {
        return dreamBound;
    }

    public boolean isBoss() {
        return false;
    }

    /** Whether killing this counts as slaying an Echo (cleansing). Body parts such as the Mother's hands do not. */
    public boolean countsAsEcho() {
        return true;
    }

    // ---- Lullaby stun --------------------------------------------------------------------------
    public void lullToSleep(int ticks) {
        if (isBoss()) ticks = ticks / 3;
        stunTicks = Math.max(stunTicks, ticks);
        entityData.set(DATA_STUNNED, true);
        getNavigation().stop();
        setTarget(null);
    }

    public boolean isStunned() {
        return entityData.get(DATA_STUNNED);
    }

    public boolean isBlinded() {
        return hasEffect(MobEffects.BLINDNESS);
    }

    @Override
    protected boolean isImmobile() {
        return super.isImmobile() || isStunned();
    }

    @Override
    public void aiStep() {
        super.aiStep();
        // counted here, not in customServerAiStep: the AI step is skipped entirely while immobile (asleep)
        if (!level().isClientSide && stunTicks > 0) {
            stunTicks--;
            getNavigation().stop();
            if (stunTicks == 0) entityData.set(DATA_STUNNED, false);
        }
        if (level().isClientSide) {
            if (isStunned() && tickCount % 12 == 0) {
                level().addParticle(ParticleTypes.NOTE, getX(), getY() + getBbHeight() + 0.3, getZ(), random.nextDouble(), 0.0, 0.0);
            }
            if (random.nextInt(6) == 0) {
                level().addParticle(ParticleTypes.ASH, getRandomX(0.6), getRandomY(), getRandomZ(0.6), 0.0, 0.0, 0.0);
            }
        }
    }

    @Override
    protected void customServerAiStep() {
        super.customServerAiStep();
        if (isBlinded() && getTarget() != null && random.nextInt(4) == 0) {
            setTarget(null);
        }
        if (dreamBound && tickCount % 100 == 0 && level() instanceof ServerLevel sl && dissolveTicks < 0) {
            if (!DistortionData.get(sl).isActive()) {
                dissolveTicks = 40 + random.nextInt(80);
            }
        }
        if (dissolveTicks > 0 && --dissolveTicks == 0 && level() instanceof ServerLevel sl) {
            sl.sendParticles(ParticleTypes.LARGE_SMOKE, getX(), getY() + getBbHeight() * 0.5, getZ(), 30,
                    getBbWidth() * 0.4, getBbHeight() * 0.4, getBbWidth() * 0.4, 0.02);
            discard();
        }
    }

    @Override
    public void die(DamageSource source) {
        boolean first = !dead && !isRemoved();
        super.die(source);
        if (first && countsAsEcho() && level() instanceof ServerLevel sl) {
            // Cleansing: killing an Echo soothes the killer and the dreaming dimension.
            if (source.getEntity() instanceof ServerPlayer killer) {
                PlayerMemory mem = PlayerMemory.of(killer);
                mem.addEchoSlain();
                mem.addDread(isBoss() ? -40.0F : -3.0F);
            }
            DistortionData data = DistortionData.get(sl);
            if (data.isActive()) {
                data.cleansing += isBoss() ? 10 : 1;
                data.setDirty();
            }
        }
    }

    @Override
    public boolean removeWhenFarAway(double distance) {
        return !isBoss() && dreamBound;
    }

    @Override
    public boolean causeFallDamage(float distance, float multiplier, DamageSource source) {
        return false;
    }

    @Override
    public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        tag.putBoolean("DreamBound", dreamBound);
        tag.putInt("StunTicks", stunTicks);
        getSourceId().ifPresent(id -> tag.putUUID("Source", id));
        tag.putString("SourceName", getSourceName());
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        dreamBound = tag.getBoolean("DreamBound");
        stunTicks = tag.getInt("StunTicks");
        entityData.set(DATA_STUNNED, stunTicks > 0);
        if (tag.hasUUID("Source")) {
            entityData.set(DATA_SOURCE, Optional.of(tag.getUUID("Source")));
        }
        entityData.set(DATA_SOURCE_NAME, tag.getString("SourceName"));
    }
}
