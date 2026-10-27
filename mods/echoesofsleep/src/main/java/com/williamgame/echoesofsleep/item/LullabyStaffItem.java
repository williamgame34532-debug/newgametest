package com.williamgame.echoesofsleep.item;

import com.williamgame.echoesofsleep.entity.NightmareMonster;
import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.AABB;

import java.util.List;

/** Lullaby Staff: sings every nightmare within 10 blocks to sleep for 5 seconds. 15 s cooldown. */
public class LullabyStaffItem extends Item {
    public static final int SLEEP_TICKS = 100;
    public static final int COOLDOWN = 300;

    public LullabyStaffItem(Properties props) {
        super(props);
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (level instanceof ServerLevel sl) {
            List<NightmareMonster> list = sl.getEntitiesOfClass(NightmareMonster.class, new AABB(player.blockPosition()).inflate(10),
                    m -> m.isAlive() && m.distanceToSqr(player) < 100);
            for (NightmareMonster m : list) {
                m.lullToSleep(SLEEP_TICKS);
                sl.sendParticles(ParticleTypes.NOTE, m.getX(), m.getY() + m.getBbHeight() + 0.4, m.getZ(), 6, 0.4, 0.2, 0.4, 1.0);
            }
            for (int i = 0; i < 24; i++) {
                double a = i / 24.0 * Math.PI * 2;
                sl.sendParticles(ParticleTypes.NOTE, player.getX() + Math.cos(a) * 3, player.getY() + 1.0, player.getZ() + Math.sin(a) * 3, 1, 0, 0, 0, i / 24.0);
            }
            sl.playSound(null, player.getX(), player.getY(), player.getZ(), ModSounds.LULLABY.get(), SoundSource.PLAYERS, 1.2F, 1.0F);
            stack.hurtAndBreak(1, player, LivingEntity.getSlotForHand(hand));
            if (list.isEmpty()) {
                player.displayClientMessage(Component.translatable("message.echoesofsleep.lullaby.none").withStyle(ChatFormatting.GRAY), true);
            }
        }
        player.getCooldowns().addCooldown(this, COOLDOWN);
        return InteractionResultHolder.sidedSuccess(stack, level.isClientSide());
    }

    @Override
    public void appendHoverText(ItemStack stack, TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.echoesofsleep.lullaby_staff.desc").withStyle(ChatFormatting.LIGHT_PURPLE, ChatFormatting.ITALIC));
    }
}
