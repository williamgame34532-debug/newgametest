package com.williamgame.blockmemory.client;

import com.mojang.blaze3d.platform.InputConstants;
import com.williamgame.blockmemory.BlockMemory;
import com.williamgame.blockmemory.ModRegistry;
import com.williamgame.blockmemory.item.MemoryBrushItem;
import net.minecraft.client.DeltaTracker;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.network.chat.Component;
import net.minecraft.util.Mth;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.AddGuiOverlayLayersEvent;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import org.lwjgl.glfw.GLFW;

@Mod.EventBusSubscriber(modid = BlockMemory.MODID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public class ClientModEvents {
    public static final KeyMapping OPEN_CODEX = new KeyMapping("key.blockmemory.codex", InputConstants.Type.KEYSYM,
            GLFW.GLFW_KEY_B, "key.categories.blockmemory");

    @SubscribeEvent
    public static void keys(RegisterKeyMappingsEvent event) {
        event.register(OPEN_CODEX);
    }

    @SubscribeEvent
    public static void hud(AddGuiOverlayLayersEvent event) {
        event.getLayeredDraw().add(BlockMemory.id("brush_charge"), (GuiGraphics g, DeltaTracker delta) -> {
            Minecraft mc = Minecraft.getInstance();
            if (mc.player == null || mc.options.hideGui || !mc.player.isUsingItem()) return;
            if (!mc.player.getUseItem().is(ModRegistry.MEMORY_BRUSH.get())) return;
            float used = mc.player.getTicksUsingItem() + delta.getGameTimeDeltaPartialTick(true);
            int cx = g.guiWidth() / 2;
            int y = g.guiHeight() / 2 + 12;
            int w = 50;
            float p = Mth.clamp(used / MemoryBrushItem.REPLAY_TICKS, 0F, 1F);
            g.fill(cx - w / 2 - 1, y - 1, cx + w / 2 + 1, y + 4, 0xAA0B0F1A);
            int fillW = (int) (w * p);
            int col = p >= 1F ? 0xFFF2D27A : 0xFF6FD3E8;
            g.fillGradient(cx - w / 2, y, cx - w / 2 + fillW, y + 3, col, (col & 0x00FFFFFF) | 0x99000000);
            Component label = Component.translatable(p >= 1F ? "blockmemory.hud.replay" : "blockmemory.hud.reading");
            int glow = p >= 1F ? (int) (180 + 75 * Mth.sin(used * 0.4F)) : 200;
            g.drawCenteredString(mc.font, label, cx, y + 7, (Mth.clamp(glow, 0, 255) << 24) | (p >= 1F ? 0xF2D27A : 0xA9E8F2));
        });
    }
}
