package com.williamgame.hideandhunt.command;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.exceptions.CommandSyntaxException;
import com.mojang.brigadier.suggestion.SuggestionProvider;
import com.mojang.brigadier.tree.LiteralCommandNode;
import com.williamgame.hideandhunt.ModRegistry;
import com.williamgame.hideandhunt.game.ArenaData;
import com.williamgame.hideandhunt.game.GameManager;
import com.williamgame.hideandhunt.game.GameSettings;
import com.williamgame.hideandhunt.game.Side;
import com.williamgame.hideandhunt.game.SpawnPoint;
import com.williamgame.hideandhunt.game.TeamDisplay;
import net.minecraft.ChatFormatting;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.SharedSuggestionProvider;
import net.minecraft.commands.arguments.EntityArgument;
import net.minecraft.commands.arguments.coordinates.BlockPosArgument;
import net.minecraft.commands.arguments.coordinates.Vec3Argument;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.phys.Vec2;
import net.minecraft.world.phys.Vec3;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;

/** /hh (alias /hideandhunt) */
public final class HHCommands {
    private HHCommands() {}

    private static final SuggestionProvider<CommandSourceStack> JOIN_SIDES =
            (ctx, b) -> SharedSuggestionProvider.suggest(List.of("hiders", "hunters", "none", "spectator"), b);
    private static final SuggestionProvider<CommandSourceStack> SPAWN_KINDS =
            (ctx, b) -> SharedSuggestionProvider.suggest(List.of("lobby", "hiders", "hunters", "spectator"), b);
    private static final SuggestionProvider<CommandSourceStack> MULTI_KINDS =
            (ctx, b) -> SharedSuggestionProvider.suggest(List.of("hiders", "hunters"), b);
    private static final SuggestionProvider<CommandSourceStack> CLEAR_KINDS =
            (ctx, b) -> SharedSuggestionProvider.suggest(List.of("hiders", "hunters", "all"), b);
    private static final SuggestionProvider<CommandSourceStack> SETTING_KEYS = (ctx, b) -> {
        List<String> keys = new ArrayList<>();
        for (GameSettings.Def d : GameSettings.DEFS) keys.add(d.key());
        return SharedSuggestionProvider.suggest(keys, b);
    };
    private static final SuggestionProvider<CommandSourceStack> SETTING_VALUES = (ctx, b) -> {
        GameSettings.Def d = GameSettings.def(StringArgumentType.getString(ctx, "key"));
        List<String> vals = new ArrayList<>();
        if (d != null) {
            switch (d.kind()) {
                case BOOL -> vals.addAll(List.of("true", "false"));
                case CHOICE -> vals.addAll(d.choices());
                default -> {
                    vals.add(String.valueOf(d.def()));
                    vals.add(String.valueOf(d.min()));
                    vals.add(String.valueOf(d.max()));
                }
            }
        }
        return SharedSuggestionProvider.suggest(vals, b);
    };

    private static LiteralArgumentBuilder<CommandSourceStack> admin(String name) {
        return Commands.literal(name).requires(s -> s.hasPermission(2));
    }

    private static MutableComponent tr(String key, Object... args) {
        return Component.translatable("hideandhunt." + key, args);
    }

    private static GameManager gm(CommandContext<CommandSourceStack> ctx) {
        return GameManager.get(ctx.getSource().getServer());
    }

    private static int ok(CommandContext<CommandSourceStack> ctx, Component msg, boolean broadcast) {
        ctx.getSource().sendSuccess(() -> GameManager.prefixed(msg), broadcast);
        return 1;
    }

    private static int fail(CommandContext<CommandSourceStack> ctx, Component msg) {
        ctx.getSource().sendFailure(GameManager.prefixed(msg.copy().withStyle(ChatFormatting.RED)));
        return 0;
    }

