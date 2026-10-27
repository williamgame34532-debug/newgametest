package com.williamgame.modcritic;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Pure maths shared by client screens, the markdown export and the server command. */
public final class Scoring {
    private Scoring() {
    }

    public static double[] equalWeights() {
        double[] w = new double[Criterion.COUNT];
        java.util.Arrays.fill(w, 1.0);
        return w;
    }

    /** Weighted mean of the scores (1..10). Falls back to a plain mean when every weight is zero. */
    public static double weighted(double[] scores, double[] weights) {
        double sum = 0, wsum = 0;
        for (int i = 0; i < Criterion.COUNT; i++) {
            double w = weights != null && i < weights.length ? Math.max(0, weights[i]) : 1.0;
            sum += scores[i] * w;
            wsum += w;
        }
        if (wsum <= 0.0001) {
            sum = 0;
            for (int i = 0; i < Criterion.COUNT; i++) sum += scores[i];
            return sum / Criterion.COUNT;
        }
        return sum / wsum;
    }

    /** One row of a ranking: a mod with its (possibly averaged) scores. */
    public static final class Row {
        public final String modId;
        public final String modName;
        public final double[] scores;
        public final int voters;
        public final List<String> comments;
        public double total;

        public Row(String modId, String modName, double[] scores, int voters, List<String> comments) {
            this.modId = modId;
            this.modName = modName;
            this.scores = scores;
            this.voters = voters;
            this.comments = comments;
        }
    }

    /** Builds rows from one person's entries. */
    public static List<Row> rowsOf(Collection<RatingEntry> entries, double[] weights) {
        List<Row> rows = new ArrayList<>();
        for (RatingEntry e : entries) {
            List<String> comments = new ArrayList<>();
            if (e.comment != null && !e.comment.isBlank()) comments.add(e.comment);
            Row r = new Row(e.modId, e.modName, e.scoresAsDouble(), 1, comments);
            rows.add(r);
        }
        return rank(rows, weights);
    }

    /**
     * Averages several people's entries per mod.
     * @param perPlayer player name -> that player's entries
     */
    public static List<Row> average(Map<String, ? extends Collection<RatingEntry>> perPlayer, double[] weights) {
        Map<String, double[]> sums = new LinkedHashMap<>();
        Map<String, Integer> counts = new LinkedHashMap<>();
        Map<String, String> names = new LinkedHashMap<>();
        Map<String, List<String>> comments = new LinkedHashMap<>();
        for (Map.Entry<String, ? extends Collection<RatingEntry>> pe : perPlayer.entrySet()) {
            for (RatingEntry e : pe.getValue()) {
                double[] s = sums.computeIfAbsent(e.modId, k -> new double[Criterion.COUNT]);
                for (int i = 0; i < Criterion.COUNT; i++) s[i] += e.scores[i];
                counts.merge(e.modId, 1, Integer::sum);
                names.putIfAbsent(e.modId, e.modName);
                if (e.comment != null && !e.comment.isBlank()) {
                    comments.computeIfAbsent(e.modId, k -> new ArrayList<>()).add(pe.getKey() + ": " + e.comment);
                }
            }
        }
        List<Row> rows = new ArrayList<>();
        for (Map.Entry<String, double[]> se : sums.entrySet()) {
            int n = counts.get(se.getKey());
            double[] avg = new double[Criterion.COUNT];
            for (int i = 0; i < Criterion.COUNT; i++) avg[i] = se.getValue()[i] / n;
            rows.add(new Row(se.getKey(), names.get(se.getKey()), avg, n,
                    comments.getOrDefault(se.getKey(), new ArrayList<>())));
        }
        return rank(rows, weights);
    }

    /** Computes totals and sorts: higher total first, pinned pack mods win ties, then by name. */
    public static List<Row> rank(List<Row> rows, double[] weights) {
        for (Row r : rows) r.total = weighted(r.scores, weights);
        rows.sort(Comparator.comparingDouble((Row r) -> -r.total)
                .thenComparingInt(r -> {
                    int p = ModCritic.pinIndex(r.modId);
                    return p < 0 ? 99 : p;
                })
                .thenComparing(r -> r.modName.toLowerCase(java.util.Locale.ROOT)));
        return rows;
    }

    /**
     * Best mod per criterion ("badge"). Index = criterion ordinal, value = row or null.
     * Needs at least two rated mods to be meaningful; with one mod it still gets every badge.
     */
    public static Row[] badges(List<Row> rows) {
        Row[] best = new Row[Criterion.COUNT];
        for (int i = 0; i < Criterion.COUNT; i++) {
            for (Row r : rows) {
                if (best[i] == null || r.scores[i] > best[i].scores[i] + 1e-9) best[i] = r;
            }
        }
        return best;
    }

    public static String fmt(double v) {
        return String.format(java.util.Locale.ROOT, "%.1f", v);
    }

    public static String fmt2(double v) {
        return String.format(java.util.Locale.ROOT, "%.2f", v);
    }

    /** Text stars for chat/markdown: 10 points = 5 stars (rounded to whole stars). */
    public static String textStars(double score) {
        int full = (int) Math.round(score / 2.0);
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 5; i++) sb.append(i < full ? '\u2605' : '\u2606');
        return sb.toString();
    }
}
