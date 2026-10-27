package com.williamgame.hideandhunt.client;

import com.williamgame.hideandhunt.HideAndHunt;
import com.williamgame.hideandhunt.network.HHNetwork;
import com.williamgame.hideandhunt.network.TauntPacket;
import net.minecraft.client.Minecraft;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.ClientPlayerNetworkEvent;
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
    }

    @SubscribeEvent
    public static void loggingOut(ClientPlayerNetworkEvent.LoggingOut event) {
        ClientState.reset();
        RandomizerOverlay.stop();
    }
}
