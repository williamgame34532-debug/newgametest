package com.williamgame.symbiont;

/**
 * Every visual/gameplay form of the symbiont: the Hatchling plus 3 stages for each of the 4 branches.
 * Common-side (no client classes). Models/textures are chosen on the client by {@link #id}.
 */
public enum Form {
    HATCHLING("hatchling", null, 0, 0.5F, 0.55F, false, 14, 1, 0.28),
    MINER_1("miner_1", Branch.MINER, 1, 0.6F, 0.6F, false, 22, 2, 0.28),
    MINER_2("miner_2", Branch.MINER, 2, 0.85F, 0.85F, false, 34, 4, 0.27),
    MINER_3("miner_3", Branch.MINER, 3, 1.3F, 1.4F, false, 55, 6, 0.26),
    WARRIOR_1("warrior_1", Branch.WARRIOR, 1, 0.55F, 1.05F, false, 26, 4, 0.30),
    WARRIOR_2("warrior_2", Branch.WARRIOR, 2, 0.9F, 1.2F, false, 44, 7, 0.32),
    WARRIOR_3("warrior_3", Branch.WARRIOR, 3, 0.9F, 2.25F, false, 75, 11, 0.32),
    FARMER_1("farmer_1", Branch.FARMER, 1, 0.5F, 0.75F, false, 20, 1, 0.27),
    FARMER_2("farmer_2", Branch.FARMER, 2, 0.95F, 0.85F, false, 32, 2, 0.24),
    FARMER_3("farmer_3", Branch.FARMER, 3, 1.2F, 2.0F, false, 48, 3, 0.27),
    EXPLORER_1("explorer_1", Branch.EXPLORER, 1, 0.5F, 0.55F, false, 18, 1, 0.33),
    EXPLORER_2("explorer_2", Branch.EXPLORER, 2, 1.0F, 0.6F, true, 28, 2, 0.34),
    EXPLORER_3("explorer_3", Branch.EXPLORER, 3, 1.4F, 1.4F, true, 42, 3, 0.36);

    public final String id;
    public final Branch branch;
    public final int stage;
    public final float width;
    public final float height;
    public final boolean flying;
    public final double maxHealth;
    public final double damage;
    public final double speed;

    Form(String id, Branch branch, int stage, float width, float height, boolean flying, double maxHealth, double damage, double speed) {
        this.id = id;
        this.branch = branch;
        this.stage = stage;
        this.width = width;
        this.height = height;
        this.flying = flying;
        this.maxHealth = maxHealth;
        this.damage = damage;
        this.speed = speed;
    }

    public static Form of(Branch branch, int stage) {
        if (branch == null || stage <= 0) return HATCHLING;
        int s = Math.min(3, stage);
        for (Form f : values()) {
            if (f.branch == branch && f.stage == s) return f;
        }
        return HATCHLING;
    }

    public static Form byOrdinal(int i) {
        Form[] v = values();
        return i >= 0 && i < v.length ? v[i] : HATCHLING;
    }

    public String translationKey() {
        return "symbiont.form." + id;
    }
}
