package com.williamgame.echoesofsleep.client;

import com.williamgame.echoesofsleep.network.FxPacket;
import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;

/** Entry points for packets; only ever called on the physical client. */
public final class ClientHooks {
    private ClientHooks() {
    }

    public static void onDistortionSync(int level, int ticksLeft, int totalTicks) {
        ClientDistortion.level = level;
        ClientDistortion.ticksLeft = ticksLeft;
        ClientDistortion.totalTicks = totalTicks;
    }

    public static void onFx(int type, float strength) {
        LocalPlayer player = Minecraft.getInstance().player;
        if (player == null) return;
        switch (type) {
            case FxPacket.WAKE_UP -> ClientDistortion.wakeUp(player, strength);
            case FxPacket.WHISPER_BEHIND -> ClientDistortion.whisperBehind(player, 0.5F + strength * 0.5F);
            case FxPacket.FOOTSTEPS -> ClientDistortion.footsteps(player);
            case FxPacket.GLITCH -> ClientDistortion.glitch(player, strength);
            case FxPacket.HEARTBEAT -> ClientDistortion.heartbeat(strength);
            case FxPacket.DREAMER_PULSE -> ClientDistortion.pulse(strength);
            default -> {
            }
        }
    }
}
