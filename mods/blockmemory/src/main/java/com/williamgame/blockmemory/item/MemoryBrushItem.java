package com.williamgame.blockmemory.item;

import com.williamgame.blockmemory.ModRegistry;
import com.williamgame.blockmemory.block.ReliquaryBlockEntity;
import com.williamgame.blockmemory.codex.CodexManager;
import com.williamgame.blockmemory.history.MemoryService;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.ExperienceOrb;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.item.UseAnim;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;

import java.util.List;

/**
 * Memory Brush. Tap use on a block: read its history. Hold for ~2 seconds: ghost replay of what used to
 * stand around it. Hold on a Memory Reliquary: dig a Memory Fragment out of it.
 */
public class MemoryBrushItem extends Item {
    public static final int USE_DURATION = 72000;
    public static final int REPLAY_TICKS = 36;
    public static final int RELIQUARY_TICKS = 50;

    public MemoryBrushItem(Properties props) {
        super(props);
    }

    @Override
    public int getUseDuration(ItemStack stack, LivingEntity entity) {
        return USE_DURATION;
    }

    @Override
    public UseAnim getUseAnimation(ItemStack stack) {
        return UseAnim.BRUSH;
    }

    @Override
    public InteractionResult useOn(UseOnContext ctx) {
        Player player = ctx.getPlayer();
        if (player != null) {
            player.startUsingItem(ctx.getHand());
        }
        return InteractionResult.CONSUME;
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        player.startUsingItem(hand);
        return InteractionResultHolder.consume(player.getItemInHand(hand));
    }

    private static BlockHitResult target(Level level, Player player) {
        return getPlayerPOVHitResult(level, player, ClipContext.Fluid.NONE);
    }

    @Override
    public void onUseTick(Level level, LivingEntity entity, ItemStack stack, int remaining) {
        if (!(entity instanceof Player player)) return;
        int used = USE_DURATION - remaining;
        BlockHitResult hit = target(level, player);
        boolean onBlock = hit.getType() == HitResult.Type.BLOCK;
        BlockPos pos = hit.getBlockPos();
        if (level.isClientSide) {
            if (onBlock) {
                Vec3 loc = hit.getLocation();
                int count = used >= REPLAY_TICKS ? 3 : 1;
                for (int i = 0; i < count; i++) {
                    double ox = (level.random.nextDouble() - 0.5) * 0.6;
                    double oy = (level.random.nextDouble() - 0.5) * 0.6;
                    double oz = (level.random.nextDouble() - 0.5) * 0.6;
                    level.addParticle(ParticleTypes.ENCHANT, loc.x + ox, loc.y + oy, loc.z + oz,
                            (player.getX() - loc.x) * 0.6, (player.getEyeY() - loc.y) * 0.6 + 0.3, (player.getZ() - loc.z) * 0.6);
                }
                if (used == REPLAY_TICKS) {
                    for (int i = 0; i < 16; i++) {
                        level.addParticle(ParticleTypes.END_ROD, loc.x, loc.y, loc.z,
                                (level.random.nextDouble() - 0.5) * 0.2, level.random.nextDouble() * 0.15, (level.random.nextDouble() - 0.5) * 0.2);
                    }
                }
            }
            return;
        }
        if (onBlock && used % 8 == 4) {
            level.playSound(null, pos, SoundEvents.BRUSH_GENERIC, SoundSource.PLAYERS, 0.6F, 0.9F + level.random.nextFloat() * 0.2F);
        }
        if (used == REPLAY_TICKS) {
            level.playSound(null, player.blockPosition(), ModRegistry.SOUND_BRUSH_WHISPER.get(), SoundSource.PLAYERS, 0.7F, 1.0F);
        }
        if (onBlock && used == RELIQUARY_TICKS && player instanceof ServerPlayer sp
                && level.getBlockEntity(pos) instanceof ReliquaryBlockEntity reliquary) {
            readReliquary(sp, (ServerLevel) level, pos, hit, reliquary);
            player.stopUsingItem();
        }
    }

