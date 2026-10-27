package com.williamgame.hideandhunt.client;

import com.williamgame.hideandhunt.network.RandomizerPacket;
import com.williamgame.hideandhunt.network.ResultsPacket;
import com.williamgame.hideandhunt.network.StatePacket;
import net.minecraft.client.Minecraft;
import net.minecraft.nbt.CompoundTag;

/** Entry points for packets (called only when running on a physical client). */
public final class ClientHooks {
    private ClientHooks() {}

    public static void onState(StatePacket m) {
        ClientState.state = m;
        ClientState.stateTick = ClientState.ticks;
    }

    public static void onRandomizer(RandomizerPacket m) {
        ClientState.randomizer = m;
        ClientState.randomizerStart = ClientState.ticks;
        RandomizerOverlay.begin(m);
    }

    public static void onResults(ResultsPacket m) {
        ClientState.lastResults = m;
        Minecraft mc = Minecraft.getInstance();
        mc.setScreen(new ResultsScreen(m));
    }

    public static void onTabletData(CompoundTag data, boolean open) {
        Minecraft mc = Minecraft.getInstance();
        if (open) {
            mc.setScreen(new TabletScreen(data));
        } else if (mc.screen instanceof TabletScreen ts) {
            ts.updateData(data);
        }
    }
}
