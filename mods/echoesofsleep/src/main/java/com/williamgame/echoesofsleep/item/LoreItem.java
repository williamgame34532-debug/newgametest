package com.williamgame.echoesofsleep.item;

import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;

import java.util.List;

/** A material with a line of lore in its tooltip. */
public class LoreItem extends Item {
    private final String key;
    private final boolean foil;

    public LoreItem(Properties props, String key, boolean foil) {
        super(props);
        this.key = key;
        this.foil = foil;
    }

    @Override
    public void appendHoverText(ItemStack stack, TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.echoesofsleep." + key + ".desc").withStyle(ChatFormatting.DARK_PURPLE, ChatFormatting.ITALIC));
    }

    @Override
    public boolean isFoil(ItemStack stack) {
        return foil || super.isFoil(stack);
    }
}
