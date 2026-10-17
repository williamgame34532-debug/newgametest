package com.zone19.scp.config;

import net.minecraftforge.common.ForgeConfigSpec;
import org.apache.commons.lang3.tuple.Pair;

public final class Zone19Config {
    public static final Common COMMON;
    public static final ForgeConfigSpec COMMON_SPEC;
    public static final Client CLIENT;
    public static final ForgeConfigSpec CLIENT_SPEC;

    static {
        Pair<Common, ForgeConfigSpec> c = new ForgeConfigSpec.Builder().configure(Common::new);
        COMMON = c.getLeft();
        COMMON_SPEC = c.getRight();
        Pair<Client, ForgeConfigSpec> cl = new ForgeConfigSpec.Builder().configure(Client::new);
        CLIENT = cl.getLeft();
        CLIENT_SPEC = cl.getRight();
    }

    public static final class Common {
        public final ForgeConfigSpec.BooleanValue autoEnterZone;
        public final ForgeConfigSpec.BooleanValue adventureInZone;
        public final ForgeConfigSpec.BooleanValue keepInventoryInZone;
        public final ForgeConfigSpec.BooleanValue blinkEnabled;
        public final ForgeConfigSpec.IntValue blinkInterval;

        Common(ForgeConfigSpec.Builder b) {
            b.push("zone");
            autoEnterZone = b.comment("Teleport every player into Zone-19 the first time they join a world.")
                    .define("autoEnterZone", true);
            adventureInZone = b.comment("Switch survival players to adventure mode inside the facility so the map stays intact.")
                    .define("adventureInZone", true);
            keepInventoryInZone = b.comment("Players keep their keycards and weapons when they die inside the facility.")
                    .define("keepInventoryInZone", true);
            b.pop();
            b.push("blink");
            blinkEnabled = b.comment("SCP:CB style blinking inside the facility (SCP-173 moves while you blink).")
                    .define("enabled", true);
            blinkInterval = b.comment("Ticks between blinks.").defineInRange("interval", 200, 60, 1200);
            b.pop();
        }
    }

    public static final class Client {
        public final ForgeConfigSpec.BooleanValue customTitleScreen;
        public final ForgeConfigSpec.BooleanValue showUpdatesPopup;
        public final ForgeConfigSpec.ConfigValue<String> lastSeenUpdate;
        public final ForgeConfigSpec.ConfigValue<String> selectedSkin;
        public final ForgeConfigSpec.BooleanValue ambientSounds;

        Client(ForgeConfigSpec.Builder b) {
            customTitleScreen = b.comment("Replace the vanilla title screen with the Zone-19 terminal.")
                    .define("customTitleScreen", true);
            showUpdatesPopup = b.comment("Show the 'what's new' window once per mod version.")
                    .define("showUpdatesPopup", true);
            lastSeenUpdate = b.define("lastSeenUpdate", "");
            selectedSkin = b.comment("Personnel skin: default, guard_standard, guard_senior, guard_heavy, guard_night, mtf_e11, class_d, scientist")
                    .define("selectedSkin", "guard_standard");
            ambientSounds = b.define("ambientSounds", true);
        }
    }

    private Zone19Config() {
    }
}
