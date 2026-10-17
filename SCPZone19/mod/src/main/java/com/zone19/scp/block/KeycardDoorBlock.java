package com.zone19.scp.block;

import com.zone19.scp.item.KeycardItem;
import com.zone19.scp.registry.ModSounds;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.RandomSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.context.BlockPlaceContext;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.HorizontalDirectionalBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.BooleanProperty;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.level.pathfinder.PathComputationType;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Sliding facility door. Each block is one cell of a door leaf; touching cells of the same
 * door type open and close together, so 1x2 office doors and 3x2 blast doors both work.
 * LEVEL is the keycard clearance needed (0 = free access).
 */
public class KeycardDoorBlock extends HorizontalDirectionalBlock {
    public static final BooleanProperty OPEN = BlockStateProperties.OPEN;
    public static final BooleanProperty UPPER = BooleanProperty.create("upper");
    public static final IntegerProperty LEVEL = IntegerProperty.create("level", 0, 5);
    private static final int MAX_GROUP = 16;

    private final boolean heavy;

    public KeycardDoorBlock(Properties props, boolean heavy) {
        super(props);
        this.heavy = heavy;
        registerDefaultState(stateDefinition.any().setValue(FACING, Direction.NORTH)
                .setValue(OPEN, false).setValue(UPPER, false).setValue(LEVEL, 0));
    }

    @Override
    protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
        builder.add(FACING, OPEN, UPPER, LEVEL);
    }

    @Override
    public BlockState getStateForPlacement(BlockPlaceContext ctx) {
        BlockState below = ctx.getLevel().getBlockState(ctx.getClickedPos().below());
        BlockState state = defaultBlockState().setValue(FACING, ctx.getHorizontalDirection().getOpposite());
        if (below.is(this)) {
            state = state.setValue(UPPER, true).setValue(FACING, below.getValue(FACING)).setValue(LEVEL, below.getValue(LEVEL));
        }
        return state;
    }

    @Override
    public VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext ctx) {
        return state.getValue(OPEN) ? Shapes.empty() : Shapes.block();
    }

    @Override
    public boolean isPathfindable(BlockState state, BlockGetter level, BlockPos pos, PathComputationType type) {
        return state.getValue(OPEN);
    }

    @Override
    public InteractionResult use(BlockState state, Level level, BlockPos pos, Player player, InteractionHand hand, BlockHitResult hit) {
        if (hand != InteractionHand.MAIN_HAND) return InteractionResult.PASS;
        if (level.isClientSide) return InteractionResult.SUCCESS;

        if (player.getAbilities().instabuild && player.isShiftKeyDown() && player.getMainHandItem().isEmpty()) {
            int next = (state.getValue(LEVEL) + 1) % 6;
            for (BlockPos p : group(level, pos)) {
                level.setBlock(p, level.getBlockState(p).setValue(LEVEL, next), Block.UPDATE_CLIENTS);
            }
            player.displayClientMessage(Component.translatable("message.scpzone19.door_level", next).withStyle(ChatFormatting.YELLOW), true);
            return InteractionResult.CONSUME;
        }
        if (state.getValue(OPEN)) return InteractionResult.PASS;

        int required = state.getValue(LEVEL);
        if (required == 0 || player.getAbilities().instabuild || KeycardItem.bestLevel(player) >= required) {
            if (required > 0) {
                level.playSound(null, pos, ModSounds.KEYCARD.get(), SoundSource.BLOCKS, 0.8F, 1.0F);
            }
            setOpen(level, pos, true);
        } else {
            level.playSound(null, pos, ModSounds.DOOR_ERROR.get(), SoundSource.BLOCKS, 0.8F, 1.0F);
            player.displayClientMessage(Component.translatable("message.scpzone19.access_denied", required)
                    .withStyle(ChatFormatting.RED), true);
        }
        return InteractionResult.CONSUME;
    }

    /** Used by SCP-096 in a rage: rips the door open regardless of clearance. */
    public static void forceOpen(Level level, BlockPos pos) {
        BlockState state = level.getBlockState(pos);
        if (state.getBlock() instanceof KeycardDoorBlock door && !state.getValue(OPEN)) {
            door.setOpen(level, pos, true);
        }
    }

    private void setOpen(Level level, BlockPos origin, boolean open) {
        List<BlockPos> cells = group(level, origin);
        for (BlockPos p : cells) {
            BlockState s = level.getBlockState(p);
            if (s.is(this)) level.setBlock(p, s.setValue(OPEN, open), Block.UPDATE_ALL);
        }
        if (open) {
            level.playSound(null, origin, heavy ? ModSounds.DOOR_BIG_OPEN.get() : ModSounds.DOOR_OPEN.get(), SoundSource.BLOCKS, 1.0F, 1.0F);
            level.scheduleTick(origin, this, heavy ? 140 : 100);
        } else {
            level.playSound(null, origin, ModSounds.DOOR_CLOSE.get(), SoundSource.BLOCKS, 1.0F, heavy ? 0.8F : 1.0F);
        }
    }

    @Override
    public void tick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random) {
        if (!state.getValue(OPEN)) return;
        List<BlockPos> cells = group(level, pos);
        for (BlockPos p : cells) {
            if (!level.getEntitiesOfClass(LivingEntity.class, new AABB(p)).isEmpty()) {
                level.scheduleTick(pos, this, 20);
                return;
            }
        }
        setOpen(level, pos, false);
    }

    private List<BlockPos> group(Level level, BlockPos origin) {
        List<BlockPos> out = new ArrayList<>();
        Set<BlockPos> seen = new HashSet<>();
        ArrayDeque<BlockPos> queue = new ArrayDeque<>();
        queue.add(origin);
        seen.add(origin);
        while (!queue.isEmpty() && out.size() < MAX_GROUP) {
            BlockPos p = queue.poll();
            out.add(p);
            for (Direction d : Direction.values()) {
                BlockPos n = p.relative(d);
                if (seen.add(n) && level.getBlockState(n).is(this)) queue.add(n);
            }
        }
        return out;
    }
}
