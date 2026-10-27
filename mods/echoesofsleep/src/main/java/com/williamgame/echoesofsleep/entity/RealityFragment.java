package com.williamgame.echoesofsleep.entity;

import com.williamgame.echoesofsleep.distortion.DistortionManager;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;

/**
 * A "reality tear": a block torn out of the world that floats up, turns slowly in the air and then
 * falls back into its hole. The hole is tracked by the Distortion data, so even if this entity is
 * lost (chunk unload, crash) the block is restored.
 */
public class RealityFragment extends Entity {
    public static final int RISE = 30, HOVER_END = 130, FALL_END = 160;
    private static final EntityDataAccessor<BlockState> DATA_STATE = SynchedEntityData.defineId(RealityFragment.class, EntityDataSerializers.BLOCK_STATE);
    private static final EntityDataAccessor<BlockPos> DATA_ORIGIN = SynchedEntityData.defineId(RealityFragment.class, EntityDataSerializers.BLOCK_POS);
    private static final EntityDataAccessor<Float> DATA_HEIGHT = SynchedEntityData.defineId(RealityFragment.class, EntityDataSerializers.FLOAT);

    public RealityFragment(EntityType<? extends RealityFragment> type, Level level) {
        super(type, level);
        noPhysics = true;
        setNoGravity(true);
    }

    public void setup(BlockState state, BlockPos origin, float height) {
        entityData.set(DATA_STATE, state);
        entityData.set(DATA_ORIGIN, origin);
        entityData.set(DATA_HEIGHT, height);
        setPos(origin.getX() + 0.5, origin.getY(), origin.getZ() + 0.5);
    }

    public BlockState getBlockState() {
        return entityData.get(DATA_STATE);
    }

    public BlockPos getOrigin() {
        return entityData.get(DATA_ORIGIN);
    }

    @Override
    protected void defineSynchedData(SynchedEntityData.Builder builder) {
        builder.define(DATA_STATE, Blocks.STONE.defaultBlockState());
        builder.define(DATA_ORIGIN, BlockPos.ZERO);
        builder.define(DATA_HEIGHT, 3.0F);
    }

    /** Height above the origin at the given (partial) age. Shared by server movement and client rendering. */
    public float offsetAt(float age) {
        float h = entityData.get(DATA_HEIGHT);
        if (age < RISE) {
            float t = age / RISE;
            return h * (1 - (1 - t) * (1 - t));
        } else if (age < HOVER_END) {
            return h + Mth.sin(age * 0.12F) * 0.25F;
        } else if (age < FALL_END) {
            float t = (age - HOVER_END) / (float) (FALL_END - HOVER_END);
            return (h + Mth.sin(HOVER_END * 0.12F) * 0.25F) * (1 - t * t);
        }
        return 0;
    }

    @Override
    public void tick() {
        super.tick();
        BlockPos origin = getOrigin();
        float y = offsetAt(tickCount);
        setPos(origin.getX() + 0.5, origin.getY() + y, origin.getZ() + 0.5);
        if (level().isClientSide) {
            if (random.nextInt(3) == 0) {
                level().addParticle(ParticleTypes.REVERSE_PORTAL, getRandomX(0.6), getY() + random.nextDouble(), getRandomZ(0.6), 0, 0.02, 0);
            }
            return;
        }
        if (tickCount >= FALL_END) {
            if (level() instanceof ServerLevel sl) {
                DistortionManager.restoreFragment(sl, origin, getBlockState());
            }
            discard();
        }
    }

    @Override
    public boolean isPickable() {
        return false;
    }

    @Override
    public boolean isPushable() {
        return false;
    }

    @Override
    protected void readAdditionalSaveData(CompoundTag tag) {
    }

    @Override
    protected void addAdditionalSaveData(CompoundTag tag) {
    }
}
