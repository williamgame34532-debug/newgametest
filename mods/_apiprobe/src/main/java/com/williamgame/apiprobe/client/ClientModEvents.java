package com.williamgame.apiprobe.client;

import com.mojang.blaze3d.platform.InputConstants;
import com.williamgame.apiprobe.ApiProbe;
import net.minecraft.client.KeyMapping;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.client.event.AddGuiOverlayLayersEvent;
import net.minecraft.client.DeltaTracker;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.event.lifecycle.FMLClientSetupEvent;
import org.lwjgl.glfw.GLFW;

@Mod.EventBusSubscriber(modid = ApiProbe.MODID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public class ClientModEvents {
    public static final KeyMapping OPEN = new KeyMapping("key.apiprobe.open", InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_J, "key.categories.apiprobe");

    @SubscribeEvent
    public static void layers(EntityRenderersEvent.RegisterLayerDefinitions event) {
        event.registerLayerDefinition(ProbeMonsterModel.LAYER, ProbeMonsterModel::createLayer);
    }

    @SubscribeEvent
    public static void renderers(EntityRenderersEvent.RegisterRenderers event) {
        event.registerEntityRenderer(ApiProbe.MONSTER.get(), ProbeMonsterRenderer::new);
    }

    @SubscribeEvent
    public static void keys(RegisterKeyMappingsEvent event) {
        event.register(OPEN);
    }

    @SubscribeEvent
    public static void setup(FMLClientSetupEvent event) {
    }

    // HUD layers: Forge 1.21.1 uses AddGuiOverlayLayersEvent (mod bus), not RenderGuiEvent.
    @SubscribeEvent
    public static void hud(AddGuiOverlayLayersEvent event) {
        event.getLayeredDraw().add(ApiProbe.id("hud"), (GuiGraphics g, DeltaTracker delta) -> {
            Minecraft mc = Minecraft.getInstance();
            if (mc.player == null || mc.options.hideGui) return;
            g.drawString(mc.font, "probe " + ClientHooks.value, 4, 4, 0xFFFFFF);
            int w = g.guiWidth();
            int h = g.guiHeight();
            g.fillGradient(0, 0, w, h / 4, 0x66000000, 0x00000000);
            float pt = delta.getGameTimeDeltaPartialTick(true);
        });
    }
}
