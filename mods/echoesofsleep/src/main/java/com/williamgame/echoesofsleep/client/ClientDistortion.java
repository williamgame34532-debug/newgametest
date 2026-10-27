package com.williamgame.echoesofsleep.client;

import com.williamgame.echoesofsleep.Config;
import com.williamgame.echoesofsleep.distortion.DistortionData;
import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.phys.Vec3;

/** Client copy of the Distortion of the current dimension plus all short-lived scare effects. */
public final class ClientDistortion {
    public static int level;
    public static int ticksLeft;
    public static int totalTicks;
    public static long clientTicks;

    public static int flashTicks, flashMax;
    public static int flashColor = 0xFFFFFF;
    public static int glitchTicks;
    /** Client tick range [blackStart, blackEnd) during which one or two black "skipped" frames are shown. */
    public static long blackStart, blackEnd;
    public static int wrongNumberTicks;
    public static float shake;
    private static int heartbeats;
    private static int heartbeatDelay;
    private static int footsteps;
    private static int footstepDelay;
    private static float footstepAngle;
    private static int droneCooldown = 100;

    private ClientDistortion() {
    }

    public static float strength() {
        return Config.VISUAL_STRENGTH.get().floatValue();
    }

    /** 0..1 intensity of the current Distortion (fade in / out), times the user's visual strength. */
    public static boolean reduceFlashing() {
        return com.williamgame.echoesofsleep.ClientConfig.REDUCE_FLASHING.get();
    }

    /** Starts a glitch: N ticks of torn bands, with at most 1-2 black frames picked per client tick (never per render frame). */
    static void startGlitch(int ticks, RandomSource r) {
        glitchTicks = Math.max(glitchTicks, ticks);
        blackStart = clientTicks + 1 + r.nextInt(Math.max(1, ticks - 2));
        blackEnd = blackStart + 1 + r.nextInt(2);
    }

    public static boolean blackFrameNow() {
        return glitchTicks > 0 && clientTicks >= blackStart && clientTicks < blackEnd && !reduceFlashing();
    }

    public static float intensity() {
        return DistortionData.intensity(level, ticksLeft, totalTicks) * strength();
    }

    public static void reset() {
        level = ticksLeft = totalTicks = 0;
        flashTicks = glitchTicks = wrongNumberTicks = heartbeats = footsteps = 0;
        shake = 0;
    }

    static void tick(Minecraft mc) {
        clientTicks++;
        if (ticksLeft > 0) ticksLeft--;
        if (flashTicks > 0) flashTicks--;
        if (glitchTicks > 0) glitchTicks--;
        if (wrongNumberTicks > 0) wrongNumberTicks--;
        shake *= 0.9F;
        LocalPlayer player = mc.player;
        if (player == null) return;
        RandomSource r = player.getRandom();

        if (heartbeats > 0 && --heartbeatDelay <= 0) {
            heartbeats--;
            heartbeatDelay = 16;
            play(player, ModSounds.HEARTBEAT.get(), player.position(), 0.9F, 1.0F);
        }
        if (footsteps > 0 && --footstepDelay <= 0) {
            footsteps--;
            footstepDelay = 7 + r.nextInt(3);
            float dist = 3.0F + footsteps * 0.6F;
            Vec3 behind = behind(player, dist, footstepAngle);
            play(player, ModSounds.FOOTSTEPS.get(), behind, 0.6F, 0.9F + r.nextFloat() * 0.15F);
        }

        float k = intensity();
        if (k <= 0.01F) return;
        // ambient dread
        if (level >= 2 && --droneCooldown <= 0) {
            droneCooldown = 300 + r.nextInt(400);
            play(player, ModSounds.DRONE.get(), player.position().add(0, 2, 0), 0.35F * k, 0.8F + r.nextFloat() * 0.2F);
        }
        if (r.nextInt(level >= 3 ? 700 : 1600) == 0) {
            whisperBehind(player, 0.6F * k);
        }
        if (level >= 3 && r.nextInt(1200) == 0) {
            startGlitch(3 + r.nextInt(4), r);
        }
        if (level >= 3 && r.nextInt(1500) == 0) {
            heartbeats = 4;
        }
    }

    static Vec3 behind(LocalPlayer player, float dist, float angleOffset) {
        float yaw = (player.getYRot() + 180.0F + angleOffset) * Mth.DEG_TO_RAD;
        return player.position().add(-Mth.sin(yaw) * dist, 0.1, Mth.cos(yaw) * dist);
    }

    static void play(LocalPlayer player, SoundEvent sound, Vec3 at, float volume, float pitch) {
        player.level().playLocalSound(at.x, at.y, at.z, sound, SoundSource.AMBIENT, volume, pitch, false);
    }

    static void whisperBehind(LocalPlayer player, float volume) {
        RandomSource r = player.getRandom();
        Vec3 pos = behind(player, 1.5F, (r.nextFloat() - 0.5F) * 70.0F).add(0, 1.5, 0);
        play(player, ModSounds.WHISPER.get(), pos, Math.max(0.3F, volume), 0.8F + r.nextFloat() * 0.3F);
    }

    // ---- triggered by FxPacket --------------------------------------------------------------
    static void wakeUp(LocalPlayer player, float strength) {
        flashTicks = flashMax = 50;
        flashColor = 0xFFFFFF;
        shake = 0.6F + strength;
        heartbeats = 5;
        heartbeatDelay = 20;
        play(player, ModSounds.WAKE_SCREAM.get(), player.position().add(0, 1, 0), 0.7F + strength * 0.3F, 0.9F);
        wrongNumberTicks = 40;
    }

    static void footsteps(LocalPlayer player) {
        footsteps = 5 + player.getRandom().nextInt(4);
        footstepDelay = 10;
        footstepAngle = (player.getRandom().nextFloat() - 0.5F) * 40.0F;
    }

    static void glitch(LocalPlayer player, float strength) {
        startGlitch(5 + (int) (strength * 6), player.getRandom());
        wrongNumberTicks = 70;
        shake = Math.max(shake, 0.4F * strength);
        play(player, ModSounds.GLITCH.get(), player.position().add(0, 1, 0), 0.6F, 0.8F + player.getRandom().nextFloat() * 0.4F);
    }

    static void heartbeat(float strength) {
        heartbeats = Math.max(heartbeats, 1 + (int) (strength * 3));
        heartbeatDelay = 0;
    }

    static void pulse(float strength) {
        shake = Math.max(shake, 1.2F * strength);
        flashTicks = flashMax = 10;
        flashColor = 0x6A1B9A;
        glitchTicks = Math.max(glitchTicks, 3);
    }
}
