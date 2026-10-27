package com.williamgame.modcritic;

import com.williamgame.modcritic.network.CriticNetwork;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;
import org.slf4j.Logger;
import com.mojang.logging.LogUtils;

/**
 * Mod Critic: rate installed mods by eight criteria, rank and compare them,
 * optionally aggregate ratings of every player on a server.
 */
@Mod(ModCritic.MODID)
public class ModCritic {
    public static final String MODID = "modcritic";
    public static final Logger LOGGER = LogUtils.getLogger();

    /** The four mods of the pack, pinned to the top of every list (in this order). */
    public static final String[] PINNED = {"echoesofsleep", "hideandhunt", "blockmemory", "symbiont"};

    public static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(MODID, path);
    }

    public static int pinIndex(String modId) {
        for (int i = 0; i < PINNED.length; i++) {
            if (PINNED[i].equals(modId)) return i;
        }
        return -1;
    }

    public ModCritic(FMLJavaModLoadingContext context) {
        CriticNetwork.register();
        MinecraftForge.EVENT_BUS.register(CriticServerEvents.class);
    }
}
