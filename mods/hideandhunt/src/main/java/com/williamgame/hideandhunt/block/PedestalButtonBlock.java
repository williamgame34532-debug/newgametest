package com.williamgame.hideandhunt.block;

import com.mojang.serialization.MapCodec;
import com.williamgame.hideandhunt.game.Fx;
import com.williamgame.hideandhunt.game.GameManager;
import com.williamgame.hideandhunt.game.GameSettings;
import com.williamgame.hideandhunt.game.Side;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.RandomSource;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.BooleanProperty;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;

import java.util.List;

/** Arcade-style pedestal with a big button on top: join a side, leave, randomize sides or start the game. */
public class PedestalButtonBlock extends Block {
    public enum ButtonType { HIDER, HUNTER, LEAVE, RANDOMIZER, START }

    public static final BooleanProperty POWERED = BlockStateProperties.POWERED;

    private static final VoxelShape BASE = Shapes.or(Block.box(0, 0, 0, 16, 2, 16), Block.box(1, 2, 1, 15, 11, 15));
    private static final VoxelShape UP = Shapes.or(BASE, Block.box(3, 11, 3, 13, 14, 13));
    private static final VoxelShape DOWN = Shapes.or(BASE, Block.box(3, 11, 3, 13, 12, 13));

    public final ButtonType type;
    private final MapCodec<PedestalButtonBlock> codec;

    public PedestalButtonBlock(Properties props, ButtonType type) {
        super(props);
        this.type = type;
        this.codec = simpleCodec(p -> new PedestalButtonBlock(p, type));
        registerDefaultState(stateDefinition.any().setValue(POWERED, Boolean.FALSE));
    }

    @Override
    protected MapCodec<? extends Block> codec() {
        return codec;
    }

    @Override
    protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder) {
        builder.add(POWERED);
    }

    @Override
    protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext ctx) {
        return state.getValue(POWERED) ? DOWN : UP;
    }

    @Override
    protected InteractionResult useWithoutItem(BlockState state, Level level, BlockPos pos, Player player, BlockHitResult hit) {
        if (state.getValue(POWERED)) return InteractionResult.CONSUME;
        if (level.isClientSide) return InteractionResult.SUCCESS;
        level.setBlock(pos, state.setValue(POWERED, Boolean.TRUE), 3);
        level.scheduleTick(pos, this, type == ButtonType.RANDOMIZER || type == ButtonType.START ? 30 : 12);
        level.playSound(null, pos, SoundEvents.STONE_BUTTON_CLICK_ON, SoundSource.BLOCKS, 0.8F, 1.0F);
        if (player instanceof ServerPlayer sp) press(sp);
        return InteractionResult.CONSUME;
    }

    private void press(ServerPlayer sp) {
        GameManager gm = GameManager.get(sp.server);
        switch (type) {
            case HIDER -> gm.join(sp, Side.HIDER, GameManager.JoinVia.BUTTON, false);
            case HUNTER -> gm.join(sp, Side.HUNTER, GameManager.JoinVia.BUTTON, false);
            case LEAVE -> gm.join(sp, Side.NONE, GameManager.JoinVia.BUTTON, false);
            case RANDOMIZER, START -> {
                if (gm.settings().getBool(GameSettings.BUTTONS_OP_ONLY) && !sp.hasPermissions(2)) {
                    Fx.actionBar(sp, Component.translatable("hideandhunt.msg.no_permission").withStyle(ChatFormatting.RED));
                    return;
                }
                Component err = type == ButtonType.START ? gm.tryStart(sp) : gm.randomize(sp);
                if (err != null) {
                    Fx.actionBar(sp, err.copy().withStyle(ChatFormatting.RED));
                    Fx.sound(sp, SoundEvents.VILLAGER_NO, 0.8F, 1.0F);
                }
            }
        }
    }

    @Override
    protected void tick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random) {
        if (state.getValue(POWERED)) {
            level.setBlock(pos, state.setValue(POWERED, Boolean.FALSE), 3);
            level.playSound(null, pos, SoundEvents.STONE_BUTTON_CLICK_OFF, SoundSource.BLOCKS, 0.6F, 1.1F);
        }
    }

    @Override
    public void appendHoverText(ItemStack stack, Item.TooltipContext ctx, List<Component> lines, TooltipFlag flag) {
        lines.add(Component.translatable("block.hideandhunt." + type.name().toLowerCase(java.util.Locale.ROOT) + "_button.desc").withStyle(ChatFormatting.GRAY));
    }
}
