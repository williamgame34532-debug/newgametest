package com.williamgame.hideandhunt;

import com.williamgame.hideandhunt.event.ServerEvents;
import com.williamgame.hideandhunt.network.HHNetwork;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;

@Mod(HideAndHunt.MODID)
public class HideAndHunt {
    public static final String MODID = "hideandhunt";

    public static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(MODID, path);
    }

    public HideAndHunt(FMLJavaModLoadingContext context) {
        IEventBus modBus = context.getModEventBus();
        ModRegistry.register(modBus);
        HHNetwork.register();
        MinecraftForge.EVENT_BUS.register(ServerEvents.class);
    }
}
