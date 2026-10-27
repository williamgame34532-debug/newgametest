package com.williamgame.blockmemory.item;

import com.williamgame.blockmemory.ModRegistry;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Equipable;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;

import java.util.List;

/** Worn on the head (or held in a hand): shows faint outlines of recently changed blocks. */
public class EchoLensItem extends Item implements Equipable {
    public EchoLensItem(Properties props) {
        super(props);
    }

    @Override
    public EquipmentSlot getEquipmentSlot() {
        return EquipmentSlot.HEAD;
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        return swapWithEquipmentSlot(this, level, player, hand);
    }

    public static boolean isActive(Player player) {
        Item lens = ModRegistry.ECHO_LENS.get();
        return player.getItemBySlot(EquipmentSlot.HEAD).is(lens)
                || player.getOffhandItem().is(lens)
                || player.getMainHandItem().is(lens);
    }

    @Override
    public void appendHoverText(ItemStack stack, Item.TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.blockmemory.echo_lens.tip1").withStyle(ChatFormatting.GRAY));
        tooltip.add(Component.translatable("item.blockmemory.echo_lens.tip2").withStyle(ChatFormatting.DARK_AQUA));
    }
}
