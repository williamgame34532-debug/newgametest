package com.zone19.scp.block;

import com.zone19.scp.registry.ModSounds;
import com.zone19.scp.story.StoryManager;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.context.BlockPlaceContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.HorizontalDirectionalBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BooleanProperty;
import net.minecraft.world.phys.BlockHitResult;

/** One-shot story machine: a terminal, console, generator or the femur breaker. */
public class TerminalBlock extends HorizontalDirectionalBlock {
    public static final String RECONTAIN = "recontain";
    public static final String CONTROL = "control_console";
    public static final String GENERATOR = "generator";
    public static final String FEMUR = "femur_breaker";

    public static final BooleanProperty ACTIVE = BooleanProperty.create("active");
    private final String kind;

    public TerminalBlock(Properties props, String kind) {
        super(props);
        this.kind = kind;
        registerDefaultState(stateDefinition.any().setValue(FACING, Direction.NORTH).setValue(ACTIVE, false));
    }

    @Override
    protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
        builder.add(FACING, ACTIVE);
    }

    @Override
    public BlockState getStateForPlacement(BlockPlaceContext ctx) {
        return defaultBlockState().setValue(FACING, ctx.getHorizontalDirection().getOpposite());
    }

    @Override
    public InteractionResult use(BlockState state, Level level, BlockPos pos, Player player, InteractionHand hand, BlockHitResult hit) {
        if (hand != InteractionHand.MAIN_HAND) return InteractionResult.PASS;
        if (level.isClientSide) return InteractionResult.SUCCESS;
        if (state.getValue(ACTIVE)) {
            player.displayClientMessage(Component.translatable("message.scpzone19.terminal_done").withStyle(ChatFormatting.GREEN), true);
            return InteractionResult.CONSUME;
        }
        if (player instanceof ServerPlayer sp && StoryManager.onInteract(sp, kind)) {
            level.setBlock(pos, state.setValue(ACTIVE, true), Block.UPDATE_ALL);
            level.playSound(null, pos, ModSounds.BUTTON.get(), SoundSource.BLOCKS, 1.0F, 1.0F);
        } else {
            level.playSound(null, pos, ModSounds.DOOR_ERROR.get(), SoundSource.BLOCKS, 0.6F, 1.2F);
            player.displayClientMessage(Component.translatable("message.scpzone19.terminal_locked").withStyle(ChatFormatting.RED), true);
        }
        return InteractionResult.CONSUME;
    }
}
