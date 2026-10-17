package com.zone19.scp.item;

import com.zone19.scp.story.StoryManager;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/** S-NAV 300: points at the current objective. */
public class SnavItem extends Item {
    private static final String[] DIRS = {"s", "sw", "w", "nw", "n", "ne", "e", "se"};

    public SnavItem() {
        super(new Properties().stacksTo(1));
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (!level.isClientSide && player instanceof ServerPlayer sp) {
            BlockPos target = StoryManager.currentWaypoint(sp.server);
            if (target == null || !com.zone19.scp.world.ZoneManager.isInZone(sp)) {
                sp.displayClientMessage(Component.translatable("message.scpzone19.snav_none").withStyle(ChatFormatting.GRAY), true);
            } else {
                double dx = target.getX() + 0.5 - sp.getX();
                double dz = target.getZ() + 0.5 - sp.getZ();
                int dist = (int) Math.sqrt(dx * dx + dz * dz);
                float yaw = (float) (Mth.atan2(dz, dx) * Mth.RAD_TO_DEG) - 90.0F;
                int idx = Math.floorMod(Math.round(yaw / 45.0F), 8);
                sp.displayClientMessage(Component.translatable("message.scpzone19.snav", dist,
                        Component.translatable("dir.scpzone19." + DIRS[idx])).withStyle(ChatFormatting.GREEN), true);
            }
        }
        return InteractionResultHolder.sidedSuccess(stack, level.isClientSide);
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level world, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("tooltip.scpzone19.snav").withStyle(ChatFormatting.GRAY));
    }
}
