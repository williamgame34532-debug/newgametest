package com.williamgame.echoesofsleep;

import net.minecraftforge.common.ForgeConfigSpec;

/** Per-player client settings (echoesofsleep-client.toml). Contains only plain values: safe on servers. */
public class ClientConfig {
    public static final ForgeConfigSpec.Builder BUILDER = new ForgeConfigSpec.Builder();

    public static final ForgeConfigSpec.BooleanValue REDUCE_FLASHING = BUILDER
            .comment("Photosensitivity: no black frame-skip flicker, much softer wake-up and pulse flashes, fainter glitch bands.")
            .define("reduceFlashing", false);

    public static final ForgeConfigSpec SPEC = BUILDER.build();
}
