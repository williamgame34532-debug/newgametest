package com.williamgame.hideandhunt.client;

import com.williamgame.hideandhunt.HideAndHunt;
import com.williamgame.hideandhunt.network.HHNetwork;
import com.williamgame.hideandhunt.network.TauntPacket;
import net.minecraft.client.Minecraft;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.ClientPlayerNetworkEvent;
import net.minecraftforge.client.event.CustomizeGuiOverlayEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = HideAndHunt.MODID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
public final class ClientForgeEvents {
    private ClientForgeEvents() {}

    @SubscribeEvent
    public static void tick(TickEvent.ClientTickEvent.Post event) {
        ClientState.ticks++;
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null) return;
        while (ClientModEvents.TAUNT.consumeClick()) {
            HHNetwork.sendToServer(new TauntPacket(0));
        }
        while (ClientModEvents.RESULTS.consumeClick()) {
            if (ClientState.lastResults != null) mc.setScreen(new ResultsScreen(ClientState.lastResults));
        }
        RandomizerOverlay.tick();
        if (ClientState.resultsOpenAt > 0 && ClientState.ticks >= ClientState.resultsOpenAt) {
            ClientState.resultsOpenAt = 0;
            // never yank a screen the player is using (chat, inventory...): the server sent a clickable chat line
            if (mc.screen == null && ClientState.lastResults != null) mc.setScreen(new ResultsScreen(ClientState.lastResults));
        }
        if (ClientState.bossBottomAccum > 0) {
            ClientState.bossBottom = ClientState.bossBottomAccum;
            ClientState.bossSeenTick = ClientState.ticks;
        } else if (ClientState.ticks - ClientState.bossSeenTick > 10) {
            ClientState.bossBottom = 0; // no boss bar rendered for half a second
        }
        ClientState.bossBottomAccum = 0;
    }

    @SubscribeEvent
    public static void bossBar(CustomizeGuiOverlayEvent.BossEventProgress event) {
        ClientState.bossBottomAccum = Math.max(ClientState.bossBottomAccum, event.getY() + event.getIncrement());
    }

    @SubscribeEvent
    public static void loggingOut(ClientPlayerNetworkEvent.LoggingOut event) {
        ClientState.reset();
        RandomizerOverlay.stop();
    }
}
