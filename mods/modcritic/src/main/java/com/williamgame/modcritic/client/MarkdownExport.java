package com.williamgame.modcritic.client;

import com.williamgame.modcritic.Criterion;
import com.williamgame.modcritic.ModCritic;
import com.williamgame.modcritic.RatingEntry;
import com.williamgame.modcritic.Scoring;
import net.minecraft.client.resources.language.I18n;
import net.minecraftforge.fml.loading.FMLPaths;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.text.SimpleDateFormat;
import java.util.Collection;
import java.util.Date;
import java.util.List;
import java.util.Map;

/** Builds the markdown report (modcritic-results.md in the game folder / clipboard). */
public final class MarkdownExport {
    public static final String FILE_NAME = "modcritic-results.md";

    private MarkdownExport() {
    }

    private static String esc(String s) {
        return s.replace("|", "\\|").replace("\n", " ");
    }

    private static String cname(Criterion c) {
        return I18n.get(c.nameKey());
    }

    public static String build(Collection<RatingEntry> mine, double[] weights, Map<String, Collection<RatingEntry>> server) {
        StringBuilder sb = new StringBuilder();
        sb.append("# ").append(I18n.get("modcritic.md.title")).append("\n\n");
        sb.append("_").append(I18n.get("modcritic.md.generated", new SimpleDateFormat("yyyy-MM-dd HH:mm").format(new Date()))).append("_\n\n");

        // weights
        sb.append("## ").append(I18n.get("modcritic.md.weights")).append("\n\n");
        sb.append("| ").append(I18n.get("modcritic.weights.criterion")).append(" | ").append(I18n.get("modcritic.md.weight")).append(" |\n|---|---:|\n");
        for (Criterion c : Criterion.values()) {
            sb.append("| ").append(cname(c)).append(" | ").append(weights[c.ordinal()]).append(" |\n");
        }
        sb.append('\n');

        List<Scoring.Row> rows = Scoring.rowsOf(mine, weights);
        sb.append("## ").append(I18n.get("modcritic.md.my_ranking")).append("\n\n");
        if (rows.isEmpty()) {
            sb.append(I18n.get("modcritic.results.empty_mine")).append("\n\n");
        } else {
            appendTable(sb, rows, false);
            appendBadges(sb, rows);
            sb.append("### ").append(I18n.get("modcritic.md.comments")).append("\n\n");
            boolean any = false;
            for (Scoring.Row r : rows) {
                for (String c : r.comments) {
                    sb.append("- **").append(esc(r.modName)).append("**: ").append(esc(c)).append('\n');
                    any = true;
                }
            }
            if (!any) sb.append("—\n");
            sb.append('\n');
        }

        if (server != null && !server.isEmpty()) {
            List<Scoring.Row> avg = Scoring.average(server, weights);
            sb.append("## ").append(I18n.get("modcritic.md.server_ranking", server.size())).append("\n\n");
            appendTable(sb, avg, true);
            appendBadges(sb, avg);
            sb.append("### ").append(I18n.get("modcritic.md.per_player")).append("\n\n");
            for (Map.Entry<String, Collection<RatingEntry>> p : server.entrySet()) {
                List<Scoring.Row> pr = Scoring.rowsOf(p.getValue(), weights);
                sb.append("- **").append(esc(p.getKey())).append("**: ");
                for (int i = 0; i < pr.size(); i++) {
                    if (i > 0) sb.append(" > ");
                    sb.append(esc(pr.get(i).modName)).append(" (").append(Scoring.fmt(pr.get(i).total)).append(')');
                }
                sb.append('\n');
            }
            sb.append('\n');
        }
        sb.append("---\n").append(I18n.get("modcritic.md.footer")).append('\n');
        return sb.toString();
    }

    private static void appendTable(StringBuilder sb, List<Scoring.Row> rows, boolean voters) {
        sb.append("| # | ").append(I18n.get("modcritic.md.mod")).append(" | ").append(I18n.get("modcritic.md.total")).append(" | ");
        for (Criterion c : Criterion.values()) sb.append(cname(c)).append(" | ");
        if (voters) sb.append(I18n.get("modcritic.md.voters")).append(" | ");
        sb.append("\n|---:|---|---:|");
        for (int i = 0; i < Criterion.COUNT; i++) sb.append("---:|");
        if (voters) sb.append("---:|");
        sb.append('\n');
        int rank = 0;
        for (Scoring.Row r : rows) {
            rank++;
            String medal = rank == 1 ? "\uD83E\uDD47 " : rank == 2 ? "\uD83E\uDD48 " : rank == 3 ? "\uD83E\uDD49 " : "";
            sb.append("| ").append(rank).append(" | ").append(medal).append("**").append(esc(r.modName)).append("** | **")
                    .append(Scoring.fmt2(r.total)).append("** ").append(Scoring.textStars(r.total)).append(" | ");
            for (Criterion c : Criterion.values()) sb.append(Scoring.fmt(r.scores[c.ordinal()])).append(" | ");
            if (voters) sb.append(r.voters).append(" | ");
            sb.append('\n');
        }
        sb.append('\n');
    }

    private static void appendBadges(StringBuilder sb, List<Scoring.Row> rows) {
        if (rows.size() < 2) return;
        Scoring.Row[] best = Scoring.badges(rows);
        sb.append("### ").append(I18n.get("modcritic.md.badges")).append("\n\n");
        for (Criterion c : Criterion.values()) {
            Scoring.Row r = best[c.ordinal()];
            if (r == null) continue;
            sb.append("- \uD83C\uDFC6 **").append(I18n.get(c.badgeKey())).append("**: ").append(esc(r.modName))
                    .append(" (").append(Scoring.fmt(r.scores[c.ordinal()])).append(")\n");
        }
        sb.append('\n');
    }

    /** Writes the report into the game directory; returns the path or null on failure. */
    public static Path write(String md) {
        Path p = FMLPaths.GAMEDIR.get().resolve(FILE_NAME);
        try {
            Files.writeString(p, md, StandardCharsets.UTF_8);
            // keep a copy next to ratings.json as well
            Files.createDirectories(LocalStore.dir());
            Files.writeString(LocalStore.dir().resolve(FILE_NAME), md, StandardCharsets.UTF_8);
            return p;
        } catch (Exception ex) {
            ModCritic.LOGGER.error("Mod Critic: could not export {}", p, ex);
            return null;
        }
    }
}
