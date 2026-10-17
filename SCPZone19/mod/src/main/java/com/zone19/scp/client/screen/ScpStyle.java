package com.zone19.scp.client.screen;

import com.mojang.blaze3d.systems.RenderSystem;
import com.zone19.scp.Zone19Mod;
import net.minecraft.Util;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;

/** Shared look of every Zone-19 screen: black terminal glass, thin frames, Foundation red. */
public final class ScpStyle {
    public static final int RED = 0xFFC42822;
    public static final int RED_DIM = 0xFF6E1A16;
    public static final int AMBER = 0xFFD9A62B;
    public static final int GREEN = 0xFF4FD86A;
    public static final int TEXT = 0xFFE2E2E2;
    public static final int DIM = 0xFF8A8D91;
    public static final int EDGE = 0xFF3C3E42;
    public static final int PANEL = 0xD80B0C0E;

    public static final ResourceLocation LOGO = Zone19Mod.id("textures/gui/logo.png");
    public static final ResourceLocation EMBLEM = Zone19Mod.id("textures/gui/emblem.png");

    public static void scanlines(GuiGraphics g, int w, int h) {
        for (int y = 0; y < h; y += 3) g.fill(0, y, w, y + 1, 0x16000000);
        int sweep = (int) (Util.getMillis() / 12 % (h + 60)) - 60;
        g.fillGradient(0, sweep, w, sweep + 60, 0x00FFFFFF, 0x0CFFFFFF);
    }

    /** Full-screen background for screens opened from the menus. */
    public static void background(GuiGraphics g, int w, int h) {
        g.fill(0, 0, w, h, 0xFF08090A);
        for (int x = 0; x < w; x += 24) g.fill(x, 0, x + 1, h, 0x0AFFFFFF);
        for (int y = 0; y < h; y += 24) g.fill(0, y, w, y + 1, 0x0AFFFFFF);
        emblem(g, w / 2 - 90, h / 2 - 90, 180, 0.05F);
        scanlines(g, w, h);
    }

    public static void emblem(GuiGraphics g, int x, int y, int size, float alpha) {
        RenderSystem.enableBlend();
        g.setColor(1.0F, 1.0F, 1.0F, alpha);
        g.blit(EMBLEM, x, y, size, size, 0, 0, 256, 256, 256, 256);
        g.setColor(1.0F, 1.0F, 1.0F, 1.0F);
        RenderSystem.disableBlend();
    }

    public static void panel(GuiGraphics g, int x, int y, int w, int h) {
        g.fill(x, y, x + w, y + h, PANEL);
        g.renderOutline(x, y, w, h, EDGE);
        g.fill(x, y, x + 10, y + 1, RED);
        g.fill(x, y, x + 1, y + 10, RED);
        g.fill(x + w - 10, y + h - 1, x + w, y + h, RED);
        g.fill(x + w - 1, y + h - 10, x + w, y + h, RED);
    }

    public static void header(GuiGraphics g, Font font, int x, int y, int w, Component text) {
        g.fill(x, y, x + 3, y + 10, RED);
        g.drawString(font, text, x + 7, y + 1, TEXT, false);
        g.fill(x + 10 + font.width(text), y + 5, x + w, y + 6, EDGE);
    }

    private ScpStyle() {
    }
}
