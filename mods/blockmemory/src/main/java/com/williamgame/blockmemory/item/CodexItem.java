package com.williamgame.blockmemory.item;

import com.williamgame.blockmemory.ModRegistry;
import com.williamgame.blockmemory.codex.CodexManager;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;
import net.minecraftforge.fml.loading.FMLEnvironment;

import java.util.List;

/** The Codex of the Forgotten: opens the book screen where collected fragments are read. */
public class CodexItem extends Item {
    public CodexItem(Properties props) {
        super(props);
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (level.isClientSide) {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.blockmemory.client.ClientHooks.openCodex();
            }
        } else if (player instanceof ServerPlayer sp) {
            CodexManager.sync(sp);
            level.playSound(null, sp.blockPosition(), ModRegistry.SOUND_CODEX_OPEN.get(), SoundSource.PLAYERS, 0.6F, 1.0F);
        }
        return InteractionResultHolder.sidedSuccess(stack, level.isClientSide);
    }

    @Override
    public void appendHoverText(ItemStack stack, Item.TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.blockmemory.codex.tip").withStyle(ChatFormatting.GRAY));
    }
}
