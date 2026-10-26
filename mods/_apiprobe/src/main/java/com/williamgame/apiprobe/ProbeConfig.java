package com.williamgame.apiprobe;

import net.minecraftforge.common.ForgeConfigSpec;

public class ProbeConfig {
    public static final ForgeConfigSpec.Builder BUILDER = new ForgeConfigSpec.Builder();
    public static final ForgeConfigSpec.IntValue STRENGTH = BUILDER.comment("Probe value").defineInRange("strength", 3, 0, 10);
    public static final ForgeConfigSpec SPEC = BUILDER.build();
}
