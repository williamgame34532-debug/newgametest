package com.williamgame.blockmemory.item;

import com.williamgame.blockmemory.ModRegistry;
import net.minecraft.ChatFormatting;
import net.minecraft.core.Holder;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.ArmorMaterial;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;

import java.util.List;

/** Archivist armor. Full set: night vision and Echo Lens sight. */
public class ArchivistArmorItem extends ArmorItem {
    public ArchivistArmorItem(Holder<ArmorMaterial> material, Type type, Properties props) {
        super(material, type, props);
    }

    public static boolean hasFullSet(Player player) {
        return player.getItemBySlot(EquipmentSlot.HEAD).is(ModRegistry.ARCHIVIST_HOOD.get())
                && player.getItemBySlot(EquipmentSlot.CHEST).is(ModRegistry.ARCHIVIST_ROBE.get())
                && player.getItemBySlot(EquipmentSlot.LEGS).is(ModRegistry.ARCHIVIST_LEGGINGS.get())
                && player.getItemBySlot(EquipmentSlot.FEET).is(ModRegistry.ARCHIVIST_SANDALS.get());
    }

    @Override
    public void appendHoverText(ItemStack stack, Item.TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.blockmemory.archivist.set").withStyle(ChatFormatting.GOLD));
        tooltip.add(Component.translatable("item.blockmemory.archivist.bonus1").withStyle(ChatFormatting.GRAY));
        tooltip.add(Component.translatable("item.blockmemory.archivist.bonus2").withStyle(ChatFormatting.GRAY));
    }
}
