package com.williamgame.modcritic;

import java.util.Arrays;

/**
 * One player's rating of one mod. Plain mutable class so that Gson can (de)serialise it.
 */
public class RatingEntry {
    public static final int MAX_COMMENT = 256;

    public String modId = "";
    public String modName = "";
    public int[] scores = defaultScores();
    public String comment = "";
    public long time;

    public RatingEntry() {
    }

    public RatingEntry(String modId, String modName) {
        this.modId = modId;
        this.modName = modName;
        this.time = System.currentTimeMillis();
    }

    public static int[] defaultScores() {
        int[] s = new int[Criterion.COUNT];
        Arrays.fill(s, Criterion.DEFAULT_SCORE);
        return s;
    }

    /** Fixes anything a hand-edited file or a malicious packet could break. */
    public RatingEntry sanitize() {
        if (modId == null) modId = "";
        if (modName == null || modName.isBlank()) modName = modId;
        if (modName.length() > 64) modName = modName.substring(0, 64);
        if (comment == null) comment = "";
        if (comment.length() > MAX_COMMENT) comment = comment.substring(0, MAX_COMMENT);
        int[] fixed = defaultScores();
        if (scores != null) {
            for (int i = 0; i < Math.min(scores.length, fixed.length); i++) {
                fixed[i] = Criterion.clampScore(scores[i]);
            }
        }
        scores = fixed;
        return this;
    }

    public RatingEntry copy() {
        RatingEntry e = new RatingEntry();
        e.modId = modId;
        e.modName = modName;
        e.scores = scores.clone();
        e.comment = comment;
        e.time = time;
        return e;
    }

    public double[] scoresAsDouble() {
        double[] d = new double[Criterion.COUNT];
        for (int i = 0; i < d.length; i++) d[i] = scores[i];
        return d;
    }
}
