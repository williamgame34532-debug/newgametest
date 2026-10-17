package com.zone19.scp.client;

import com.zone19.scp.Zone19Mod;
import com.zone19.scp.client.render.GuardSkinRenderer;
import com.zone19.scp.client.render.Scp0492Renderer;
import com.zone19.scp.client.render.Scp096Renderer;
import com.zone19.scp.client.render.Scp106Renderer;
import com.zone19.scp.client.render.Scp173Model;
import com.zone19.scp.client.render.Scp173Renderer;
import com.zone19.scp.registry.ModEntities;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.world.entity.monster.Zombie;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.client.event.RegisterGuiOverlaysEvent;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = Zone19Mod.MODID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public final class ClientSetup {
    @SubscribeEvent
    public static void onRegisterRenderers(EntityRenderersEvent.RegisterRenderers event) {
        event.registerEntityRenderer(ModEntities.SCP173.get(), Scp173Renderer::new);
        event.registerEntityRenderer(ModEntities.SCP096.get(), Scp096Renderer::new);
        event.registerEntityRenderer(ModEntities.SCP106.get(), Scp106Renderer::new);
        EntityRendererProvider<Zombie> zombie = Scp0492Renderer::new;
        event.registerEntityRenderer(ModEntities.SCP049_2.get(), zombie);
    }

    @SubscribeEvent
    public static void onLayers(EntityRenderersEvent.RegisterLayerDefinitions event) {
        event.registerLayerDefinition(Scp173Model.LAYER, Scp173Model::createBodyLayer);
    }

    @SubscribeEvent
    public static void onAddLayers(EntityRenderersEvent.AddLayers event) {
        GuardSkinRenderer.init(event.getContext());
    }

    @SubscribeEvent
    public static void onKeys(RegisterKeyMappingsEvent event) {
        event.register(Keys.TERMINAL);
        event.register(Keys.BLINK);
    }

    @SubscribeEvent
    public static void onOverlays(RegisterGuiOverlaysEvent event) {
        event.registerAboveAll("zone19_hud", HudOverlay::render);
    }

    private ClientSetup() {
    }
}
