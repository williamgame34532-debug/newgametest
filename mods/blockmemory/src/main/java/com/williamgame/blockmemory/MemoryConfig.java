package com.williamgame.blockmemory;

import net.minecraftforge.common.ForgeConfigSpec;

public class MemoryConfig {
    public static final ForgeConfigSpec.Builder BUILDER = new ForgeConfigSpec.Builder();

    static {
        BUILDER.comment("Block history tracking").push("history");
    }

    public static final ForgeConfigSpec.IntValue MAX_ENTRIES_PER_CHUNK = BUILDER
            .comment("Maximum remembered changes per chunk (oldest are forgotten first)")
            .defineInRange("maxEntriesPerChunk", 768, 64, 16384);
    public static final ForgeConfigSpec.IntValue MAX_ENTRIES_PER_BLOCK = BUILDER
            .comment("Maximum remembered changes per single block position")
            .defineInRange("maxEntriesPerBlock", 8, 1, 64);
    public static final ForgeConfigSpec.BooleanValue TRACK_EXPLOSIONS = BUILDER
            .comment("Remember blocks destroyed by explosions")
            .define("trackExplosions", true);
    public static final ForgeConfigSpec.BooleanValue TRACK_MOBS = BUILDER
            .comment("Remember blocks placed by non-player entities (endermen, snow golems...)")
            .define("trackMobs", true);

    static {
        BUILDER.pop();
        BUILDER.comment("Tools").push("tools");
    }

    public static final ForgeConfigSpec.IntValue LENS_RADIUS = BUILDER
            .comment("Echo Lens radius in blocks")
            .defineInRange("lensRadius", 12, 4, 32);
    public static final ForgeConfigSpec.IntValue LENS_MINUTES = BUILDER
            .comment("Echo Lens shows changes newer than this many minutes")
            .defineInRange("lensMinutes", 60, 1, 10080);
    public static final ForgeConfigSpec.IntValue REPLAY_RADIUS = BUILDER
            .comment("Memory Brush ghost replay radius")
            .defineInRange("replayRadius", 8, 2, 16);
    public static final ForgeConfigSpec.IntValue REPLAY_SECONDS = BUILDER
            .comment("How long ghost blocks stay visible")
            .defineInRange("replaySeconds", 12, 3, 60);
    public static final ForgeConfigSpec.IntValue RESTORE_MINUTES = BUILDER
            .comment("Tome of Restoration restores blocks removed within this many minutes")
            .defineInRange("restoreMinutes", 120, 1, 10080);
    public static final ForgeConfigSpec.IntValue RECALL_COOLDOWN = BUILDER
            .comment("Recall Charm cooldown in seconds")
            .defineInRange("recallCooldownSeconds", 300, 0, 86400);

    static {
        BUILDER.pop();
    }

    public static final ForgeConfigSpec SPEC = BUILDER.build();
}
