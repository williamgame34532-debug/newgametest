package com.williamgame.blockmemory.item;

import com.williamgame.blockmemory.MemoryConfig;
import com.williamgame.blockmemory.ModRegistry;
import com.williamgame.blockmemory.history.MemoryService;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.item.context.UseOnContext;

import java.util.List;

/** Chapter IV reward: un-remembers griefing. Restores blocks other players or explosions removed recently. */
public class RestorationTomeItem extends Item {
    public static final int RADIUS = 6;

    public RestorationTomeItem(Properties props) {
        super(props);
    }

    @Override
    public InteractionResult useOn(UseOnContext ctx) {
        if (ctx.getLevel().isClientSide) return InteractionResult.SUCCESS;
        if (!(ctx.getPlayer() instanceof ServerPlayer player)) return InteractionResult.PASS;
        ItemStack stack = ctx.getItemInHand();
        int budget = Math.max(1, stack.getMaxDamage() - stack.getDamageValue());
        int n = MemoryService.restore(player, ctx.getClickedPos(), RADIUS, budget);
        if (n > 0) {
            stack.hurtAndBreak(n, player, LivingEntity.getSlotForHand(ctx.getHand()));
            player.serverLevel().playSound(null, ctx.getClickedPos(), ModRegistry.SOUND_GHOST_RISE.get(), SoundSource.PLAYERS, 1.0F, 1.4F);
            player.displayClientMessage(Component.translatable("blockmemory.tome.restored", n).withStyle(ChatFormatting.AQUA), true);
            player.getCooldowns().addCooldown(this, 60);
        } else {
            player.displayClientMessage(Component.translatable("blockmemory.tome.nothing", MemoryConfig.RESTORE_MINUTES.get())
                    .withStyle(ChatFormatting.GRAY), true);
        }
        return InteractionResult.CONSUME;
    }

    @Override
    public void appendHoverText(ItemStack stack, Item.TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.blockmemory.restoration_tome.tip1").withStyle(ChatFormatting.GRAY));
        tooltip.add(Component.translatable("item.blockmemory.restoration_tome.tip2").withStyle(ChatFormatting.DARK_GRAY));
    }
}
