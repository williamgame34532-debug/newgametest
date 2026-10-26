package com.williamgame.apiprobe;

import com.mojang.brigadier.arguments.IntegerArgumentType;
import net.minecraft.commands.Commands;
import net.minecraft.commands.arguments.EntityArgument;
import net.minecraft.commands.arguments.coordinates.BlockPosArgument;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.event.entity.living.LivingDeathEvent;
import net.minecraftforge.event.entity.player.PlayerEvent;
import net.minecraftforge.event.entity.player.PlayerWakeUpEvent;
import net.minecraftforge.event.level.BlockEvent;
import net.minecraftforge.event.level.SleepFinishedTimeEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;

public class ProbeEvents {
    @SubscribeEvent
    public static void onCommands(RegisterCommandsEvent event) {
        event.getDispatcher().register(Commands.literal("probe")
                .requires(src -> src.hasPermission(2))
                .then(Commands.literal("set")
                        .then(Commands.argument("pos", BlockPosArgument.blockPos())
                                .then(Commands.argument("n", IntegerArgumentType.integer(0, 10))
                                        .executes(ctx -> {
                                            BlockPos pos = BlockPosArgument.getLoadedBlockPos(ctx, "pos");
                                            int n = IntegerArgumentType.getInteger(ctx, "n");
                                            ctx.getSource().sendSuccess(() -> Component.literal(pos + " " + n), true);
                                            return 1;
                                        }))))
                .then(Commands.literal("who")
                        .then(Commands.argument("target", EntityArgument.player())
                                .executes(ctx -> {
                                    ServerPlayer p = EntityArgument.getPlayer(ctx, "target");
                                    ctx.getSource().sendSuccess(() -> p.getDisplayName(), false);
                                    return 1;
                                }))));
    }

    @SubscribeEvent
    public static void onWake(PlayerWakeUpEvent event) {
        event.getEntity().getPersistentData().putLong("apiprobe_woke", event.getEntity().level().getGameTime());
    }

    @SubscribeEvent
    public static void onSleepFinished(SleepFinishedTimeEvent event) {
        long t = event.getNewTime();
    }

    @SubscribeEvent
    public static void onPlace(BlockEvent.EntityPlaceEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) {
            sp.getPersistentData().putInt("placed", sp.getPersistentData().getInt("placed") + 1);
        }
    }

    @SubscribeEvent
    public static void onBreak(BlockEvent.BreakEvent event) {
        event.getPlayer();
    }

    @SubscribeEvent
    public static void onDeath(LivingDeathEvent event) {
        event.getSource().getEntity();
    }

    @SubscribeEvent
    public static void onLogin(PlayerEvent.PlayerLoggedInEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) {
            ProbeNetwork.sendTo(sp, new ProbeSyncPacket(1, "login"));
        }
    }

    @SubscribeEvent
    public static void onClone(PlayerEvent.Clone event) {
        event.getEntity().getPersistentData().merge(event.getOriginal().getPersistentData());
    }

    @SubscribeEvent
    public static void onServerTick(TickEvent.ServerTickEvent.Post event) {
    }

    @SubscribeEvent
    public static void onPlayerTick(TickEvent.PlayerTickEvent.Post event) {
    }

    @SubscribeEvent
    public static void onLevelTick(TickEvent.LevelTickEvent.Post event) {
    }
}
