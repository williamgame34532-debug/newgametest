package com.williamgame.echoesofsleep;

import net.minecraftforge.common.ForgeConfigSpec;

public class Config {
    public static final ForgeConfigSpec.Builder BUILDER = new ForgeConfigSpec.Builder();

    static {
        BUILDER.comment("Echoes of Sleep - common settings (server side values are authoritative)").push("general");
    }

    public static final ForgeConfigSpec.DoubleValue SPAWN_RATE = BUILDER
            .comment("Multiplier for how often nightmares (Echoes) try to spawn during a Distortion. 0 disables them.")
            .defineInRange("spawnRate", 1.0, 0.0, 5.0);
    public static final ForgeConfigSpec.IntValue MAX_NIGHTMARES_PER_PLAYER = BUILDER
            .comment("Maximum number of nightmares hunting around a single player at once.")
            .defineInRange("maxNightmaresPerPlayer", 4, 0, 16);
    public static final ForgeConfigSpec.IntValue DISTORTION_DURATION = BUILDER
            .comment("How many ticks a Distortion lasts after a slept night (12000 = half a Minecraft day).")
            .defineInRange("distortionDuration", 12000, 1200, 48000);
    public static final ForgeConfigSpec.DoubleValue VISUAL_STRENGTH = BUILDER
            .comment("Client: strength of visual distortion effects (fog, camera sway, overlay). 0 disables them.")
            .defineInRange("visualStrength", 1.0, 0.0, 2.0);
    public static final ForgeConfigSpec.BooleanValue WORLD_DISTORTION = BUILDER
            .comment("Whether the Distortion temporarily changes blocks near players (always reverted). Disable on servers if you wish.")
            .define("worldBlockDistortion", true);
    public static final ForgeConfigSpec.BooleanValue SLEEPLESS_ENABLED = BUILDER
            .comment("Whether the Sleepless can appear for players who have not slept for 3+ nights.")
            .define("sleeplessEnabled", true);
    public static final ForgeConfigSpec.BooleanValue BOSS_ARENA_GRIEFING = BUILDER
            .comment("Whether the Deep Mother's arena collapses (blocks fall from the ceiling). Also respects the mobGriefing gamerule.")
            .define("bossArenaGriefing", true);
    public static final ForgeConfigSpec.BooleanValue WHISPER_CHAT = BUILDER
            .comment("Whether whispers with player names are written into chat.")
            .define("whisperChat", true);

    static {
        BUILDER.pop();
    }

    public static final ForgeConfigSpec SPEC = BUILDER.build();
}
