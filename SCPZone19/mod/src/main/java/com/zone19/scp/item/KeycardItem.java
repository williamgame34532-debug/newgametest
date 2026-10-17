package com.zone19.scp.item;

import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;

import java.util.List;

public class KeycardItem extends Item {
    private final int level;

    public KeycardItem(int level, Properties props) {
        super(props);
        this.level = level;
    }

    public int level() {
        return level;
    }

    /** Highest clearance the player carries anywhere in their inventory. */
    public static int bestLevel(Player player) {
        int best = 0;
        for (ItemStack s : player.getInventory().items) {
            if (s.getItem() instanceof KeycardItem k) best = Math.max(best, k.level);
        }
        for (ItemStack s : player.getInventory().offhand) {
            if (s.getItem() instanceof KeycardItem k) best = Math.max(best, k.level);
        }
        return best;
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level world, List<Component> tooltip, TooltipFlag flag) {
        if (level >= 6) {
            tooltip.add(Component.translatable("tooltip.scpzone19.keycard_omni").withStyle(ChatFormatting.LIGHT_PURPLE));
        } else {
            tooltip.add(Component.translatable("tooltip.scpzone19.keycard", level).withStyle(ChatFormatting.GRAY));
        }
    }
}
