package com.williamgame.modcritic.client;

import net.minecraft.Util;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.network.chat.Component;

import java.util.HashMap;
import java.util.Map;

/** Drawing helpers shared by every Mod Critic screen: rounded panels, pixel stars, bars, badges, hover animation. */
public final class Ui {
    // Palette
    public static final int PANEL = 0xD0101018;
    public static final int PANEL_LIGHT = 0xD81A1A28;
    public static final int BORDER = 0xFF3B3B58;
    public static final int BORDER_HI = 0xFF6A6A9A;
    public static final int GOLD = 0xFFFFC94A;
    public static final int GOLD_DARK = 0xFFB07A10;
    public static final int TEXT = 0xFFEDEDF5;
    public static final int TEXT_DIM = 0xFF9A9AB0;
    public static final int TEXT_FAINT = 0xFF66667A;
    public static final int GOOD = 0xFF5BD46E;
    public static final int BAD = 0xFFE85A5A;
    public static final int COMPARE_A = 0xFF45B0EA;
    public static final int COMPARE_B = 0xFFEE963C;

    private Ui() {
    }

    // ---------------------------------------------------------------- colours

    public static int alpha(int color, int a) {
        return (Math.max(0, Math.min(255, a)) << 24) | (color & 0xFFFFFF);
    }

    public static int lerpColor(int a, int b, float t) {
        t = Math.max(0, Math.min(1, t));
        int aa = a >>> 24, ar = (a >> 16) & 255, ag = (a >> 8) & 255, ab = a & 255;
        int ba = b >>> 24, br = (b >> 16) & 255, bg = (b >> 8) & 255, bb = b & 255;
        return ((int) (aa + (ba - aa) * t) << 24) | ((int) (ar + (br - ar) * t) << 16)
                | ((int) (ag + (bg - ag) * t) << 8) | (int) (ab + (bb - ab) * t);
    }

    public static int brighten(int c, float f) {
        return lerpColor(c, 0xFFFFFFFF & (c | 0x00FFFFFF), f);
    }

    public static int darken(int c, float f) {
        return lerpColor(c, c & 0xFF000000, f);
    }

    /** Red -> orange -> yellow -> green for a 1..10 score. */
    public static int scoreColor(double v) {
        float t = (float) ((v - 1) / 9.0);
        if (t < 0.5f) return lerpColor(0xFFE85A5A, 0xFFF2C94C, t * 2);
        return lerpColor(0xFFF2C94C, 0xFF5BD46E, (t - 0.5f) * 2);
    }

    // ---------------------------------------------------------------- shapes

    /** Rectangle with 2px "rounded" (cut) corners. */
    public static void fillRounded(GuiGraphics g, int x, int y, int w, int h, int color) {
        if (w < 4 || h < 4) {
            g.fill(x, y, x + w, y + h, color);
            return;
        }
        g.fill(x + 2, y, x + w - 2, y + 1, color);
        g.fill(x + 1, y + 1, x + w - 1, y + 2, color);
        g.fill(x, y + 2, x + w, y + h - 2, color);
        g.fill(x + 1, y + h - 2, x + w - 1, y + h - 1, color);
        g.fill(x + 2, y + h - 1, x + w - 2, y + h, color);
    }

    /** 1px rounded outline. */
    public static void outlineRounded(GuiGraphics g, int x, int y, int w, int h, int color) {
        g.fill(x + 2, y, x + w - 2, y + 1, color);
        g.fill(x + 2, y + h - 1, x + w - 2, y + h, color);
        g.fill(x, y + 2, x + 1, y + h - 2, color);
        g.fill(x + w - 1, y + 2, x + w, y + h - 2, color);
        g.fill(x + 1, y + 1, x + 2, y + 2, color);
        g.fill(x + w - 2, y + 1, x + w - 1, y + 2, color);
        g.fill(x + 1, y + h - 2, x + 2, y + h - 1, color);
        g.fill(x + w - 2, y + h - 2, x + w - 1, y + h - 1, color);
    }

