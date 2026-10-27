package com.williamgame.blockmemory.block;

import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;

/** Stone that faintly glows and lets slip a glyph now and then. */
public class MemoryStoneBlock extends Block {
    public static final MapCodec<MemoryStoneBlock> CODEC = simpleCodec(MemoryStoneBlock::new);

    public MemoryStoneBlock(Properties props) {
        super(props);
    }

    @Override
    protected MapCodec<? extends Block> codec() {
        return CODEC;
    }

    @Override
    public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
        if (random.nextInt(12) == 0) {
            double x = pos.getX() + random.nextDouble();
            double y = pos.getY() + 1.05;
            double z = pos.getZ() + random.nextDouble();
            level.addParticle(ParticleTypes.ENCHANT, x, y + 0.6, z, (random.nextDouble() - 0.5) * 0.4, -0.6, (random.nextDouble() - 0.5) * 0.4);
        }
    }
}
