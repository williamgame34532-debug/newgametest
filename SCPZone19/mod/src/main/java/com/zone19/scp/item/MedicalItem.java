package com.zone19.scp.item;

import com.zone19.scp.registry.ModSounds;
import com.zone19.scp.world.BlinkManager;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;

import java.util.List;

public class MedicalItem extends Item {
    public enum Kind { SCP500, FIRST_AID, EYEDROPS }

    private final Kind kind;

    public MedicalItem(Kind kind, Properties props) {
        super(props);
        this.kind = kind;
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (kind != Kind.EYEDROPS && player.getHealth() >= player.getMaxHealth() && player.getActiveEffects().isEmpty()) {
            return InteractionResultHolder.pass(stack);
        }
        if (!level.isClientSide) {
            switch (kind) {
                case SCP500 -> {
                    player.removeAllEffects();
                    player.setHealth(player.getMaxHealth());
                    player.getFoodData().eat(20, 1.0F);
                    player.displayClientMessage(Component.translatable("message.scpzone19.scp500").withStyle(ChatFormatting.AQUA), true);
                }
                case FIRST_AID -> {
                    player.heal(10.0F);
                    player.addEffect(new MobEffectInstance(MobEffects.REGENERATION, 100, 0));
                }
                case EYEDROPS -> {
                    if (player instanceof ServerPlayer sp) BlinkManager.eyedrops(sp);
                    player.displayClientMessage(Component.translatable("message.scpzone19.eyedrops").withStyle(ChatFormatting.AQUA), true);
                }
            }
            level.playSound(null, player.blockPosition(), ModSounds.PICKUP.get(), SoundSource.PLAYERS, 0.8F, 1.0F);
            if (!player.getAbilities().instabuild) stack.shrink(1);
            player.getCooldowns().addCooldown(this, 20);
        }
        return InteractionResultHolder.sidedSuccess(stack, level.isClientSide);
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level world, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("tooltip.scpzone19." + kind.name().toLowerCase()).withStyle(ChatFormatting.GRAY));
    }
}