    /** Dark translucent panel with a soft vertical gradient, a rounded border and a top highlight. */
    public static void panel(GuiGraphics g, int x, int y, int w, int h) {
        panel(g, x, y, w, h, BORDER);
    }

    public static void panel(GuiGraphics g, int x, int y, int w, int h, int border) {
        // drop shadow
        fillRounded(g, x + 2, y + 3, w, h, 0x50000000);
        fillRounded(g, x, y, w, h, PANEL);
        g.fillGradient(x + 1, y + 2, x + w - 1, y + Math.min(h - 2, 24), 0x22FFFFFF, 0x00FFFFFF);
        outlineRounded(g, x, y, w, h, border);
        g.fill(x + 3, y + 1, x + w - 3, y + 2, 0x30FFFFFF);
    }

    /** Horizontal bar: dark track, gradient fill, glossy top line. frac 0..1. */
    public static void bar(GuiGraphics g, int x, int y, int w, int h, float frac, int color) {
        fillRounded(g, x, y, w, h, 0xAA000000);
        outlineRounded(g, x, y, w, h, 0x40FFFFFF);
        int fw = Math.round((w - 2) * Math.max(0, Math.min(1, frac)));
        if (fw > 0) {
            g.fillGradient(x + 1, y + 1, x + 1 + fw, y + h - 1, brighten(color, 0.25f), darken(color, 0.25f));
            g.fill(x + 1, y + 1, x + 1 + fw, y + 2, alpha(0xFFFFFF, 0x70));
        }
    }

    /** Bar growing to the left from (right edge). */
    public static void barLeft(GuiGraphics g, int x, int y, int w, int h, float frac, int color) {
        fillRounded(g, x, y, w, h, 0xAA000000);
        outlineRounded(g, x, y, w, h, 0x40FFFFFF);
        int fw = Math.round((w - 2) * Math.max(0, Math.min(1, frac)));
        if (fw > 0) {
            int r = x + w - 1;
            g.fillGradient(r - fw, y + 1, r, y + h - 1, brighten(color, 0.25f), darken(color, 0.25f));
            g.fill(r - fw, y + 1, r, y + 2, alpha(0xFFFFFF, 0x70));
        }
    }

    // ---------------------------------------------------------------- stars

    private static final String[] STAR = {
            "....#....",
            "...###...",
            "...###...",
            "#########",
            ".#######.",
            "..#####..",
            "..#####..",
            ".###.###.",
            ".##...##.",
    };
    public static final int STAR_SIZE = 9;
    public static final int STAR_STEP = 10;
    public static final int STARS_WIDTH = STAR_STEP * 4 + STAR_SIZE;

    /** One pixel-art star; fill 0..1 (0.5 = left half gold). */
    public static void star(GuiGraphics g, int x, int y, float fill) {
        int goldCols = Math.round(STAR_SIZE * fill);
        for (int row = 0; row < STAR_SIZE; row++) {
            String line = STAR[row];
            int top = lerpColor(0xFFFFF2A8, 0xFFFFB300, row / (float) (STAR_SIZE - 1));
            int col = 0;
            while (col < STAR_SIZE) {
                if (line.charAt(col) != '#') {
                    col++;
                    continue;
                }
                int start = col;
                while (col < STAR_SIZE && line.charAt(col) == '#') col++;
                // shadow
                g.fill(x + start + 1, y + row + 1, x + col + 1, y + row + 2, 0x90000000);
                // grey part / gold part
                int split = Math.max(start, Math.min(col, goldCols));
                if (split > start) g.fill(x + start, y + row, x + split, y + row + 1, top);
                if (col > split) g.fill(x + split, y + row, x + col, y + row + 1, 0xFF4A4A5C);
            }
        }
    }

