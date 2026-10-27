package com.williamgame.modcritic;

import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import com.williamgame.modcritic.network.CriticNetwork;
import com.williamgame.modcritic.network.OpenScreenPacket;
import net.minecraft.ChatFormatting;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.SharedSuggestionProvider;
import net.minecraft.network.chat.ClickEvent;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.HoverEvent;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;

import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Server side: the /critic command. Registered on the Forge bus from {@link ModCritic}. */
public class CriticServerEvents {
    private static final int SHOWN_ROWS = 10;

    /** Translatable with an English fallback, so clients without the mod still read something sensible. */
    static MutableComponent tr(String key, String fallback, Object... args) {
        return Component.translatableWithFallback(key, fallback, args);
    }

    @SubscribeEvent
    public static void onCommands(RegisterCommandsEvent event) {
        event.getDispatcher().register(Commands.literal("critic")
                .executes(ctx -> open(ctx, OpenScreenPacket.RATING))
                .then(Commands.literal("open")
                        .executes(ctx -> open(ctx, OpenScreenPacket.RATING))
                        .then(Commands.literal("results").executes(ctx -> open(ctx, OpenScreenPacket.RESULTS))))
                .then(Commands.literal("results")
                        .executes(CriticServerEvents::resultsAll)
                        .then(Commands.argument("player", StringArgumentType.word())
                                .suggests((ctx, builder) -> SharedSuggestionProvider.suggest(playerNames(ctx.getSource()), builder))
                                .executes(ctx -> resultsPlayer(ctx, StringArgumentType.getString(ctx, "player")))))
                .then(Commands.literal("players").executes(CriticServerEvents::listPlayers))
                .then(Commands.literal("clear")
                        .requires(src -> src.hasPermission(2))
                        .executes(ctx -> {
                            CriticSavedData.get(ctx.getSource().getServer()).clearAll();
                            ctx.getSource().sendSuccess(() -> tr("modcritic.cmd.cleared_all", "All Mod Critic ratings on this server were deleted.")
                                    .withStyle(ChatFormatting.YELLOW), true);
                            return 1;
                        })
                        .then(Commands.argument("player", StringArgumentType.word())
                                .suggests((ctx, builder) -> SharedSuggestionProvider.suggest(playerNames(ctx.getSource()), builder))
                                .executes(ctx -> {
                                    String name = StringArgumentType.getString(ctx, "player");
                                    boolean ok = CriticSavedData.get(ctx.getSource().getServer()).clearPlayer(name);
                                    if (ok) {
                                        ctx.getSource().sendSuccess(() -> tr("modcritic.cmd.cleared_player", "Ratings of %s were deleted.", name)
                                                .withStyle(ChatFormatting.YELLOW), true);
                                    } else {
                                        ctx.getSource().sendFailure(tr("modcritic.cmd.no_player", "%s has not rated anything.", name));
                                    }
                                    return ok ? 1 : 0;
                                }))));
    }

    private static List<String> playerNames(CommandSourceStack src) {
        List<String> names = new ArrayList<>();
        for (CriticSavedData.PlayerData p : CriticSavedData.get(src.getServer()).players()) names.add(p.name);
        return names;
    }

    private static int open(CommandContext<CommandSourceStack> ctx, int screen) {
        CommandSourceStack src = ctx.getSource();
        ServerPlayer player = src.getPlayer();
        if (player == null) {
            src.sendFailure(tr("modcritic.cmd.players_only", "Only players can open the Mod Critic screen. Use /critic results."));
            return 0;
        }
        if (!CriticNetwork.hasMod(player)) {
            src.sendFailure(tr("modcritic.cmd.no_client_mod",
                    "Your client does not have Mod Critic installed. Use /critic results to see the server ranking."));
            return 0;
        }
        if (screen == OpenScreenPacket.RESULTS) {
            CriticNetwork.sendTo(player, CriticSavedData.get(src.getServer()).toPacket());
        }
        CriticNetwork.sendTo(player, new OpenScreenPacket(screen));
        return 1;
    }

    private static int resultsAll(CommandContext<CommandSourceStack> ctx) {
        CommandSourceStack src = ctx.getSource();
        CriticSavedData data = CriticSavedData.get(src.getServer());
        Map<String, Collection<RatingEntry>> per = data.byPlayerName();
        if (per.isEmpty()) {
            src.sendFailure(tr("modcritic.cmd.empty", "Nobody has submitted ratings yet. Press N (or /critic) to rate the mods!"));
            return 0;
        }
        List<Scoring.Row> rows = Scoring.average(per, Scoring.equalWeights());
        src.sendSuccess(() -> header(tr("modcritic.cmd.header_server", "Server ranking (%s players)", per.size())), false);
        printRows(src, rows, true);
        printBadges(src, rows);
        return rows.size();
    }

    private static int resultsPlayer(CommandContext<CommandSourceStack> ctx, String name) {
        CommandSourceStack src = ctx.getSource();
        CriticSavedData.PlayerData pd = CriticSavedData.get(src.getServer()).byName(name);
        if (pd == null || pd.ratings.isEmpty()) {
            src.sendFailure(tr("modcritic.cmd.no_player", "%s has not rated anything.", name));
            return 0;
        }
        List<Scoring.Row> rows = Scoring.rowsOf(pd.ratings.values(), Scoring.equalWeights());
        src.sendSuccess(() -> header(tr("modcritic.cmd.header_player", "Ranking of %s", pd.name)), false);
        printRows(src, rows, false);
        printBadges(src, rows);
        return rows.size();
    }

