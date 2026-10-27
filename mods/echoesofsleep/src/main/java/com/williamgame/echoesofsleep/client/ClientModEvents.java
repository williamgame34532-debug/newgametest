package com.williamgame.echoesofsleep.client;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.client.model.*;
import com.williamgame.echoesofsleep.client.renderer.*;
import com.williamgame.echoesofsleep.entity.HollowVillager;
import com.williamgame.echoesofsleep.entity.Sleepless;
import com.williamgame.echoesofsleep.entity.Stitcher;
import com.williamgame.echoesofsleep.registry.ModEntities;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.AddGuiOverlayLayersEvent;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = EchoesOfSleep.MODID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public final class ClientModEvents {
    private ClientModEvents() {
    }

    @SubscribeEvent
    public static void layers(EntityRenderersEvent.RegisterLayerDefinitions event) {
        event.registerLayerDefinition(DoppelgangerModel.LAYER, DoppelgangerModel::createLayer);
        event.registerLayerDefinition(StitcherModel.LAYER, StitcherModel::createLayer);
        event.registerLayerDefinition(SleeplessModel.LAYER, SleeplessModel::createLayer);
        event.registerLayerDefinition(HollowVillagerModel.LAYER, HollowVillagerModel::createLayer);
        event.registerLayerDefinition(DeepMotherModel.LAYER, DeepMotherModel::createLayer);
        event.registerLayerDefinition(MotherHandModel.LAYER, MotherHandModel::createLayer);
        event.registerLayerDefinition(DreamerModel.LAYER, DreamerModel::createLayer);
    }

    @SubscribeEvent
    public static void renderers(EntityRenderersEvent.RegisterRenderers event) {
        event.registerEntityRenderer(ModEntities.ECHO_DOPPELGANGER.get(), DoppelgangerRenderer::new);
        event.registerEntityRenderer(ModEntities.STITCHER.get(),
                ctx -> new NightmareRenderer<Stitcher, StitcherModel>(ctx, new StitcherModel(ctx.bakeLayer(StitcherModel.LAYER)), 0.8F, "stitcher"));
        event.registerEntityRenderer(ModEntities.SLEEPLESS.get(),
                ctx -> new NightmareRenderer<Sleepless, SleeplessModel>(ctx, new SleeplessModel(ctx.bakeLayer(SleeplessModel.LAYER)), 0.4F, "sleepless"));
        event.registerEntityRenderer(ModEntities.HOLLOW_VILLAGER.get(),
                ctx -> new NightmareRenderer<HollowVillager, HollowVillagerModel>(ctx, new HollowVillagerModel(ctx.bakeLayer(HollowVillagerModel.LAYER)), 0.5F, "hollow_villager"));
        event.registerEntityRenderer(ModEntities.DEEP_MOTHER.get(), DeepMotherRenderer::new);
        event.registerEntityRenderer(ModEntities.MOTHER_HAND.get(), MotherHandRenderer::new);
        event.registerEntityRenderer(ModEntities.THE_DREAMER.get(), DreamerRenderer::new);
        event.registerEntityRenderer(ModEntities.REALITY_FRAGMENT.get(), RealityFragmentRenderer::new);
    }

    @SubscribeEvent
    public static void hud(AddGuiOverlayLayersEvent event) {
        event.getLayeredDraw().add(EchoesOfSleep.id("distortion"), DistortionOverlay::render);
    }
}
