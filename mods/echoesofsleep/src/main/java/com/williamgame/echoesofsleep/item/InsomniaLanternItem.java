package com.williamgame.echoesofsleep.item;

import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;

import java.util.List;

/** Insomnia Lantern: held in either hand (best in the offhand), the Sleepless cannot come near. */
public class InsomniaLanternItem extends Item {
    public InsomniaLanternItem(Properties props) {
        super(props);
    }

    @Override
    public void inventoryTick(ItemStack stack, Level level, Entity entity, int slot, boolean selected) {
        if (level.isClientSide && entity instanceof Player p && (selected || p.getOffhandItem() == stack)
                && level.random.nextInt(4) == 0) {
            level.addParticle(ParticleTypes.SOUL_FIRE_FLAME, p.getX() + (level.random.nextDouble() - 0.5) * 0.6,
                    p.getY() + 0.9, p.getZ() + (level.random.nextDouble() - 0.5) * 0.6, 0, 0.02, 0);
        }
    }

    @Override
    public void appendHoverText(ItemStack stack, TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.echoesofsleep.insomnia_lantern.desc").withStyle(ChatFormatting.AQUA, ChatFormatting.ITALIC));
    }
}
