package com.williamgame.apiprobe.client;

import com.mojang.blaze3d.systems.RenderSystem;
import com.williamgame.apiprobe.ApiProbe;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.InputEvent;
import net.minecraftforge.client.event.RenderGuiEvent;
import net.minecraftforge.client.event.ViewportEvent;
import net.minecraftforge.client.event.RenderLevelStageEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = ApiProbe.MODID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
public class ClientForgeEvents {
    @SubscribeEvent
    public static void hud(RenderGuiEvent.Post event) {
        GuiGraphics g = event.getGuiGraphics();
        Minecraft mc = Minecraft.getInstance();
        g.drawString(mc.font, "probe " + ClientHooks.value, 4, 4, 0xFFFFFF);
        int w = g.guiWidth();
        int h = g.guiHeight();
        g.fillGradient(0, 0, w, h / 4, 0x66000000, 0x00000000);
    }

    @SubscribeEvent
    public static void fogColor(ViewportEvent.ComputeFogColor event) {
        event.setRed(event.getRed() * 0.6F);
    }

    @SubscribeEvent
    public static void fog(ViewportEvent.RenderFog event) {
        event.setNearPlaneDistance(event.getNearPlaneDistance() * 0.5F);
        event.setFarPlaneDistance(event.getFarPlaneDistance() * 0.5F);
        event.setCanceled(true);
    }

    @SubscribeEvent
    public static void camera(ViewportEvent.ComputeCameraAngles event) {
        event.setRoll(event.getRoll() + 0.5F);
    }

    @SubscribeEvent
    public static void fov(ViewportEvent.ComputeFov event) {
        event.setFOV(event.getFOV() * 1.01);
    }

    @SubscribeEvent
    public static void levelStage(RenderLevelStageEvent event) {
        if (event.getStage() == RenderLevelStageEvent.Stage.AFTER_PARTICLES) {
            event.getPoseStack();
        }
    }

    @SubscribeEvent
    public static void key(InputEvent.Key event) {
        while (ClientModEvents.OPEN.consumeClick()) {
            Minecraft.getInstance().setScreen(new ProbeScreen());
        }
    }

    @SubscribeEvent
    public static void tick(TickEvent.ClientTickEvent.Post event) {
    }
}
