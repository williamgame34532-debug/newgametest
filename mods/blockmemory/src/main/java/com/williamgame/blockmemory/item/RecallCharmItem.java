package com.williamgame.blockmemory.item;

import com.williamgame.blockmemory.MemoryConfig;
import com.williamgame.blockmemory.ModRegistry;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.GlobalPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.tags.FluidTags;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.item.UseAnim;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.levelgen.Heightmap;

import java.util.List;
import java.util.Optional;

/** Chapter I reward: remembers where you last died and carries you back there. */
public class RecallCharmItem extends Item {
    private static final int CHARGE = 40;

    public RecallCharmItem(Properties props) {
        super(props);
    }

    @Override
    public int getUseDuration(ItemStack stack, LivingEntity entity) {
        return CHARGE;
    }

    @Override
    public UseAnim getUseAnimation(ItemStack stack) {
        return UseAnim.BOW;
    }

    @Override
    public boolean isFoil(ItemStack stack) {
        return true;
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (player.getLastDeathLocation().isEmpty()) {
            if (!level.isClientSide) {
                player.displayClientMessage(Component.translatable("blockmemory.recall.no_death").withStyle(ChatFormatting.GRAY), true);
            }
            return InteractionResultHolder.fail(stack);
        }
        player.startUsingItem(hand);
        return InteractionResultHolder.consume(stack);
    }

    @Override
    public void onUseTick(Level level, LivingEntity entity, ItemStack stack, int remaining) {
        if (level.isClientSide) {
            for (int i = 0; i < 3; i++) {
                double a = level.random.nextDouble() * Math.PI * 2;
                level.addParticle(ParticleTypes.REVERSE_PORTAL, entity.getX() + Math.cos(a) * 0.8, entity.getY() + level.random.nextDouble() * 2,
                        entity.getZ() + Math.sin(a) * 0.8, 0, 0.05, 0);
            }
        }
    }

    @Override
    public ItemStack finishUsingItem(ItemStack stack, Level level, LivingEntity entity) {
        if (level.isClientSide || !(entity instanceof ServerPlayer player)) return stack;
        Optional<GlobalPos> death = player.getLastDeathLocation();
        if (death.isEmpty()) return stack;
        ServerLevel target = player.server.getLevel(death.get().dimension());
        if (target == null) {
            player.displayClientMessage(Component.translatable("blockmemory.recall.lost").withStyle(ChatFormatting.RED), true);
            return stack;
        }
        BlockPos safe = findSafe(target, death.get().pos());
        ServerLevel from = player.serverLevel();
        from.sendParticles(ParticleTypes.REVERSE_PORTAL, player.getX(), player.getY() + 1, player.getZ(), 60, 0.4, 0.9, 0.4, 0.1);
        from.playSound(null, player.blockPosition(), ModRegistry.SOUND_RECALL.get(), SoundSource.PLAYERS, 1.0F, 1.0F);
        player.teleportTo(target, safe.getX() + 0.5, safe.getY(), safe.getZ() + 0.5, player.getYRot(), player.getXRot());
        target.playSound(null, safe, ModRegistry.SOUND_RECALL.get(), SoundSource.PLAYERS, 1.0F, 1.3F);
        target.sendParticles(ParticleTypes.SOUL, safe.getX() + 0.5, safe.getY() + 1, safe.getZ() + 0.5, 40, 0.5, 1.0, 0.5, 0.03);
        player.displayClientMessage(Component.translatable("blockmemory.recall.done").withStyle(ChatFormatting.LIGHT_PURPLE), true);
        player.getCooldowns().addCooldown(this, MemoryConfig.RECALL_COOLDOWN.get() * 20);
        return stack;
    }

    private static boolean free(ServerLevel level, BlockPos p) {
        return level.getBlockState(p).getCollisionShape(level, p).isEmpty() && !level.getFluidState(p).is(FluidTags.LAVA);
    }

    private static BlockPos findSafe(ServerLevel level, BlockPos death) {
        int min = level.getMinBuildHeight() + 1;
        int max = level.getMaxBuildHeight() - 2;
        BlockPos start = new BlockPos(death.getX(), Math.max(min, Math.min(max, death.getY())), death.getZ());
        for (int dy = 0; dy < 32 && start.getY() + dy < max; dy++) {
            BlockPos p = start.above(dy);
            if (free(level, p) && free(level, p.above())) return p;
        }
        level.getChunk(death); // make sure the column is loaded for the heightmap
        int top = level.getHeight(Heightmap.Types.MOTION_BLOCKING, death.getX(), death.getZ());
        return new BlockPos(death.getX(), Math.max(min, top), death.getZ());
    }

    @Override
    public void appendHoverText(ItemStack stack, Item.TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.blockmemory.recall_charm.tip").withStyle(ChatFormatting.GRAY));
    }
}
