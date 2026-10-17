package com.zone19.scp;

import com.mojang.logging.LogUtils;
import com.zone19.scp.config.Zone19Config;
import com.zone19.scp.network.Net;
import com.zone19.scp.registry.ModBlocks;
import com.zone19.scp.registry.ModEntities;
import com.zone19.scp.registry.ModItems;
import com.zone19.scp.registry.ModSounds;
import com.zone19.scp.registry.ModTabs;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.ModLoadingContext;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.config.ModConfig;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;
import org.slf4j.Logger;

@Mod(Zone19Mod.MODID)
public class Zone19Mod {
    public static final String MODID = "scpzone19";
    public static final String VERSION = "1.0.0";
    public static final Logger LOGGER = LogUtils.getLogger();

    public Zone19Mod() {
        IEventBus bus = FMLJavaModLoadingContext.get().getModEventBus();
        ModBlocks.BLOCKS.register(bus);
        ModItems.ITEMS.register(bus);
        ModEntities.ENTITIES.register(bus);
        ModSounds.SOUNDS.register(bus);
        ModTabs.TABS.register(bus);
        bus.addListener(ModEntities::onAttributes);

        ModLoadingContext.get().registerConfig(ModConfig.Type.COMMON, Zone19Config.COMMON_SPEC);
        ModLoadingContext.get().registerConfig(ModConfig.Type.CLIENT, Zone19Config.CLIENT_SPEC);
        Net.register();
    }

    public static ResourceLocation id(String path) {
        return new ResourceLocation(MODID, path);
    }
}
