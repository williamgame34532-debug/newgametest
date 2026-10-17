package com.zone19.scp.world;

import com.zone19.scp.Zone19Mod;
import net.minecraft.resources.ResourceLocation;
import org.jetbrains.annotations.Nullable;

/** Personnel skins. DEFAULT means "keep my own Minecraft skin". */
public enum GuardSkin {
    DEFAULT("default"),
    GUARD_STANDARD("guard_standard"),
    GUARD_SENIOR("guard_senior"),
    GUARD_HEAVY("guard_heavy"),
    GUARD_NIGHT("guard_night"),
    MTF_E11("mtf_e11"),
    SCIENTIST("scientist"),
    CLASS_D("class_d");

    private final String id;
    private final ResourceLocation texture;

    GuardSkin(String id) {
        this.id = id;
        this.texture = Zone19Mod.id("textures/entity/skins/" + id + ".png");
    }

    public String id() {
        return id;
    }

    public ResourceLocation texture() {
        return texture;
    }

    public String nameKey() {
        return "skin.scpzone19." + id;
    }

    public String descKey() {
        return "skin.scpzone19." + id + ".desc";
    }

    @Nullable
    public static GuardSkin byId(String id) {
        for (GuardSkin s : values()) {
            if (s.id.equals(id)) return s;
        }
        return null;
    }
}
