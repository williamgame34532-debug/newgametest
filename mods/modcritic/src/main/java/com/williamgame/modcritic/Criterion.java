package com.williamgame.modcritic;

/** The eight rating criteria. Order is the order of score arrays everywhere (files, packets, NBT). */
public enum Criterion {
    IDEA("idea", 0xFFF2C94C),
    ATMOSPHERE("atmosphere", 0xFF9B6BE0),
    GAMEPLAY("gameplay", 0xFF4FC36A),
    VISUALS("visuals", 0xFF45B0EA),
    SOUND("sound", 0xFFE86FA8),
    BALANCE("balance", 0xFFEE963C),
    ORIGINALITY("originality", 0xFF35D3C0),
    REPLAYABILITY("replayability", 0xFFE85A5A);

    public static final int COUNT = values().length;
    public static final int MIN_SCORE = 1;
    public static final int MAX_SCORE = 10;
    public static final int DEFAULT_SCORE = 5;

    public final String key;
    /** ARGB colour used for bars, sliders and badges. */
    public final int color;

    Criterion(String key, int color) {
        this.key = key;
        this.color = color;
    }

    public String nameKey() {
        return "modcritic.criterion." + key;
    }

    public String descKey() {
        return "modcritic.criterion." + key + ".desc";
    }

    public String badgeKey() {
        return "modcritic.badge." + key;
    }

    /** English names, used as fallbacks in server chat for clients without the mod. */
    public String englishName() {
        return switch (this) {
            case IDEA -> "Idea";
            case ATMOSPHERE -> "Atmosphere";
            case GAMEPLAY -> "Gameplay";
            case VISUALS -> "Visuals";
            case SOUND -> "Sound";
            case BALANCE -> "Balance";
            case ORIGINALITY -> "Originality";
            case REPLAYABILITY -> "Replayability";
        };
    }

    public String englishBadge() {
        return switch (this) {
            case IDEA -> "Best idea";
            case ATMOSPHERE -> "Most atmospheric";
            case GAMEPLAY -> "Best gameplay";
            case VISUALS -> "Most beautiful";
            case SOUND -> "Best sound";
            case BALANCE -> "Best balanced";
            case ORIGINALITY -> "Most original";
            case REPLAYABILITY -> "Most replayable";
        };
    }

    public static int clampScore(int s) {
        return Math.max(MIN_SCORE, Math.min(MAX_SCORE, s));
    }
}
