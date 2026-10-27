package com.williamgame.blockmemory;

import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import com.williamgame.blockmemory.codex.CodexManager;
import com.williamgame.blockmemory.codex.Fragments;
import com.williamgame.blockmemory.history.BlockHistoryData;
import com.williamgame.blockmemory.history.HistoryAction;
import com.williamgame.blockmemory.history.MemoryService;
import com.williamgame.blockmemory.item.ArchivistArmorItem;
import com.williamgame.blockmemory.item.EchoLensItem;
import com.williamgame.blockmemory.network.LensPacket;
import com.williamgame.blockmemory.network.ModNetwork;
import net.minecraft.ChatFormatting;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.arguments.EntityArgument;
import net.minecraft.commands.arguments.coordinates.BlockPosArgument;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Explosion;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraftforge.common.util.BlockSnapshot;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.event.entity.player.PlayerEvent;
import net.minecraftforge.event.level.BlockEvent;
import net.minecraftforge.event.level.ExplosionEvent;
import net.minecraftforge.eventbus.api.EventPriority;
import net.minecraftforge.eventbus.api.SubscribeEvent;

import java.util.Collection;
import java.util.List;
import java.util.UUID;

public class CommonEvents {

    // ------------------------------------------------------------------ history tracking

    @SubscribeEvent(priority = EventPriority.LOWEST)
    public static void onPlace(BlockEvent.EntityPlaceEvent event) {
        if (!(event.getLevel() instanceof ServerLevel level)) return;
        Entity entity = event.getEntity();
        if (!(entity instanceof Player) && (entity == null || !MemoryConfig.TRACK_MOBS.get())) return;
        UUID id = entity instanceof Player p ? p.getUUID() : null;
        String name = actorName(entity);
        BlockHistoryData data = BlockHistoryData.get(level);
        if (event instanceof BlockEvent.EntityMultiPlaceEvent multi) {
            for (BlockSnapshot snap : multi.getReplacedBlockSnapshots()) {
                data.record(snap.getPos(), HistoryAction.PLACED, id, name, snap.getReplacedBlock(), level.getBlockState(snap.getPos()));
            }
        } else {
            data.record(event.getPos(), HistoryAction.PLACED, id, name, event.getBlockSnapshot().getReplacedBlock(), event.getPlacedBlock());
        }
    }

    @SubscribeEvent(priority = EventPriority.LOWEST)
    public static void onBreak(BlockEvent.BreakEvent event) {
        if (!(event.getLevel() instanceof ServerLevel level)) return;
        Player player = event.getPlayer();
        BlockState state = event.getState();
        if (state.isAir() || player == null) return;
        BlockHistoryData.get(level).record(event.getPos(), HistoryAction.BROKEN, player.getUUID(), actorName(player),
                state, level.getFluidState(event.getPos()).createLegacyBlock());
    }

    @SubscribeEvent(priority = EventPriority.LOWEST)
    public static void onExplode(ExplosionEvent.Detonate event) {
        if (!(event.getLevel() instanceof ServerLevel level) || !MemoryConfig.TRACK_EXPLOSIONS.get()) return;
        Explosion explosion = event.getExplosion();
        LivingEntity indirect = explosion.getIndirectSourceEntity();
        Entity direct = explosion.getDirectSourceEntity();
        UUID id = indirect instanceof Player p ? p.getUUID() : null;
        String name = indirect instanceof Player ? actorName(indirect)
                : direct != null ? actorName(direct) : indirect != null ? actorName(indirect) : "Explosion";
        BlockHistoryData data = BlockHistoryData.get(level);
        List<BlockPos> blocks = event.getAffectedBlocks();
        int n = 0;
        for (BlockPos pos : blocks) {
            BlockState state = level.getBlockState(pos);
            if (state.isAir()) continue;
            data.record(pos, HistoryAction.EXPLODED, id, name, state, level.getFluidState(pos).createLegacyBlock());
            if (++n >= 4096) break;
        }
    }

    private static String actorName(Entity entity) {
        if (entity == null) return "?";
        if (entity instanceof Player p) return p.getGameProfile().getName();
        return entity.getName().getString();
    }

    // ------------------------------------------------------------------ players

