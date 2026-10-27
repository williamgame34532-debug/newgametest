package com.williamgame.echoesofsleep.block;

import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;

/** Ashen Grass: grass the dream burned grey. Ash drifts up from it. */
public class AshenGrassBlock extends Block {
    public static final MapCodec<AshenGrassBlock> CODEC = simpleCodec(AshenGrassBlock::new);

    public AshenGrassBlock(Properties props) {
        super(props);
    }

    @Override
    protected MapCodec<? extends Block> codec() {
        return CODEC;
    }

    @Override
    public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
        if (random.nextInt(4) == 0 && level.getBlockState(pos.above()).isAir()) {
            level.addParticle(random.nextBoolean() ? ParticleTypes.ASH : ParticleTypes.WHITE_ASH,
                    pos.getX() + random.nextDouble(), pos.getY() + 1.05, pos.getZ() + random.nextDouble(), 0.0, 0.02, 0.0);
        }
    }
}
