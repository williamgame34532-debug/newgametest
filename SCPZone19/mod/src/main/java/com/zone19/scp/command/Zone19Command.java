package com.zone19.scp.command;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.zone19.scp.story.Chapters;
import com.zone19.scp.story.StoryData;
import com.zone19.scp.story.StoryManager;
import com.zone19.scp.world.ZoneManager;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.network.chat.Component;

/**
 * /zone19 enter | leave | status — for everyone
 * /zone19 chapter <1-6> | skip | reset — operators
 */
public final class Zone19Command {
    public static void register(CommandDispatcher<CommandSourceStack> dispatcher) {
        dispatcher.register(Commands.literal("zone19")
                .then(Commands.literal("enter").executes(c -> {
                    ZoneManager.enter(c.getSource().getPlayerOrException());
                    return 1;
                }))
                .then(Commands.literal("leave").executes(c -> {
                    ZoneManager.leave(c.getSource().getPlayerOrException());
                    return 1;
                }))
                .then(Commands.literal("status").executes(c -> {
                    StoryData d = StoryData.get(c.getSource().getServer());
                    if (d.chapter == 0) {
                        c.getSource().sendSuccess(() -> Component.translatable("command.scpzone19.status_idle"), false);
                    } else {
                        c.getSource().sendSuccess(() -> Component.translatable("command.scpzone19.status", d.chapter,
                                Component.translatable(Chapters.get(d.chapter).titleKey()), d.step + 1, d.finished), false);
                    }
                    return 1;
                }))
                .then(Commands.literal("chapter").requires(s -> s.hasPermission(2))
                        .then(Commands.argument("number", IntegerArgumentType.integer(1, Chapters.COUNT)).executes(c -> {
                            int n = IntegerArgumentType.getInteger(c, "number");
                            StoryManager.jumpTo(c.getSource().getServer(), n);
                            c.getSource().sendSuccess(() -> Component.translatable("command.scpzone19.jump", n), true);
                            return 1;
                        })))
                .then(Commands.literal("skip").requires(s -> s.hasPermission(2)).executes(c -> {
                    StoryManager.skipStep(c.getSource().getServer());
                    return 1;
                }))
                .then(Commands.literal("reset").requires(s -> s.hasPermission(2)).executes(c -> {
                    StoryManager.reset(c.getSource().getServer());
                    c.getSource().sendSuccess(() -> Component.translatable("command.scpzone19.reset"), true);
                    return 1;
                })));
    }

    private Zone19Command() {
    }
}