    @SubscribeEvent
    public static void onLogin(PlayerEvent.PlayerLoggedInEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) {
            CodexManager.sync(sp);
        }
    }

    @SubscribeEvent
    public static void onRespawn(PlayerEvent.PlayerRespawnEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) {
            CodexManager.sync(sp);
        }
    }

    @SubscribeEvent
    public static void onPlayerTick(TickEvent.PlayerTickEvent.Post event) {
        if (!(event.player instanceof ServerPlayer sp) || sp.tickCount % 20 != 0) return;
        boolean fullSet = ArchivistArmorItem.hasFullSet(sp);
        if (fullSet) {
            MobEffectInstance nv = sp.getEffect(MobEffects.NIGHT_VISION);
            if (nv == null || nv.getDuration() < 260) {
                sp.addEffect(new MobEffectInstance(MobEffects.NIGHT_VISION, 400, 0, true, false, true));
            }
        }
        if (fullSet || EchoLensItem.isActive(sp)) {
            ModNetwork.sendTo(sp, new LensPacket(MemoryService.lensMarks(sp.serverLevel(), sp.blockPosition())));
        }
    }

    // ------------------------------------------------------------------ commands

    @SubscribeEvent
    public static void onCommands(RegisterCommandsEvent event) {
        LiteralArgumentBuilder<CommandSourceStack> root = Commands.literal("memory")
                .then(Commands.literal("inspect")
                        .requires(src -> src.hasPermission(2))
                        .then(Commands.argument("pos", BlockPosArgument.blockPos())
                                .executes(ctx -> {
                                    BlockPos pos = BlockPosArgument.getLoadedBlockPos(ctx, "pos");
                                    for (Component line : MemoryService.describe(ctx.getSource().getLevel(), pos)) {
                                        ctx.getSource().sendSuccess(() -> line, false);
                                    }
                                    return 1;
                                })))
                .then(Commands.literal("replay")
                        .requires(src -> src.hasPermission(2))
                        .then(Commands.argument("pos", BlockPosArgument.blockPos())
                                .executes(ctx -> {
                                    BlockPos pos = BlockPosArgument.getLoadedBlockPos(ctx, "pos");
                                    ServerPlayer player = ctx.getSource().getPlayerOrException();
                                    int n = MemoryService.replay(player, pos);
                                    ctx.getSource().sendSuccess(() -> Component.translatable("blockmemory.command.replay", n), false);
                                    return n;
                                })))
                .then(Commands.literal("clear")
                        .requires(src -> src.hasPermission(2))
                        .then(Commands.argument("radius", IntegerArgumentType.integer(0, 256))
                                .executes(ctx -> {
                                    int radius = IntegerArgumentType.getInteger(ctx, "radius");
                                    BlockPos center = BlockPos.containing(ctx.getSource().getPosition());
                                    int n = BlockHistoryData.get(ctx.getSource().getLevel()).clear(center, radius);
                                    ctx.getSource().sendSuccess(() -> Component.translatable("blockmemory.command.cleared", n, radius), true);
                                    return n;
                                })))
                .then(Commands.literal("stats")
                        .requires(src -> src.hasPermission(2))
                        .executes(ctx -> {
                            BlockHistoryData data = BlockHistoryData.get(ctx.getSource().getLevel());
                            int entries = data.entryCount();
                            int chunks = data.chunkCount();
                            ctx.getSource().sendSuccess(() -> Component.translatable("blockmemory.command.stats", entries, chunks), false);
                            return entries;
                        }))
                .then(Commands.literal("codex")
                        .requires(src -> src.hasPermission(2))
                        .then(Commands.argument("targets", EntityArgument.players())
                                .then(Commands.literal("unlockall").executes(ctx -> {
                                    Collection<ServerPlayer> targets = EntityArgument.getPlayers(ctx, "targets");
                                    for (ServerPlayer p : targets) {
                                        CodexManager.setAll(p, Fragments.ALL_MASK, CodexManager.progress(p).claimed);
                                    }
                                    ctx.getSource().sendSuccess(() -> Component.translatable("blockmemory.command.unlockall", targets.size()), true);
                                    return targets.size();
                                }))
                                .then(Commands.literal("reset").executes(ctx -> {
                                    Collection<ServerPlayer> targets = EntityArgument.getPlayers(ctx, "targets");
                                    for (ServerPlayer p : targets) CodexManager.setAll(p, 0, 0);
                                    ctx.getSource().sendSuccess(() -> Component.translatable("blockmemory.command.reset", targets.size()), true);
                                    return targets.size();
                                }))
                                .then(Commands.literal("unlock")
                                        .then(Commands.argument("fragment", IntegerArgumentType.integer(1, Fragments.TOTAL))
                                                .executes(ctx -> {
                                                    int idx = IntegerArgumentType.getInteger(ctx, "fragment") - 1;
                                                    Collection<ServerPlayer> targets = EntityArgument.getPlayers(ctx, "targets");
                                                    for (ServerPlayer p : targets) CodexManager.unlock(p, idx);
                                                    ctx.getSource().sendSuccess(() -> Component.translatable("blockmemory.command.unlock",
                                                            Fragments.label(idx), targets.size()), true);
                                                    return targets.size();
                                                })))
                                .then(Commands.literal("status").executes(ctx -> {
                                    Collection<ServerPlayer> targets = EntityArgument.getPlayers(ctx, "targets");
                                    for (ServerPlayer p : targets) {
                                        int f = CodexManager.progress(p).fragments;
                                        int c = CodexManager.progress(p).claimed;
                                        ctx.getSource().sendSuccess(() -> Component.translatable("blockmemory.command.status",
                                                p.getDisplayName(), Integer.bitCount(f), Fragments.TOTAL, Integer.bitCount(c))
                                                .withStyle(ChatFormatting.AQUA), false);
                                    }
                                    return targets.size();
                                }))));
        event.getDispatcher().register(root);
    }
}