    private static int listPlayers(CommandContext<CommandSourceStack> ctx) {
        CommandSourceStack src = ctx.getSource();
        Map<String, Integer> counts = new LinkedHashMap<>();
        for (CriticSavedData.PlayerData p : CriticSavedData.get(src.getServer()).players()) counts.put(p.name, p.ratings.size());
        if (counts.isEmpty()) {
            src.sendFailure(tr("modcritic.cmd.empty", "Nobody has submitted ratings yet. Press N (or /critic) to rate the mods!"));
            return 0;
        }
        src.sendSuccess(() -> header(tr("modcritic.cmd.header_players", "Critics")), false);
        for (Map.Entry<String, Integer> e : counts.entrySet()) {
            MutableComponent line = Component.literal(" • ").withStyle(ChatFormatting.DARK_GRAY)
                    .append(Component.literal(e.getKey()).withStyle(s -> s.withColor(ChatFormatting.AQUA)
                            .withClickEvent(new ClickEvent(ClickEvent.Action.RUN_COMMAND, "/critic results " + e.getKey()))
                            .withHoverEvent(new HoverEvent(HoverEvent.Action.SHOW_TEXT,
                                    tr("modcritic.cmd.click_player", "Click to see this player's ranking")))))
                    .append(Component.literal(" — ").withStyle(ChatFormatting.DARK_GRAY))
                    .append(tr("modcritic.cmd.mods_rated", "%s mods rated", e.getValue()).withStyle(ChatFormatting.GRAY));
            src.sendSuccess(() -> line, false);
        }
        return counts.size();
    }

    private static Component header(MutableComponent title) {
        return Component.literal("★ ").withStyle(ChatFormatting.GOLD)
                .append(tr("modcritic.name", "Mod Critic").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD))
                .append(Component.literal(" — ").withStyle(ChatFormatting.DARK_GRAY))
                .append(title.withStyle(ChatFormatting.YELLOW))
                .append(Component.literal(" ★").withStyle(ChatFormatting.GOLD));
    }

    static ChatFormatting rankColor(int rank) {
        return switch (rank) {
            case 1 -> ChatFormatting.GOLD;
            case 2 -> ChatFormatting.WHITE;
            case 3 -> ChatFormatting.RED;
            default -> ChatFormatting.GRAY;
        };
    }

    static ChatFormatting scoreColor(double v) {
        if (v >= 8.5) return ChatFormatting.GREEN;
        if (v >= 7) return ChatFormatting.YELLOW;
        if (v >= 5) return ChatFormatting.GOLD;
        return ChatFormatting.RED;
    }

    private static void printRows(CommandSourceStack src, List<Scoring.Row> rows, boolean showVoters) {
        int rank = 0;
        for (Scoring.Row r : rows) {
            rank++;
            if (rank > SHOWN_ROWS) {
                int more = rows.size() - SHOWN_ROWS;
                src.sendSuccess(() -> tr("modcritic.cmd.more", "...and %s more", more).withStyle(ChatFormatting.DARK_GRAY), false);
                break;
            }
            MutableComponent hover = Component.literal(r.modName).withStyle(ChatFormatting.GOLD);
            for (Criterion c : Criterion.values()) {
                hover.append(Component.literal("\n"))
                        .append(tr(c.nameKey(), c.englishName()).withStyle(ChatFormatting.GRAY))
                        .append(Component.literal(": " + Scoring.fmt(r.scores[c.ordinal()])).withStyle(scoreColor(r.scores[c.ordinal()])));
            }
            for (String comment : r.comments) {
                hover.append(Component.literal("\n“" + comment + "”").withStyle(ChatFormatting.ITALIC, ChatFormatting.DARK_AQUA));
            }
            MutableComponent line = Component.literal("#" + rank + " ").withStyle(rankColor(rank), ChatFormatting.BOLD)
                    .append(Component.literal(r.modName).withStyle(s -> s.withColor(ChatFormatting.WHITE)
                            .withHoverEvent(new HoverEvent(HoverEvent.Action.SHOW_TEXT, hover))))
                    .append(Component.literal(" — ").withStyle(ChatFormatting.DARK_GRAY))
                    .append(Component.literal(Scoring.fmt2(r.total)).withStyle(scoreColor(r.total), ChatFormatting.BOLD))
                    .append(Component.literal(" " + Scoring.textStars(r.total)).withStyle(ChatFormatting.GOLD));
            if (showVoters) {
                line.append(Component.literal(" ").append(tr("modcritic.cmd.votes", "(%s votes)", r.voters)).withStyle(ChatFormatting.DARK_GRAY));
            }
            src.sendSuccess(() -> line, false);
        }
    }

    private static void printBadges(CommandSourceStack src, List<Scoring.Row> rows) {
        if (rows.size() < 2) return;
        Scoring.Row[] best = Scoring.badges(rows);
        MutableComponent line = tr("modcritic.cmd.badges", "Awards:").withStyle(ChatFormatting.LIGHT_PURPLE);
        for (Criterion c : Criterion.values()) {
            Scoring.Row r = best[c.ordinal()];
            if (r == null) continue;
            line.append(Component.literal("\n ✦ ").withStyle(s -> s.withColor(c.color & 0xFFFFFF)))
                    .append(tr(c.badgeKey(), c.englishBadge()).withStyle(s -> s.withColor(c.color & 0xFFFFFF)))
                    .append(Component.literal(": ").withStyle(ChatFormatting.DARK_GRAY))
                    .append(Component.literal(r.modName + " (" + Scoring.fmt(r.scores[c.ordinal()]) + ")").withStyle(ChatFormatting.WHITE));
        }
        src.sendSuccess(() -> line, false);
    }
}
