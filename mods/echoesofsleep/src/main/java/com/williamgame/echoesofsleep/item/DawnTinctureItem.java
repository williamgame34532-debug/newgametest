package com.williamgame.echoesofsleep.item;

import com.williamgame.echoesofsleep.memory.PlayerMemory;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.item.UseAnim;
import net.minecraft.world.level.Level;

import java.util.List;

/** Dawn Tincture: a sip of morning. Lowers Dread and clears darkness from the eyes. */
public class DawnTinctureItem extends Item {
    public DawnTinctureItem(Properties props) {
        super(props);
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        player.startUsingItem(hand);
        return InteractionResultHolder.consume(player.getItemInHand(hand));
    }

    @Override
    public UseAnim getUseAnimation(ItemStack stack) {
        return UseAnim.DRINK;
    }

    @Override
    public int getUseDuration(ItemStack stack, LivingEntity entity) {
        return 32;
    }

    @Override
    public ItemStack finishUsingItem(ItemStack stack, Level level, LivingEntity entity) {
        if (!level.isClientSide && entity instanceof ServerPlayer sp) {
            PlayerMemory mem = PlayerMemory.of(sp);
            mem.addDread(-30.0F);
            sp.removeEffect(MobEffects.DARKNESS);
            sp.removeEffect(MobEffects.BLINDNESS);
            sp.removeEffect(MobEffects.CONFUSION);
            sp.addEffect(new MobEffectInstance(MobEffects.REGENERATION, 100, 0));
            sp.displayClientMessage(Component.translatable("message.echoesofsleep.tincture", (int) mem.dread()).withStyle(ChatFormatting.GOLD), true);
            ((ServerLevel) level).sendParticles(ParticleTypes.END_ROD, sp.getX(), sp.getY() + 1.2, sp.getZ(), 20, 0.4, 0.6, 0.4, 0.02);
        }
        if (!(entity instanceof Player p && p.getAbilities().instabuild)) {
            stack.shrink(1);
        }
        return stack;
    }

    @Override
    public void appendHoverText(ItemStack stack, TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.echoesofsleep.dawn_tincture.desc").withStyle(ChatFormatting.GOLD, ChatFormatting.ITALIC));
    }
}
