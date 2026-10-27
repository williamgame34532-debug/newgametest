package com.williamgame.modcritic.client;

import com.williamgame.modcritic.ModCritic;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.screens.PauseScreen;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.gui.screens.TitleScreen;
import net.minecraft.client.gui.components.Tooltip;
import net.minecraft.network.chat.Component;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.ClientPlayerNetworkEvent;
import net.minecraftforge.client.event.ScreenEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = ModCritic.MODID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
public class ClientForgeEvents {
    @SubscribeEvent
    public static void tick(TickEvent.ClientTickEvent.Post event) {
        Minecraft mc = Minecraft.getInstance();
        while (ClientModEvents.OPEN.consumeClick()) {
            if (mc.screen == null) ClientHooks.openRating(null);
        }
    }

    /** Adds the "Mod Critic" button to the title screen and the pause menu (top-left corner). */
    @SubscribeEvent
    public static void screenInit(ScreenEvent.Init.Post event) {
        Screen screen = event.getScreen();
        boolean title = screen instanceof TitleScreen;
        boolean pause = screen instanceof PauseScreen ps && ps.showsPauseMenu();
        if (!title && !pause) return;
        FancyButton b = new FancyButton(6, 6, 108, 20, Component.translatable("modcritic.button.open"), Ui.GOLD,
                btn -> ClientHooks.openRating(screen));
        b.setTooltip(Tooltip.create(Component.translatable("modcritic.button.open.tooltip")));
        event.addListener(b);
    }

    @SubscribeEvent
    public static void loggingOut(ClientPlayerNetworkEvent.LoggingOut event) {
        ClientHooks.clearServerData();
    }
}
