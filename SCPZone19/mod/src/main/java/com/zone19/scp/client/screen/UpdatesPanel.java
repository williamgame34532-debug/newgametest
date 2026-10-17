package com.zone19.scp.client.screen;

import com.zone19.scp.Zone19Mod;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.network.chat.Component;
import net.minecraft.util.FormattedCharSequence;
import net.minecraft.util.Mth;

import java.util.List;

/** Scrollable column of update cards ("what's new in this build"). */
public class UpdatesPanel {
    private final Font font;
    private int x, y, w, h;
    private double scroll;
    private int contentHeight;

    public UpdatesPanel(Font font, int x, int y, int w, int h) {
        this.font = font;
        setBounds(x, y, w, h);
    }

    public void setBounds(int x, int y, int w, int h) {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
    }

    public boolean isMouseOver(double mx, double my) {
        return mx >= x && mx < x + w && my >= y && my < y + h;
    }

    public void scroll(double delta) {
        scroll = Mth.clamp(scroll - delta * 18, 0, Math.max(0, contentHeight - (h - 26)));
    }

    public void render(GuiGraphics g) {
        ScpStyle.panel(g, x, y, w, h);
        ScpStyle.header(g, font, x + 6, y + 6, w - 12, Component.translatable("gui.scpzone19.updates"));
        String ver = "v" + Zone19Mod.VERSION;
        g.drawString(font, ver, x + w - 8 - font.width(ver), y + 6, ScpStyle.DIM, false);

        int top = y + 22, bottom = y + h - 4;
        g.enableScissor(x + 1, top, x + w - 1, bottom);
        int cy = top - (int) scroll;
        int cardW = w - 16;
        for (UpdateFeed.Entry e : UpdateFeed.ENTRIES) {
            cy = card(g, e, x + 8, cy, cardW);
            cy += 6;
        }
        contentHeight = cy + (int) scroll - top;
        g.disableScissor();

        if (contentHeight > h - 26) {
            int track = bottom - top;
            int knob = Math.max(16, track * (h - 26) / contentHeight);
            int ky = top + (int) ((track - knob) * (scroll / Math.max(1, contentHeight - (h - 26))));
            g.fill(x + w - 3, ky, x + w - 1, ky + knob, ScpStyle.RED_DIM);
        }
    }

    private int card(GuiGraphics g, UpdateFeed.Entry e, int cx, int cy, int cw) {
        List<FormattedCharSequence> title = font.split(Component.translatable(e.key("title")), cw - 12);
        int start = cy;
        int inner = cy + 4;
        Component tag = Component.translatable(e.key("tag"));
        int tw = font.width(tag) + 8;
        int lineY = inner + 14 + title.size() * 10;
        int textH = 0;
        for (int i = 1; i <= e.lines(); i++) {
            textH += font.split(Component.translatable(e.key(String.valueOf(i))), cw - 18).size() * 9 + 2;
        }
        int ch = lineY - cy + textH + 4;
        g.fill(cx, cy, cx + cw, cy + ch, 0x9914161A);
        g.fill(cx, cy, cx + 2, cy + ch, e.color());
        g.fill(cx + 6, inner, cx + 6 + tw, inner + 11, (e.color() & 0x00FFFFFF) | 0x55000000);
        g.drawString(font, tag, cx + 10, inner + 2, 0xFFFFFFFF, false);
        int ty = inner + 14;
        for (FormattedCharSequence line : title) {
            g.drawString(font, line, cx + 6, ty, ScpStyle.TEXT, false);
            ty += 10;
        }
        int ly = lineY;
        for (int i = 1; i <= e.lines(); i++) {
            List<FormattedCharSequence> lines = font.split(Component.translatable(e.key(String.valueOf(i))), cw - 18);
            g.drawString(font, "•", cx + 6, ly, e.color(), false);
            for (FormattedCharSequence l : lines) {
                g.drawString(font, l, cx + 13, ly, 0xFFB8BBBF, false);
                ly += 9;
            }
            ly += 2;
        }
        return start + ch;
    }
}