    private static void readReliquary(ServerPlayer player, ServerLevel level, BlockPos pos, BlockHitResult hit, ReliquaryBlockEntity reliquary) {
        if (reliquary.hasRead(player.getUUID())) {
            player.displayClientMessage(Component.translatable("blockmemory.reliquary.empty").withStyle(ChatFormatting.GRAY), true);
            return;
        }
        reliquary.markRead(player.getUUID());
        int idx = CodexManager.pickMissing(player, level.random);
        if (idx >= 0) {
            Block.popResourceFromFace(level, pos, hit.getDirection(), MemoryFragmentItem.identified(idx));
            player.displayClientMessage(Component.translatable("blockmemory.reliquary.found").withStyle(ChatFormatting.AQUA), true);
        } else {
            ExperienceOrb.award(level, Vec3.atCenterOf(pos.relative(hit.getDirection())), 30);
            player.displayClientMessage(Component.translatable("blockmemory.reliquary.all_known").withStyle(ChatFormatting.GOLD), true);
        }
        level.playSound(null, pos, SoundEvents.AMETHYST_BLOCK_RESONATE, SoundSource.BLOCKS, 1.0F, 0.8F);
        level.playSound(null, pos, ModRegistry.SOUND_BRUSH_WHISPER.get(), SoundSource.BLOCKS, 0.8F, 1.2F);
        level.sendParticles(ParticleTypes.END_ROD, pos.getX() + 0.5, pos.getY() + 0.5, pos.getZ() + 0.5, 30, 0.4, 0.4, 0.4, 0.08);
    }

    @Override
    public void releaseUsing(ItemStack stack, Level level, LivingEntity entity, int timeLeft) {
        if (level.isClientSide || !(entity instanceof ServerPlayer player)) return;
        int used = USE_DURATION - timeLeft;
        BlockHitResult hit = target(level, player);
        ServerLevel server = (ServerLevel) level;
        if (used >= REPLAY_TICKS) {
            BlockPos center = hit.getType() == HitResult.Type.BLOCK ? hit.getBlockPos() : player.blockPosition();
            int n = MemoryService.replay(player, center);
            if (n > 0) {
                player.displayClientMessage(Component.translatable("blockmemory.brush.replay", n).withStyle(ChatFormatting.AQUA), true);
                stack.hurtAndBreak(1, player, LivingEntity.getSlotForHand(player.getUsedItemHand()));
            } else {
                player.displayClientMessage(Component.translatable("blockmemory.brush.replay_none").withStyle(ChatFormatting.GRAY), true);
            }
            player.getCooldowns().addCooldown(this, 30);
            return;
        }
        if (hit.getType() != HitResult.Type.BLOCK) {
            player.displayClientMessage(Component.translatable("blockmemory.brush.no_target").withStyle(ChatFormatting.GRAY), true);
            return;
        }
        BlockPos pos = hit.getBlockPos();
        BlockPos front = pos.relative(hit.getDirection());
        for (Component line : MemoryService.describe(server, pos)) player.sendSystemMessage(line);
        if (MemoryService.hasMemory(server, front)) {
            for (Component line : MemoryService.describe(server, front)) player.sendSystemMessage(line);
        }
        server.playSound(null, pos, ModRegistry.SOUND_BRUSH_WHISPER.get(), SoundSource.PLAYERS, 0.4F, 1.4F);
        server.sendParticles(ParticleTypes.ENCHANT, pos.getX() + 0.5, pos.getY() + 1.0, pos.getZ() + 0.5, 12, 0.4, 0.3, 0.4, 0.5);
    }

    @Override
    public void appendHoverText(ItemStack stack, Item.TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.blockmemory.memory_brush.tip1").withStyle(ChatFormatting.GRAY));
        tooltip.add(Component.translatable("item.blockmemory.memory_brush.tip2").withStyle(ChatFormatting.GRAY));
        tooltip.add(Component.translatable("item.blockmemory.memory_brush.tip3").withStyle(ChatFormatting.DARK_AQUA));
    }
}
