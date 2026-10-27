package com.williamgame.hideandhunt.client;

import com.mojang.blaze3d.platform.InputConstants;
import com.williamgame.hideandhunt.HideAndHunt;
import net.minecraft.client.DeltaTracker;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.AddGuiOverlayLayersEvent;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import org.lwjgl.glfw.GLFW;

@Mod.EventBusSubscriber(modid = HideAndHunt.MODID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public final class ClientModEvents {
    private ClientModEvents() {}

    public static final KeyMapping TAUNT = new KeyMapping("key.hideandhunt.taunt", InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_G, "key.categories.hideandhunt");
    public static final KeyMapping RESULTS = new KeyMapping("key.hideandhunt.results", InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_UNKNOWN, "key.categories.hideandhunt");

    @SubscribeEvent
    public static void keys(RegisterKeyMappingsEvent event) {
        event.register(TAUNT);
        event.register(RESULTS);
    }

    @SubscribeEvent
    public static void hud(AddGuiOverlayLayersEvent event) {
        event.getLayeredDraw().add(HideAndHunt.id("hud"), (GuiGraphics g, DeltaTracker delta) -> {
            float pt = delta.getGameTimeDeltaPartialTick(true);
            HudOverlay.render(g, pt);
            RandomizerOverlay.render(g, pt);
        });
    }
}
