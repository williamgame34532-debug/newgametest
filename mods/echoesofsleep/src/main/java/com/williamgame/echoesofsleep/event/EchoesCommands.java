package com.williamgame.echoesofsleep.event;

import com.mojang.brigadier.arguments.FloatArgumentType;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.exceptions.CommandSyntaxException;
import com.williamgame.echoesofsleep.distortion.DistortionData;
import com.williamgame.echoesofsleep.distortion.DistortionManager;
import com.williamgame.echoesofsleep.memory.PlayerMemory;
import net.minecraft.ChatFormatting;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.arguments.EntityArgument;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;

/** /echoes dread [player] [value], /echoes distort <0-3>, /echoes info */
public final class EchoesCommands {
    private EchoesCommands() {
    }

    @SubscribeEvent
    public static void onCommands(RegisterCommandsEvent event) {
        event.getDispatcher().register(Commands.literal("echoes")
                .then(Commands.literal("info").executes(ctx -> info(ctx.getSource())))
                .then(Commands.literal("dread")
                        .requires(src -> src.hasPermission(2))
                        .executes(ctx -> showDread(ctx.getSource(), ctx.getSource().getPlayerOrException()))
                        .then(Commands.argument("player", EntityArgument.player())
                                .executes(ctx -> showDread(ctx.getSource(), EntityArgument.getPlayer(ctx, "player")))
                                .then(Commands.argument("value", FloatArgumentType.floatArg(0.0F, 100.0F))
                                        .executes(ctx -> {
                                            ServerPlayer p = EntityArgument.getPlayer(ctx, "player");
                                            float v = FloatArgumentType.getFloat(ctx, "value");
                                            PlayerMemory.of(p).setDread(v);
                                            ctx.getSource().sendSuccess(() -> Component.translatable("command.echoesofsleep.dread.set",
                                                    p.getDisplayName(), String.format("%.1f", v)), true);
                                            return 1;
                                        }))))
                .then(Commands.literal("distort")
                        .requires(src -> src.hasPermission(2))
                        .then(Commands.argument("level", IntegerArgumentType.integer(0, 3))
                                .executes(ctx -> {
                                    int lvl = IntegerArgumentType.getInteger(ctx, "level");
                                    ServerLevel sl = ctx.getSource().getLevel();
                                    DistortionManager.setLevel(sl, lvl);
                                    ctx.getSource().sendSuccess(() -> Component.translatable("command.echoesofsleep.distort",
                                            Component.translatable("distortion.echoesofsleep.level." + lvl),
                                            sl.dimension().location().toString()), true);
                                    return 1;
                                }))));
    }

    private static int showDread(CommandSourceStack src, ServerPlayer p) {
        float d = PlayerMemory.of(p).dread();
        src.sendSuccess(() -> Component.translatable("command.echoesofsleep.dread.show", p.getDisplayName(), String.format("%.1f", d)), false);
        return (int) d;
    }

    private static int info(CommandSourceStack src) throws CommandSyntaxException {
        ServerLevel sl = src.getLevel();
        DistortionData data = DistortionData.get(sl);
        int lvl = data.isActive() ? data.level : 0;
        src.sendSuccess(() -> Component.translatable("command.echoesofsleep.info.header").withStyle(ChatFormatting.DARK_PURPLE, ChatFormatting.BOLD), false);
        src.sendSuccess(() -> Component.translatable("command.echoesofsleep.info.distortion",
                Component.translatable("distortion.echoesofsleep.level." + lvl).withStyle(DistortionManager.levelColor(Math.max(1, lvl))),
                data.ticksLeft / 20, data.consecutiveNights, data.entries.size()), false);
        ServerPlayer p = src.getPlayer();
        if (p != null) {
            PlayerMemory m = PlayerMemory.of(p);
            src.sendSuccess(() -> Component.translatable("command.echoesofsleep.info.player",
                    String.format("%.1f", m.dread()), m.nightsWithoutSleep(), m.totalKills(), m.deaths(),
                    m.echoesSlain(), m.villagersHurt(), m.underground() / 60), false);
        }
        return lvl;
    }
}
