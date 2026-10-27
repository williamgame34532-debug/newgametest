package com.williamgame.hideandhunt.item;

import com.williamgame.hideandhunt.game.GameManager;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;

import java.util.List;

/** Opens the Game Master settings GUI. The server checks operator permission and sends the arena data. */
public class GameMasterTabletItem extends Item {
    public GameMasterTabletItem(Properties props) {
        super(props);
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (!level.isClientSide && player instanceof ServerPlayer sp) {
            GameManager.get(sp.server).openTablet(sp);
        }
        return InteractionResultHolder.sidedSuccess(stack, level.isClientSide);
    }

    @Override
    public boolean isFoil(ItemStack stack) {
        return true;
    }

    @Override
    public void appendHoverText(ItemStack stack, Item.TooltipContext ctx, List<Component> lines, TooltipFlag flag) {
        lines.add(Component.translatable("item.hideandhunt.game_master_tablet.desc").withStyle(ChatFormatting.GRAY));
        lines.add(Component.translatable("item.hideandhunt.game_master_tablet.op").withStyle(ChatFormatting.DARK_GRAY, ChatFormatting.ITALIC));
    }
}
