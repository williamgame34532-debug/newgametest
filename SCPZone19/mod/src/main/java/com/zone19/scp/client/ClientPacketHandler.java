package com.zone19.scp.client;

import com.zone19.scp.client.screen.TerminalScreen;
import com.zone19.scp.network.BlinkPacket;
import com.zone19.scp.network.SkinSyncPacket;
import com.zone19.scp.network.StoryEventPacket;
import com.zone19.scp.network.StorySyncPacket;
import com.zone19.scp.registry.ModSounds;
import com.zone19.scp.world.GuardSkin;
import net.minecraft.client.Minecraft;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.client.resources.sounds.SoundInstance;
import net.minecraft.sounds.SoundEvent;
import org.jetbrains.annotations.Nullable;

import java.util.Map;
import java.util.UUID;

public final class ClientPacketHandler {
    @Nullable
    private static SoundInstance music;

    public static void story(StorySyncPacket m) {
        ClientState.chapter = m.chapter();
        ClientState.step = m.step();
        ClientState.progress = m.progress();
        ClientState.required = m.required();
        ClientState.objective = m.objective();
        ClientState.finished = m.finished();
        ClientState.waypoint = m.waypoint();
    }

    public static void event(StoryEventPacket m) {
        Minecraft mc = Minecraft.getInstance();
        switch (m.type()) {
            case StoryEventPacket.DIALOGUE -> ClientState.queueDialogue(m.a(), m.b(), m.ticks());
            case StoryEventPacket.TITLE -> ClientState.showTitle(m.a(), m.b(), m.ticks());
            case StoryEventPacket.MUSIC -> playMusic(m.a());
            case StoryEventPacket.STOP_MUSIC -> stopMusic();
            case StoryEventPacket.OPEN_TERMINAL -> {
                if (mc.screen == null) mc.setScreen(new TerminalScreen(null));
            }
            case StoryEventPacket.ENDING -> {
                ClientState.showTitle("ending.scpzone19.title", "ending.scpzone19.subtitle", 260);
                playMusic("gateb");
            }
            default -> {
            }
        }
    }

    public static void blink(BlinkPacket m) {
        ClientState.blinkMeter = m.meter();
        ClientState.blinkMax = Math.max(1, m.max());
        ClientState.blinking = m.blinking();
    }

    public static void skins(SkinSyncPacket m) {
        ClientState.SKINS.clear();
        for (Map.Entry<UUID, String> e : m.skins().entrySet()) {
            GuardSkin s = GuardSkin.byId(e.getValue());
            if (s != null && s != GuardSkin.DEFAULT) ClientState.SKINS.put(e.getKey(), s);
        }
    }

    @Nullable
    private static SoundEvent musicEvent(String id) {
        return switch (id) {
            case "intro" -> ModSounds.MUSIC_INTRO.get();
            case "hcz" -> ModSounds.MUSIC_HCZ.get();
            case "chase096" -> ModSounds.MUSIC_CHASE096.get();
            case "scp106" -> ModSounds.MUSIC_106.get();
            case "gateb" -> ModSounds.MUSIC_GATEB.get();
            default -> null;
        };
    }

    public static void playMusic(String id) {
        SoundEvent event = musicEvent(id);
        if (event == null) return;
        Minecraft mc = Minecraft.getInstance();
        stopMusic();
        mc.getMusicManager().stopPlaying();
        music = SimpleSoundInstance.forMusic(event);
        mc.getSoundManager().play(music);
    }

    public static void stopMusic() {
        if (music != null) {
            Minecraft.getInstance().getSoundManager().stop(music);
            music = null;
        }
    }

    public static void radioBeep() {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player != null) {
            mc.getSoundManager().play(SimpleSoundInstance.forUI(ModSounds.RADIO_BEEP.get(), 1.0F, 0.5F));
        }
    }

    private ClientPacketHandler() {
    }
}
