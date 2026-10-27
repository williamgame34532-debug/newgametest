package com.williamgame.hideandhunt.block;

import com.mojang.serialization.MapCodec;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.DustParticleOptions;
import net.minecraft.network.chat.Component;
import net.minecraft.util.RandomSource;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.VoxelShape;
import org.joml.Vector3f;

import java.util.List;

/**
 * Thin glowing plate. Stepping on it joins a side (Hider / Hunter) or returns to the lobby.
 * Detection is done by the GameManager (it scans player feet positions), so it also works while standing still.
 */
public class TeamPadBlock extends Block {
    public enum PadType { HIDER, HUNTER, LOBBY }

    private static final VoxelShape SHAPE = Block.box(0, 0, 0, 16, 2, 16);

    public final PadType type;
    private final MapCodec<TeamPadBlock> codec;

    public TeamPadBlock(Properties props, PadType type) {
        super(props);
        this.type = type;
        this.codec = simpleCodec(p -> new TeamPadBlock(p, type));
    }

    @Override
    protected MapCodec<? extends Block> codec() {
        return codec;
    }

    @Override
    protected VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext ctx) {
        return SHAPE;
    }

    @Override
    protected VoxelShape getCollisionShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext ctx) {
        return SHAPE;
    }

    @Override
    protected boolean useShapeForLightOcclusion(BlockState state) {
        return true;
    }

    private Vector3f color() {
        return switch (type) {
            case HIDER -> new Vector3f(0.3F, 1.0F, 0.45F);
            case HUNTER -> new Vector3f(1.0F, 0.25F, 0.2F);
            case LOBBY -> new Vector3f(0.75F, 0.4F, 1.0F);
        };
    }

    @Override
    public void animateTick(BlockState state, Level level, BlockPos pos, RandomSource random) {
        if (random.nextInt(3) != 0) return;
        double x = pos.getX() + 0.1 + random.nextDouble() * 0.8;
        double z = pos.getZ() + 0.1 + random.nextDouble() * 0.8;
        level.addParticle(new DustParticleOptions(color(), 0.8F), x, pos.getY() + 0.2, z, 0.0, 0.04, 0.0);
    }

    @Override
    public void appendHoverText(ItemStack stack, Item.TooltipContext ctx, List<Component> lines, TooltipFlag flag) {
        lines.add(Component.translatable("block.hideandhunt." + type.name().toLowerCase(java.util.Locale.ROOT) + "_pad.desc").withStyle(ChatFormatting.GRAY));
    }
}
