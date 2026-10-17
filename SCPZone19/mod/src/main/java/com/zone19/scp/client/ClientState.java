package com.zone19.scp.client;

import com.zone19.scp.Zone19Mod;
import com.zone19.scp.world.GuardSkin;
import net.minecraft.client.Minecraft;
import net.minecraft.client.resources.language.I18n;
import net.minecraft.core.BlockPos;
import net.minecraft.util.Mth;
import org.jetbrains.annotations.Nullable;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/** Everything the HUD and the terminal know about the shift, mirrored from the server. */
public final class ClientState {
    public static int chapter, step, progress, required;
    public static String objective = "";
    public static boolean finished;
    @Nullable
    public static BlockPos waypoint;

    public static final Map<UUID, GuardSkin> SKINS = new HashMap<>();

    public static int blinkMeter = -1, blinkMax = 1;
    public static boolean blinking;

    public record Dialogue(String speaker, String key, int total) {
    }

    private static final Deque<Dialogue> QUEUE = new ArrayDeque<>();
    @Nullable
    public static Dialogue dialogue;
    public static int dialogueTicks;

    @Nullable
    public static String titleKey, subtitleKey;
    public static int titleTicks, titleTotal;

    public static void queueDialogue(String speaker, String key, int ticks) {
        int t = ticks > 0 ? ticks : Mth.clamp(60 + I18n.get(key).length() * 2, 90, 340);
        QUEUE.add(new Dialogue(speaker, key, t));
    }

    public static void showTitle(String title, String subtitle, int ticks) {
        titleKey = title;
        subtitleKey = subtitle;
        titleTicks = ticks;
        titleTotal = ticks;
    }

    public static boolean inZone() {
        Minecraft mc = Minecraft.getInstance();
        return mc.player != null && mc.player.level().dimension().location().equals(Zone19Mod.id("zone19"));
    }

    public static void tick() {
        if (dialogue != null && --dialogueTicks <= 0) dialogue = null;
        if (dialogue == null && !QUEUE.isEmpty()) {
            dialogue = QUEUE.poll();
            dialogueTicks = dialogue.total();
            ClientPacketHandler.radioBeep();
        }
        if (titleTicks > 0) titleTicks--;
    }

    public static void reset() {
        chapter = step = progress = required = 0;
        objective = "";
        finished = false;
        waypoint = null;
        SKINS.clear();
        blinkMeter = -1;
        blinking = false;
        QUEUE.clear();
        dialogue = null;
        titleTicks = 0;
    }

    private ClientState() {
    }
}