    public static void register(CommandDispatcher<CommandSourceStack> dispatcher) {
        LiteralArgumentBuilder<CommandSourceStack> root = Commands.literal("hh").executes(HHCommands::status)
                .then(Commands.literal("status").executes(HHCommands::status))
                .then(Commands.literal("help").executes(HHCommands::help))
                .then(Commands.literal("join")
                        .then(Commands.argument("side", StringArgumentType.word()).suggests(JOIN_SIDES)
                                .executes(ctx -> join(ctx, StringArgumentType.getString(ctx, "side")))))
                .then(Commands.literal("leave").executes(ctx -> join(ctx, "none")))
                .then(Commands.literal("taunt").executes(ctx -> {
                    gm(ctx).taunt(ctx.getSource().getPlayerOrException());
                    return 1;
                }))
                .then(admin("start").executes(ctx -> {
                    Component err = gm(ctx).tryStart(ctx.getSource().getPlayer());
                    return err != null ? fail(ctx, err) : ok(ctx, tr("msg.start_ok"), false);
                }))
                .then(admin("stop").executes(ctx -> {
                    boolean stopped = gm(ctx).stop(tr("msg.stopped_by", ctx.getSource().getDisplayName()).withStyle(ChatFormatting.RED));
                    return stopped ? ok(ctx, tr("msg.stopped"), false) : fail(ctx, tr("msg.not_running"));
                }))
                .then(admin("randomize").executes(ctx -> {
                    Component err = gm(ctx).randomize(ctx.getSource().getPlayer());
                    return err != null ? fail(ctx, err) : 1;
                }))
                .then(admin("reset")
                        .executes(ctx -> resetTeams(ctx))
                        .then(Commands.literal("teams").executes(HHCommands::resetTeams))
                        .then(Commands.literal("settings").executes(ctx -> {
                            ArenaData d = gm(ctx).data();
                            d.settings.resetToDefaults();
                            d.setDirty();
                            return ok(ctx, tr("msg.settings_reset"), true);
                        }))
                        .then(Commands.literal("arena").executes(ctx -> {
                            GameManager g = gm(ctx);
                            g.stop(null);
                            g.resetTeams();
                            g.data().resetArena();
                            return ok(ctx, tr("msg.arena_reset"), true);
                        })))
                .then(admin("team")
                        .then(Commands.argument("players", EntityArgument.players())
                                .then(Commands.argument("side", StringArgumentType.word()).suggests(JOIN_SIDES)
                                        .executes(HHCommands::team))))
                .then(admin("setspawn")
                        .then(Commands.argument("kind", StringArgumentType.word()).suggests(SPAWN_KINDS)
                                .executes(ctx -> spawn(ctx, false, false))
                                .then(Commands.argument("pos", Vec3Argument.vec3())
                                        .executes(ctx -> spawn(ctx, false, true)))))
                .then(admin("addspawn")
                        .then(Commands.argument("kind", StringArgumentType.word()).suggests(MULTI_KINDS)
                                .executes(ctx -> spawn(ctx, true, false))
                                .then(Commands.argument("pos", Vec3Argument.vec3())
                                        .executes(ctx -> spawn(ctx, true, true)))))
                .then(admin("clearspawns")
                        .then(Commands.argument("kind", StringArgumentType.word()).suggests(CLEAR_KINDS)
                                .executes(HHCommands::clearSpawns)))
                .then(admin("spawns").executes(HHCommands::listSpawns))
                .then(admin("tp")
                        .then(Commands.argument("kind", StringArgumentType.word()).suggests(SPAWN_KINDS)
                                .executes(HHCommands::tp)))
                .then(admin("setbounds")
                        .then(Commands.argument("pos1", BlockPosArgument.blockPos())
                                .then(Commands.argument("pos2", BlockPosArgument.blockPos())
                                        .executes(ctx -> {
                                            ArenaData d = gm(ctx).data();
                                            BlockPos a = BlockPosArgument.getBlockPos(ctx, "pos1");
                                            BlockPos b = BlockPosArgument.getBlockPos(ctx, "pos2");
                                            d.cornerA = a;
                                            d.cornerB = b;
                                            d.setDirty();
                                            return ok(ctx, tr("msg.bounds_set", a.toShortString(), b.toShortString()), true);
                                        }))))
                .then(admin("clearbounds").executes(ctx -> {
                    ArenaData d = gm(ctx).data();
                    d.cornerA = null;
                    d.cornerB = null;
                    d.setDirty();
                    return ok(ctx, tr("msg.bounds_cleared"), true);
                }))
                .then(admin("joinmode")
                        .then(Commands.argument("value", StringArgumentType.word())
                                .suggests((c, b) -> SharedSuggestionProvider.suggest(List.of("free", "pads", "random", "admin"), b))
                                .executes(ctx -> setSetting(ctx, GameSettings.JOIN_MODE, StringArgumentType.getString(ctx, "value")))))
                .then(admin("mode")
                        .then(Commands.argument("value", StringArgumentType.word())
                                .suggests((c, b) -> SharedSuggestionProvider.suggest(List.of("classic", "infection"), b))
                                .executes(ctx -> setSetting(ctx, GameSettings.MODE, StringArgumentType.getString(ctx, "value")))))
                .then(admin("name")
                        .then(Commands.argument("name", StringArgumentType.greedyString())
                                .executes(ctx -> {
                                    String n = StringArgumentType.getString(ctx, "name").trim();
                                    if (n.length() > 32) n = n.substring(0, 32);
                                    ArenaData d = gm(ctx).data();
                                    d.name = n;
                                    d.setDirty();
                                    return ok(ctx, tr("msg.renamed", n), true);
                                })))
                .then(admin("settings").executes(HHCommands::listSettings)
                        .then(Commands.argument("key", StringArgumentType.word()).suggests(SETTING_KEYS)
                                .executes(ctx -> showSetting(ctx, StringArgumentType.getString(ctx, "key")))
                                .then(Commands.argument("value", StringArgumentType.word()).suggests(SETTING_VALUES)
                                        .executes(ctx -> setSetting(ctx, StringArgumentType.getString(ctx, "key"),
                                                StringArgumentType.getString(ctx, "value"))))))
                .then(admin("kit")
                        .then(Commands.argument("kind", StringArgumentType.word()).suggests(MULTI_KINDS)
                                .then(Commands.literal("set").executes(ctx -> kit(ctx, true)))
                                .then(Commands.literal("clear").executes(ctx -> kit(ctx, false)))))
                .then(admin("tablet").executes(ctx -> {
                    ServerPlayer p = ctx.getSource().getPlayerOrException();
                    ItemStack st = new ItemStack(ModRegistry.TABLET.get());
                    if (!p.getInventory().add(st)) p.drop(st, false);
                    return ok(ctx, tr("msg.tablet_given"), false);
                }));
        LiteralCommandNode<CommandSourceStack> node = dispatcher.register(root);
        dispatcher.register(Commands.literal("hideandhunt").executes(HHCommands::status).redirect(node));
    }

