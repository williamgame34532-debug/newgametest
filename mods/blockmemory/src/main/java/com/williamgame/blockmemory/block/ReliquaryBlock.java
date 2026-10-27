package com.williamgame.blockmemory.block;

import com.mojang.serialization.MapCodec;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.util.RandomSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.ItemInteractionResult;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;

/**
 * Holds a buried memory. Brushing it with a Memory Brush yields a Memory Fragment the brushing player
 * does not know yet. Every player can read each reliquary once.
 */
public class ReliquaryBlock extends BaseEntityBlock {
    public static final MapCodec<ReliquaryBlock> CODEC = simpleCodec(ReliquaryBlock::new);

    public ReliquaryBlock(Properties props) {
        super(props);
    }

    @Override
    protected MapCodec<? extends BaseEntityBlock> codec() {
        return CODEC;
    }

    @Override
    public RenderShape getRenderShape(BlockState state) {
        return RenderShape.MODEL;
    }

    @Override
    public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
        return new ReliquaryBlockEntity(pos, state);
    }

    @Override
    protected ItemInteractionResult useItemOn(ItemStack stack, BlockState state, Level level, BlockPos pos, Player player,
                                              InteractionHand hand, BlockHitResult hit) {
        if (stack.getItem() instanceof com.williamgame.blockmemory.item.MemoryBrushItem) {
            // let the brush start brushing instead of the plain interaction
            return ItemInteractionResult.SKIP_DEFAULT_BLOCK_INTERACTION;
        }
        return super.useItemOn(stack, state, level, pos, player, hand, hit);
    }

    @Override
    protected InteractionResult useWithoutItem(BlockState state, Level level, BlockPos pos, Player player, BlockHitResult hit) {
        if (!level.isClientSide) {
            boolean read = level.getBlockEntity(pos) instanceof ReliquaryBlockEntity be && be.hasRead(player.getUUID());
            player.displayClientMessage(Component.translatable(read ? "blockmemory.reliquary.empty" : "blockmemory.reliquary.hint"), true);
        }
        return InteractionResult.sidedSuccess(level.isClientSide);
    }

    @Override
    public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
        if (random.nextInt(3) == 0) {
            level.addParticle(ParticleTypes.END_ROD, pos.getX() + 0.5 + (random.nextDouble() - 0.5) * 0.9, pos.getY() + 0.3 + random.nextDouble() * 0.6,
                    pos.getZ() + 0.5 + (random.nextDouble() - 0.5) * 0.9, 0, 0.01, 0);
        }
    }
}
