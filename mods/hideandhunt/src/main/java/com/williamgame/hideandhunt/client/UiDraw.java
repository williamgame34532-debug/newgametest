package com.williamgame.hideandhunt.client;

import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.network.chat.Component;

/** Shared drawing helpers for the HUD and screens. */
public final class UiDraw {
    private UiDraw() {}

    public static int withAlpha(int argb, float alpha) {
        int a = Math.max(0, Math.min(255, (int) (((argb >>> 24) & 0xFF) * alpha)));
        return (a << 24) | (argb & 0xFFFFFF);
    }

    public static int darker(int argb, float f) {
        int r = (int) (((argb >> 16) & 0xFF) * f), gg = (int) (((argb >> 8) & 0xFF) * f), b = (int) ((argb & 0xFF) * f);
        return (argb & 0xFF000000) | (r << 16) | (gg << 8) | b;
    }

    /** Rounded-looking dark glass panel with a coloured accent line on top. */
    public static void panel(GuiGraphics g, int x, int y, int w, int h, int accent, float alpha) {
        int bg = withAlpha(0xD0101018, alpha);
        int border = withAlpha(0xFF3A3A50, alpha);
        g.fill(x + 1, y, x + w - 1, y + h, bg);
        g.fill(x, y + 1, x + 1, y + h - 1, bg);
        g.fill(x + w - 1, y + 1, x + w, y + h - 1, bg);
        // border
        g.fill(x + 1, y - 1, x + w - 1, y, border);
        g.fill(x + 1, y + h, x + w - 1, y + h + 1, border);
        g.fill(x - 1, y + 1, x, y + h - 1, border);
        g.fill(x + w, y + 1, x + w + 1, y + h - 1, border);
        // accent
        g.fill(x + 1, y, x + w - 1, y + 2, withAlpha(accent, alpha));
        g.fillGradient(x + 1, y + 2, x + w - 1, y + 10, withAlpha(accent & 0x40FFFFFF, alpha), 0x00000000);
    }

    public static void bar(GuiGraphics g, int x, int y, int w, int h, float frac, int color) {
        frac = Math.max(0F, Math.min(1F, frac));
        g.fill(x, y, x + w, y + h, 0xFF202028);
        int fw = (int) (w * frac);
        if (fw > 0) {
            g.fillGradient(x, y, x + fw, y + h, color, darker(color, 0.6F));
            g.fill(x, y, x + fw, y + 1, withAlpha(0xFFFFFFFF, 0.35F));
        }
    }

    public static void badge(GuiGraphics g, Font font, Component text, int x, int y, int color) {
        int w = font.width(text) + 8;
        g.fill(x, y, x + w, y + 11, darker(color, 0.35F) | 0xFF000000);
        g.fill(x, y, x + w, y + 1, color);
        g.drawString(font, text, x + 4, y + 2, color, false);
    }

    public static String clock(int seconds) {
        seconds = Math.max(0, seconds);
        return String.format(java.util.Locale.ROOT, "%d:%02d", seconds / 60, seconds % 60);
    }

    public static void scaledCentered(GuiGraphics g, Font font, Component text, int cx, int y, float scale, int color) {
        g.pose().pushPose();
        g.pose().translate(cx, y, 0);
        g.pose().scale(scale, scale, 1F);
        g.drawString(font, text, -font.width(text) / 2, 0, color, true);
        g.pose().popPose();
    }
}