    // ---------------------------------------------------------------- handlers

    private static int status(CommandContext<CommandSourceStack> ctx) {
        for (Component line : gm(ctx).statusLines()) ctx.getSource().sendSuccess(() -> line, false);
        return 1;
    }

    private static int help(CommandContext<CommandSourceStack> ctx) {
        String[] keys = {"join", "leave", "taunt", "status", "start", "stop", "randomize", "reset", "team", "setspawn",
                "addspawn", "clearspawns", "spawns", "tp", "setbounds", "clearbounds", "joinmode", "mode", "name", "settings", "kit", "tablet"};
        ctx.getSource().sendSuccess(() -> tr("help.header").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD), false);
        for (String k : keys) {
            ctx.getSource().sendSuccess(() -> Component.literal(" /hh " + k + " ").withStyle(ChatFormatting.YELLOW)
                    .append(tr("help." + k).withStyle(ChatFormatting.GRAY)), false);
        }
        return 1;
    }

    private static int join(CommandContext<CommandSourceStack> ctx, String sideName) throws CommandSyntaxException {
        ServerPlayer p = ctx.getSource().getPlayerOrException();
        Side side = Side.parse(sideName);
        if (side == null) return fail(ctx, tr("msg.bad_side", sideName));
        return gm(ctx).join(p, side, GameManager.JoinVia.COMMAND, false) ? 1 : 0;
    }

    private static int resetTeams(CommandContext<CommandSourceStack> ctx) {
        GameManager g = gm(ctx);
        g.stop(tr("msg.stopped_by", ctx.getSource().getDisplayName()).withStyle(ChatFormatting.RED));
        g.resetTeams();
        return ok(ctx, tr("msg.teams_reset"), true);
    }

    private static int team(CommandContext<CommandSourceStack> ctx) throws CommandSyntaxException {
        Collection<ServerPlayer> players = EntityArgument.getPlayers(ctx, "players");
        String sideName = StringArgumentType.getString(ctx, "side");
        Side side = Side.parse(sideName);
        if (side == null) return fail(ctx, tr("msg.bad_side", sideName));
        GameManager g = gm(ctx);
        int n = 0;
        for (ServerPlayer p : players) {
            Component err = g.adminSetSide(p.getUUID(), p.getGameProfile().getName(), side);
            if (err != null) return fail(ctx, err);
            n++;
        }
        return ok(ctx, tr("msg.team_set", n, side.displayName()), true);
    }

    private static int spawn(CommandContext<CommandSourceStack> ctx, boolean add, boolean withPos) {
        String kind = StringArgumentType.getString(ctx, "kind");
        Side side = Side.parse(kind);
        String which;
        if ("lobby".equalsIgnoreCase(kind)) which = "lobby";
        else if (side == Side.SPECTATOR) which = "spectator";
        else if (side == Side.HIDER) which = add ? "hider_add" : "hider_set";
        else if (side == Side.HUNTER) which = add ? "hunter_add" : "hunter_set";
        else return fail(ctx, tr("msg.bad_value", "kind", kind));
        if (add && (which.equals("lobby") || which.equals("spectator"))) return fail(ctx, tr("msg.single_spawn"));
        CommandSourceStack src = ctx.getSource();
        Vec3 pos = withPos ? Vec3Argument.getVec3(ctx, "pos") : src.getPosition();
        Vec2 rot = src.getRotation();
        SpawnPoint sp = new SpawnPoint(pos.x, pos.y, pos.z, rot.y, rot.x);
        return ok(ctx, gm(ctx).setSpawn(src.getLevel(), sp, which), true);
    }

    private static int clearSpawns(CommandContext<CommandSourceStack> ctx) {
        String kind = StringArgumentType.getString(ctx, "kind");
        ArenaData d = gm(ctx).data();
        Side side = Side.parse(kind);
        if ("all".equalsIgnoreCase(kind)) {
            d.hiderSpawns.clear();
            d.hunterSpawns.clear();
            d.lobby = null;
            d.spectator = null;
        } else if (side == Side.HIDER) d.hiderSpawns.clear();
        else if (side == Side.HUNTER) d.hunterSpawns.clear();
        else return fail(ctx, tr("msg.bad_value", "kind", kind));
        d.setDirty();
        return ok(ctx, tr("msg.spawns_cleared", Component.literal(kind)), true);
    }

    private static int listSpawns(CommandContext<CommandSourceStack> ctx) {
        ArenaData d = gm(ctx).data();
        CommandSourceStack src = ctx.getSource();
        src.sendSuccess(() -> tr("spawns.header", d.name, d.dimension).withStyle(ChatFormatting.GOLD), false);
        src.sendSuccess(() -> Component.literal(" ").append(tr("spawn.lobby")).append(": " + (d.lobby == null ? "-" : d.lobby.shortString())), false);
        src.sendSuccess(() -> Component.literal(" ").append(tr("spawn.spectator")).append(": " + (d.spectator == null ? "-" : d.spectator.shortString())), false);
        for (int i = 0; i < d.hiderSpawns.size(); i++) {
            int n = i + 1;
            String s = d.hiderSpawns.get(i).shortString();
            src.sendSuccess(() -> Component.literal(" ").append(tr("spawn.hiders").withStyle(ChatFormatting.GREEN)).append(" #" + n + ": " + s), false);
        }
        for (int i = 0; i < d.hunterSpawns.size(); i++) {
            int n = i + 1;
            String s = d.hunterSpawns.get(i).shortString();
            src.sendSuccess(() -> Component.literal(" ").append(tr("spawn.hunters").withStyle(ChatFormatting.RED)).append(" #" + n + ": " + s), false);
        }
        String bounds = d.hasBounds() ? d.cornerA.toShortString() + " -> " + d.cornerB.toShortString() : "-";
        src.sendSuccess(() -> Component.literal(" ").append(tr("spawn.bounds")).append(": " + bounds), false);
        return 1;
    }

    private static int tp(CommandContext<CommandSourceStack> ctx) throws CommandSyntaxException {
        ServerPlayer p = ctx.getSource().getPlayerOrException();
        ArenaData d = gm(ctx).data();
        String kind = StringArgumentType.getString(ctx, "kind");
        Side side = Side.parse(kind);
        SpawnPoint sp = null;
        if ("lobby".equalsIgnoreCase(kind)) sp = d.lobby;
        else if (side == Side.SPECTATOR) sp = d.spectator;
        else if (side == Side.HIDER && !d.hiderSpawns.isEmpty()) sp = d.hiderSpawns.get(p.getRandom().nextInt(d.hiderSpawns.size()));
        else if (side == Side.HUNTER && !d.hunterSpawns.isEmpty()) sp = d.hunterSpawns.get(p.getRandom().nextInt(d.hunterSpawns.size()));
        if (sp == null) return fail(ctx, tr("msg.no_spawn", kind));
        p.teleportTo(gm(ctx).arenaLevel(), sp.x(), sp.y(), sp.z(), sp.yaw(), sp.pitch());
        return 1;
    }

    private static int listSettings(CommandContext<CommandSourceStack> ctx) {
        GameSettings s = gm(ctx).settings();
        CommandSourceStack src = ctx.getSource();
        src.sendSuccess(() -> tr("settings.header").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD), false);
        for (GameSettings.Def d : GameSettings.DEFS) {
            String v = s.valueString(d.key());
            src.sendSuccess(() -> Component.literal(" " + d.key() + " = ").withStyle(ChatFormatting.YELLOW)
                    .append(Component.literal(v + d.unit()).withStyle(ChatFormatting.WHITE))
                    .append(Component.literal("  ").append(Component.translatable(d.langKey())).withStyle(ChatFormatting.DARK_GRAY)), false);
        }
        return 1;
    }

    private static int showSetting(CommandContext<CommandSourceStack> ctx, String key) {
        GameSettings.Def d = GameSettings.def(key);
        if (d == null) return fail(ctx, tr("msg.bad_key", key));
        String v = gm(ctx).settings().valueString(key);
        String range = switch (d.kind()) {
            case BOOL -> "true/false";
            case CHOICE -> String.join("/", d.choices());
            default -> d.min() + ".." + d.max();
        };
        ctx.getSource().sendSuccess(() -> Component.literal(key + " = " + v + "  [" + range + "]").withStyle(ChatFormatting.YELLOW), false);
        ctx.getSource().sendSuccess(() -> Component.translatable(d.descKey()).withStyle(ChatFormatting.GRAY), false);
        return 1;
    }

    private static int setSetting(CommandContext<CommandSourceStack> ctx, String key, String value) {
        GameManager g = gm(ctx);
        GameSettings.Def d = GameSettings.def(key);
        if (d == null) return fail(ctx, tr("msg.bad_key", key));
        if (!g.settings().set(key, value)) return fail(ctx, tr("msg.bad_value", key, value));
        g.data().setDirty();
        TeamDisplay.ensureTeams(ctx.getSource().getServer(), g.settings());
        g.syncAll();
        String v = g.settings().valueString(key);
        return ok(ctx, tr("msg.setting_set", Component.translatable(d.langKey()), v), true);
    }

    private static int kit(CommandContext<CommandSourceStack> ctx, boolean set) throws CommandSyntaxException {
        String kind = StringArgumentType.getString(ctx, "kind");
        Side side = Side.parse(kind);
        if (side != Side.HIDER && side != Side.HUNTER) return fail(ctx, tr("msg.bad_value", "kind", kind));
        GameManager g = gm(ctx);
        if (set) {
            ServerPlayer p = ctx.getSource().getPlayerOrException();
            int n = g.captureKit(p, side);
            return ok(ctx, tr("msg.kit_saved", side.pluralName(), n), true);
        }
        g.data().setKit(side, new net.minecraft.nbt.ListTag());
        return ok(ctx, tr("msg.kit_cleared", side.pluralName()), true);
    }
}
