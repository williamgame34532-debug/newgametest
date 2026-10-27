package com.williamgame.echoesofsleep.item;

import com.williamgame.echoesofsleep.distortion.DistortionData;
import com.williamgame.echoesofsleep.entity.TheDreamer;
import com.williamgame.echoesofsleep.network.FxPacket;
import com.williamgame.echoesofsleep.network.ModNetwork;
import com.williamgame.echoesofsleep.registry.ModEntities;
import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.MobSpawnType;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.phys.AABB;

import java.util.List;

/** Dream Totem: placed on the ground while the world is in the Nightmare, it calls The Dreamer. */
public class DreamTotemItem extends Item {
    public DreamTotemItem(Properties props) {
        super(props);
    }

    @Override
    public InteractionResult useOn(UseOnContext ctx) {
        if (!(ctx.getLevel() instanceof ServerLevel sl)) return InteractionResult.SUCCESS;
        Player player = ctx.getPlayer();
        DistortionData data = DistortionData.get(sl);
        if (data.level < 3 || !data.isActive()) {
            if (player != null) {
                player.displayClientMessage(Component.translatable("message.echoesofsleep.totem.not_deep").withStyle(ChatFormatting.DARK_PURPLE), true);
            }
            return InteractionResult.FAIL;
        }
        BlockPos pos = ctx.getClickedPos().above();
        if (!sl.getEntitiesOfClass(TheDreamer.class, new AABB(pos).inflate(128)).isEmpty()) {
            if (player != null) {
                player.displayClientMessage(Component.translatable("message.echoesofsleep.totem.already").withStyle(ChatFormatting.DARK_RED), true);
            }
            return InteractionResult.FAIL;
        }
        TheDreamer dreamer = ModEntities.THE_DREAMER.get().create(sl);
        if (dreamer == null) return InteractionResult.FAIL;
        dreamer.moveTo(pos.getX() + 0.5, pos.getY() + 3.0, pos.getZ() + 0.5, 0, 0);
        dreamer.finalizeSpawn(sl, sl.getCurrentDifficultyAt(pos), MobSpawnType.TRIGGERED, null);
        sl.addFreshEntity(dreamer);
        sl.sendParticles(ParticleTypes.REVERSE_PORTAL, pos.getX() + 0.5, pos.getY() + 2, pos.getZ() + 0.5, 200, 1.0, 2.0, 1.0, 0.3);
        sl.playSound(null, pos, ModSounds.DREAMER_PULSE.get(), SoundSource.HOSTILE, 5.0F, 0.5F);
        for (ServerPlayer sp : sl.players()) {
            sp.sendSystemMessage(Component.translatable("message.echoesofsleep.dreamer_summoned").withStyle(ChatFormatting.DARK_RED, ChatFormatting.BOLD));
            if (sp.distanceToSqr(dreamer) < 64 * 64) ModNetwork.sendTo(sp, new FxPacket(FxPacket.WAKE_UP, 1.0F));
        }
        ItemStack stack = ctx.getItemInHand();
        if (player == null || !player.getAbilities().instabuild) stack.shrink(1);
        return InteractionResult.CONSUME;
    }

    @Override
    public boolean isFoil(ItemStack stack) {
        return true;
    }

    @Override
    public void appendHoverText(ItemStack stack, TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.echoesofsleep.dream_totem.desc").withStyle(ChatFormatting.DARK_RED, ChatFormatting.ITALIC));
    }
}
