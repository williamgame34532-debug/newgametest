package com.williamgame.modcritic.client;

import com.mojang.blaze3d.platform.InputConstants;
import com.williamgame.modcritic.ModCritic;
import net.minecraft.client.KeyMapping;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import org.lwjgl.glfw.GLFW;

@Mod.EventBusSubscriber(modid = ModCritic.MODID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public class ClientModEvents {
    public static final KeyMapping OPEN = new KeyMapping("key.modcritic.open", InputConstants.Type.KEYSYM,
            GLFW.GLFW_KEY_N, "key.categories.modcritic");

    @SubscribeEvent
    public static void keys(RegisterKeyMappingsEvent event) {
        event.register(OPEN);
    }
}
