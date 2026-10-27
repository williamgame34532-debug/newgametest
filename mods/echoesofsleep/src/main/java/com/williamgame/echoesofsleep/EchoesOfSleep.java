package com.williamgame.echoesofsleep;

import com.williamgame.echoesofsleep.event.CommonEvents;
import com.williamgame.echoesofsleep.event.EchoesCommands;
import com.williamgame.echoesofsleep.event.GearEvents;
import com.williamgame.echoesofsleep.distortion.DistortionManager;
import com.williamgame.echoesofsleep.network.ModNetwork;
import com.williamgame.echoesofsleep.registry.*;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.config.ModConfig;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;

@Mod(EchoesOfSleep.MODID)
public class EchoesOfSleep {
    public static final String MODID = "echoesofsleep";

    public static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(MODID, path);
    }

    public EchoesOfSleep(FMLJavaModLoadingContext context) {
        IEventBus modBus = context.getModEventBus();
        ModBlocks.BLOCKS.register(modBus);
        ModItems.ITEMS.register(modBus);
        ModEntities.ENTITIES.register(modBus);
        ModSounds.SOUNDS.register(modBus);
        ModTabs.TABS.register(modBus);
        modBus.addListener(ModEntities::attributes);
        context.registerConfig(ModConfig.Type.COMMON, Config.SPEC);
        context.registerConfig(ModConfig.Type.CLIENT, ClientConfig.SPEC);
        ModNetwork.register();
        MinecraftForge.EVENT_BUS.register(CommonEvents.class);
        MinecraftForge.EVENT_BUS.register(GearEvents.class);
        MinecraftForge.EVENT_BUS.register(DistortionManager.class);
        MinecraftForge.EVENT_BUS.register(EchoesCommands.class);
    }
}
