package com.williamgame.hideandhunt.game;

import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.ServerScoreboard;
import net.minecraft.world.scores.DisplaySlot;
import net.minecraft.world.scores.Objective;
import net.minecraft.world.scores.PlayerTeam;
import net.minecraft.world.scores.ScoreAccess;
import net.minecraft.world.scores.ScoreHolder;
import net.minecraft.world.scores.Team;
import net.minecraft.world.scores.criteria.ObjectiveCriteria;

import java.util.UUID;

/** Coloured vanilla scoreboard teams (name tags, tab list) and the sidebar. */
public final class TeamDisplay {
    private TeamDisplay() {}

    public static final String TEAM_HIDERS = "hh_hiders";
    public static final String TEAM_HUNTERS = "hh_hunters";
    public static final String TEAM_SPECT = "hh_spect";
    public static final String SIDEBAR = "hh_sidebar";

    private static boolean ours(String team) {
        return TEAM_HIDERS.equals(team) || TEAM_HUNTERS.equals(team) || TEAM_SPECT.equals(team);
    }

    private static PlayerTeam team(ServerScoreboard sb, String name) {
        PlayerTeam t = sb.getPlayerTeam(name);
        if (t == null) t = sb.addPlayerTeam(name);
        return t;
    }

    public static void ensureTeams(MinecraftServer server, GameSettings s) {
        ServerScoreboard sb = server.getScoreboard();
        PlayerTeam h = team(sb, TEAM_HIDERS);
        h.setDisplayName(Component.translatable("hideandhunt.side.hider.plural"));
        h.setColor(ChatFormatting.GREEN);
        h.setPlayerPrefix(Component.literal("[").append(Component.translatable("hideandhunt.side.hider.short")).append("] ").withStyle(ChatFormatting.GREEN));
        h.setNameTagVisibility(s.getBool(GameSettings.HIDE_NAMETAGS) ? Team.Visibility.HIDE_FOR_OTHER_TEAMS : Team.Visibility.ALWAYS);
        h.setAllowFriendlyFire(s.getBool(GameSettings.FRIENDLY_FIRE));
        h.setSeeFriendlyInvisibles(true);

        PlayerTeam k = team(sb, TEAM_HUNTERS);
        k.setDisplayName(Component.translatable("hideandhunt.side.hunter.plural"));
        k.setColor(ChatFormatting.RED);
        k.setPlayerPrefix(Component.literal("[").append(Component.translatable("hideandhunt.side.hunter.short")).append("] ").withStyle(ChatFormatting.RED));
        k.setNameTagVisibility(Team.Visibility.ALWAYS);
        k.setAllowFriendlyFire(s.getBool(GameSettings.FRIENDLY_FIRE));
        k.setSeeFriendlyInvisibles(true);

        PlayerTeam sp = team(sb, TEAM_SPECT);
        sp.setDisplayName(Component.translatable("hideandhunt.side.spectator.plural"));
        sp.setColor(ChatFormatting.GRAY);
        sp.setPlayerPrefix(Component.literal("[").append(Component.translatable("hideandhunt.side.spectator.short")).append("] ").withStyle(ChatFormatting.GRAY));
        sp.setNameTagVisibility(Team.Visibility.HIDE_FOR_OTHER_TEAMS);
        sp.setCollisionRule(Team.CollisionRule.NEVER);
    }

    /** Puts a player into the coloured team for {@code side} (NONE restores the team they had before). */
    public static void assign(MinecraftServer server, ArenaData data, UUID id, String name, Side side) {
        ServerScoreboard sb = server.getScoreboard();
        PlayerTeam current = sb.getPlayersTeam(name);
        if (side == Side.NONE) {
            if (current != null && ours(current.getName())) sb.removePlayerFromTeam(name, current);
            String prev = data.prevTeams.remove(id);
            if (prev != null && !prev.isEmpty() && !ours(prev)) {
                PlayerTeam p = sb.getPlayerTeam(prev);
                if (p != null) sb.addPlayerToTeam(name, p);
            }
            data.setDirty();
            return;
        }
        ensureTeams(server, data.settings);
        if (!data.prevTeams.containsKey(id)) {
            data.prevTeams.put(id, current != null && !ours(current.getName()) ? current.getName() : "");
            data.setDirty();
        }
        String target = side == Side.HIDER ? TEAM_HIDERS : side == Side.HUNTER ? TEAM_HUNTERS : TEAM_SPECT;
        if (current != null && current.getName().equals(target)) return;
        sb.addPlayerToTeam(name, sb.getPlayerTeam(target));
    }

    // ---------------------------------------------------------------- sidebar

    public static void showSidebar(MinecraftServer server, ArenaData data) {
        ServerScoreboard sb = server.getScoreboard();
        Objective obj = sb.getObjective(SIDEBAR);
        if (obj == null) {
            obj = sb.addObjective(SIDEBAR, ObjectiveCriteria.DUMMY,
                    Component.literal("✦ ").append(Component.literal(data.name)).append(" ✦").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD),
                    ObjectiveCriteria.RenderType.INTEGER, false, null);
        } else {
            obj.setDisplayName(Component.literal("✦ ").append(Component.literal(data.name)).append(" ✦").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD));
        }
        Objective prev = sb.getDisplayObjective(DisplaySlot.SIDEBAR);
        if (prev != null && prev != obj) {
            data.prevSidebar = prev.getName();
            data.setDirty();
        }
        sb.setDisplayObjective(DisplaySlot.SIDEBAR, obj);
    }

    public static void updateSidebar(MinecraftServer server, int hidersLeft, int hunters, int secondsLeft, int caught) {
        ServerScoreboard sb = server.getScoreboard();
        Objective obj = sb.getObjective(SIDEBAR);
        if (obj == null) return;
        line(sb, obj, "hh_time", Component.translatable("hideandhunt.sidebar.time").withStyle(ChatFormatting.YELLOW), secondsLeft);
        line(sb, obj, "hh_hiders", Component.translatable("hideandhunt.sidebar.hiders").withStyle(ChatFormatting.GREEN), hidersLeft);
        line(sb, obj, "hh_hunters", Component.translatable("hideandhunt.sidebar.hunters").withStyle(ChatFormatting.RED), hunters);
        line(sb, obj, "hh_caught", Component.translatable("hideandhunt.sidebar.caught").withStyle(ChatFormatting.GRAY), caught);
    }

    private static void line(ServerScoreboard sb, Objective obj, String holder, Component display, int value) {
        ScoreAccess a = sb.getOrCreatePlayerScore(ScoreHolder.forNameOnly(holder), obj);
        a.set(value);
        a.display(display);
    }

    public static void hideSidebar(MinecraftServer server, ArenaData data) {
        ServerScoreboard sb = server.getScoreboard();
        Objective obj = sb.getObjective(SIDEBAR);
        if (obj != null) sb.removeObjective(obj);
        if (!data.prevSidebar.isEmpty()) {
            Objective prev = sb.getObjective(data.prevSidebar);
            if (prev != null) sb.setDisplayObjective(DisplaySlot.SIDEBAR, prev);
            data.prevSidebar = "";
            data.setDirty();
        }
    }
}
