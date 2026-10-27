package com.williamgame.blockmemory.block;

import com.mojang.serialization.MapCodec;
import com.williamgame.blockmemory.ModRegistry;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.RotatedPillarBlock;
import net.minecraft.world.level.block.state.BlockState;

/** A pillar of the Mnemari. Glyphs drift around it and it whispers to those who stand close. */
public class WhisperingPillarBlock extends RotatedPillarBlock {
    public static final MapCodec<WhisperingPillarBlock> CODEC = simpleCodec(WhisperingPillarBlock::new);

    public WhisperingPillarBlock(Properties props) {
        super(props);
    }

    @Override
    public MapCodec<? extends RotatedPillarBlock> codec() {
        return CODEC;
    }

    @Override
    public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
        double cx = pos.getX() + 0.5, cy = pos.getY() + 0.5, cz = pos.getZ() + 0.5;
        for (int i = 0; i < 2; i++) {
            double a = random.nextDouble() * Math.PI * 2;
            double r = 1.2 + random.nextDouble();
            level.addParticle(ParticleTypes.ENCHANT, cx + Math.cos(a) * r, cy + random.nextDouble() * 1.5 - 0.2, cz + Math.sin(a) * r,
                    -Math.cos(a) * r, -0.3, -Math.sin(a) * r);
        }
        if (random.nextInt(140) == 0) {
            level.playLocalSound(pos, ModRegistry.SOUND_PILLAR_WHISPER.get(), SoundSource.BLOCKS,
                    0.35F + random.nextFloat() * 0.2F, 0.8F + random.nextFloat() * 0.4F, false);
        }
    }
}
