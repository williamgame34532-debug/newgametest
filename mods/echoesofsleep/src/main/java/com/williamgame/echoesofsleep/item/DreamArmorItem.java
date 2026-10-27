package com.williamgame.echoesofsleep.item;

import net.minecraft.ChatFormatting;
import net.minecraft.core.Holder;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.ArmorMaterial;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;

import java.util.List;

public class DreamArmorItem extends ArmorItem {
    private final ArmorSet set;

    public DreamArmorItem(Holder<ArmorMaterial> material, Type type, Properties props, ArmorSet set) {
        super(material, type, props);
        this.set = set;
    }

    public ArmorSet getSet() {
        return set;
    }

    @Override
    public void appendHoverText(ItemStack stack, TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("tooltip.echoesofsleep.set_bonus").withStyle(ChatFormatting.GRAY));
        tooltip.add(Component.translatable("tooltip.echoesofsleep.set." + set.getName()).withStyle(ChatFormatting.DARK_AQUA));
    }
}
