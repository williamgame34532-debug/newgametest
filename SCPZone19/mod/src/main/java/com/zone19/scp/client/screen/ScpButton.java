package com.zone19.scp.client.screen;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Button;
import net.minecraft.network.chat.Component;
import net.minecraft.util.Mth;

/** Flat terminal-style button with a red hover bar that slides in. */
public class ScpButton extends Button {
    private float hover;
    private boolean selected;

    public ScpButton(int x, int y, int w, int h, Component message, OnPress onPress) {
        super(x, y, w, h, message, onPress, DEFAULT_NARRATION);
    }

    public ScpButton selected(boolean value) {
        selected = value;
        return this;
    }

    @Override
    protected void renderWidget(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        boolean hot = active && (isHoveredOrFocused() || selected);
        hover = Mth.lerp(0.3F, hover, hot ? 1.0F : 0.0F);
        int x = getX(), y = getY(), w = getWidth(), h = getHeight();
        g.fill(x, y, x + w, y + h, hot ? 0xCC2A0F0F : 0xB00D0E10);
        g.fill(x, y, x + (int) (w * hover), y + h, 0x30C42822);
        g.renderOutline(x, y, w, h, hot ? ScpStyle.RED : ScpStyle.EDGE);
        g.fill(x, y, x + 2 + (int) (hover * 3), y + h, hot ? ScpStyle.RED : 0xFF55585C);
        Font font = Minecraft.getInstance().font;
        int color = !active ? 0xFF5A5C60 : hot ? 0xFFFFFFFF : 0xFFCFCFCF;
        g.drawString(font, getMessage(), x + 10 + (int) (hover * 4), y + (h - 8) / 2, color, false);
        if (hot) g.drawString(font, ">", x + w - 10, y + (h - 8) / 2, ScpStyle.RED, false);
    }
}
