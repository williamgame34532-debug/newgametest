package com.williamgame.blockmemory;

import com.williamgame.blockmemory.network.ModNetwork;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.config.ModConfig;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;

@Mod(BlockMemory.MODID)
public class BlockMemory {
    public static final String MODID = "blockmemory";

    public static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(MODID, path);
    }

    public BlockMemory(FMLJavaModLoadingContext context) {
        IEventBus modBus = context.getModEventBus();
        ModRegistry.register(modBus);
        context.registerConfig(ModConfig.Type.COMMON, MemoryConfig.SPEC);
        ModNetwork.register();
        MinecraftForge.EVENT_BUS.register(CommonEvents.class);
    }
}