    /** Five stars for a 0..10 score (each point = half a star). */
    public static void stars(GuiGraphics g, int x, int y, double score) {
        for (int i = 0; i < 5; i++) {
            double left = score - i * 2;
            float fill = left >= 2 ? 1f : left >= 1 ? 0.5f : left > 0 ? (float) (left / 2) : 0f;
            if (fill > 0 && fill < 0.5f) fill = 0.5f;
            if (fill > 0.5f && fill < 1f) fill = left >= 1.5 ? 1f : 0.5f;
            star(g, x + i * STAR_STEP, y, fill);
        }
    }

    // ---------------------------------------------------------------- text

    /** Pill badge, returns its width. */
    public static int badge(GuiGraphics g, Font font, Component text, int x, int y, int color) {
        int w = font.width(text) + 8;
        fillRounded(g, x, y, w, 11, alpha(darken(color, 0.55f), 0xE0));
        outlineRounded(g, x, y, w, 11, color);
        g.drawString(font, text, x + 4, y + 2, brighten(color, 0.55f), false);
        return w;
    }

    public static int badgeWidth(Font font, Component text) {
        return font.width(text) + 8;
    }

    public static void scaledText(GuiGraphics g, Font font, Component text, int x, int y, float scale, int color, boolean shadow) {
        g.pose().pushPose();
        g.pose().translate((float) x, (float) y, 0f);
        g.pose().scale(scale, scale, 1f);
        g.drawString(font, text, 0, 0, color, shadow);
        g.pose().popPose();
    }

    public static void centeredScaled(GuiGraphics g, Font font, Component text, int cx, int y, float scale, int color) {
        int w = Math.round(font.width(text) * scale);
        scaledText(g, font, text, cx - w / 2, y, scale, color, true);
    }

    public static String ellipsize(Font font, String s, int maxWidth) {
        if (font.width(s) <= maxWidth) return s;
        String cut = font.plainSubstrByWidth(s, Math.max(0, maxWidth - font.width("…")));
        return cut + "…";
    }

    public static void scrollbar(GuiGraphics g, int x, int y, int h, int contentH, int viewH, double scroll) {
        if (contentH <= viewH) return;
        g.fill(x, y, x + 3, y + h, 0x60000000);
        int thumb = Math.max(12, (int) (h * (viewH / (double) contentH)));
        int maxScroll = contentH - viewH;
        int ty = y + (int) ((h - thumb) * (scroll / maxScroll));
        g.fill(x, ty, x + 3, ty + thumb, 0xFF8A8AB0);
        g.fill(x, ty, x + 1, ty + thumb, 0xFFC0C0E0);
    }

    public static boolean inside(double mx, double my, int x, int y, int w, int h) {
        return mx >= x && my >= y && mx < x + w && my < y + h;
    }

    /** Word-wrapped multi-line tooltip. */
    public static void tooltip(GuiGraphics g, Font font, java.util.List<Component> lines, int mx, int my, int wrap) {
        java.util.List<net.minecraft.util.FormattedCharSequence> seq = new java.util.ArrayList<>();
        for (Component c : lines) seq.addAll(font.split(c, wrap));
        if (!seq.isEmpty()) g.renderTooltip(font, seq, mx, my);
    }

    // ---------------------------------------------------------------- hover animation

    private static final Map<Object, float[]> ANIM = new HashMap<>();
    private static long lastFrame = Util.getMillis();
    private static float frameDt = 0.016f;

    /** Call once per frame (at the start of render). */
    public static void tickFrame() {
        long now = Util.getMillis();
        frameDt = Math.max(0.001f, Math.min(0.1f, (now - lastFrame) / 1000f));
        lastFrame = now;
    }

    /** Smoothly approaches 1 while active, 0 otherwise (about 120 ms). */
    public static float anim(Object key, boolean active) {
        float[] v = ANIM.computeIfAbsent(key, k -> new float[1]);
        float target = active ? 1f : 0f;
        float k = 1f - (float) Math.exp(-frameDt * 18f);
        v[0] += (target - v[0]) * k;
        if (Math.abs(target - v[0]) < 0.005f) v[0] = target;
        return v[0];
    }

    public static void clearAnim() {
        if (ANIM.size() > 2000) ANIM.clear();
    }
}
