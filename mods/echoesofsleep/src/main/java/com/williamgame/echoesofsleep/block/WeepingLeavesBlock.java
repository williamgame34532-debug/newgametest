package com.williamgame.echoesofsleep.block;

import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.LeavesBlock;
import net.minecraft.world.level.block.state.BlockState;

/**
 * Weeping Leaves: leaves that cry dark tears. Extends LeavesBlock and copies the leaf distance of the
 * leaves it replaced, so the tree around it never decays while the dream lasts.
 */
public class WeepingLeavesBlock extends LeavesBlock {
    public static final MapCodec<WeepingLeavesBlock> CODEC = simpleCodec(WeepingLeavesBlock::new);

    public WeepingLeavesBlock(Properties props) {
        super(props);
    }

    @Override
    public MapCodec<? extends LeavesBlock> codec() {
        return CODEC;
    }

    @Override
    public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
        if (random.nextInt(6) == 0 && level.getBlockState(pos.below()).isAir()) {
            level.addParticle(ParticleTypes.DRIPPING_OBSIDIAN_TEAR, pos.getX() + random.nextDouble(), pos.getY() - 0.05, pos.getZ() + random.nextDouble(), 0, 0, 0);
        }
    }
}
