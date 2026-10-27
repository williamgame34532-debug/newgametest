package com.williamgame.blockmemory.item;

import com.williamgame.blockmemory.ModRegistry;
import com.williamgame.blockmemory.codex.CodexManager;
import com.williamgame.blockmemory.codex.Fragments;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;

import java.util.List;

/**
 * A Memory Fragment. Without a fragment id it is "faded": reading it reveals a memory the reader does not
 * know yet. With an id (dug out of a reliquary) it is a specific page of the story and can be shared.
 */
public class MemoryFragmentItem extends Item {
    public MemoryFragmentItem(Properties props) {
        super(props);
    }

    public static ItemStack identified(int index) {
        ItemStack stack = new ItemStack(ModRegistry.MEMORY_FRAGMENT.get());
        stack.set(ModRegistry.FRAGMENT_ID.get(), index);
        return stack;
    }

    public static int fragmentId(ItemStack stack) {
        Integer id = stack.get(ModRegistry.FRAGMENT_ID.get());
        return id != null && Fragments.valid(id) ? id : -1;
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (level.isClientSide || !(player instanceof ServerPlayer sp)) {
            return InteractionResultHolder.success(stack);
        }
        int id = fragmentId(stack);
        if (id >= 0) {
            if (CodexManager.knows(sp, id)) {
                sp.displayClientMessage(Component.translatable("blockmemory.fragment.known", Fragments.title(id)).withStyle(ChatFormatting.GRAY), true);
                return InteractionResultHolder.fail(stack);
            }
            CodexManager.unlock(sp, id);
        } else {
            int pick = CodexManager.pickMissing(sp, level.random);
            if (pick < 0) {
                sp.giveExperiencePoints(15);
                sp.displayClientMessage(Component.translatable("blockmemory.fragment.all_known").withStyle(ChatFormatting.GOLD), true);
                level.playSound(null, sp.blockPosition(), SoundEvents.EXPERIENCE_ORB_PICKUP, SoundSource.PLAYERS, 0.6F, 1.0F);
            } else {
                CodexManager.unlock(sp, pick);
            }
        }
        if (!sp.getAbilities().instabuild) stack.shrink(1);
        return InteractionResultHolder.consume(stack);
    }

    @Override
    public Component getName(ItemStack stack) {
        int id = fragmentId(stack);
        if (id >= 0) {
            return Component.translatable("item.blockmemory.memory_fragment.identified", Fragments.label(id));
        }
        return super.getName(stack);
    }

    @Override
    public boolean isFoil(ItemStack stack) {
        return fragmentId(stack) >= 0;
    }

    @Override
    public void appendHoverText(ItemStack stack, Item.TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        int id = fragmentId(stack);
        if (id >= 0) {
            tooltip.add(Fragments.chapterTitle(Fragments.chapterOf(id)).copy().withStyle(ChatFormatting.DARK_AQUA));
            tooltip.add(Component.literal("“").append(Fragments.title(id)).append("”").withStyle(ChatFormatting.GOLD, ChatFormatting.ITALIC));
            tooltip.add(Component.translatable("item.blockmemory.memory_fragment.tip_id").withStyle(ChatFormatting.GRAY));
        } else {
            tooltip.add(Component.translatable("item.blockmemory.memory_fragment.tip").withStyle(ChatFormatting.GRAY));
        }
    }
}
