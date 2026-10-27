package com.williamgame.modcritic.client;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Button;
import net.minecraft.network.chat.Component;

/** Button drawn in the Mod Critic style: dark rounded pill, accent border, smooth hover glow. */
public class FancyButton extends Button {
    private int accent;
    private boolean selected;

    public FancyButton(int x, int y, int w, int h, Component message, int accent, Button.OnPress onPress) {
        super(x, y, w, h, message, onPress, DEFAULT_NARRATION);
        this.accent = accent;
    }

    public FancyButton setSelected(boolean selected) {
        this.selected = selected;
        return this;
    }

    public boolean isSelected() {
        return selected;
    }

    public void setAccent(int accent) {
        this.accent = accent;
    }

    @Override
    protected void renderWidget(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        float h = Ui.anim(this, isHoveredOrFocused() && active);
        float s = Ui.anim(new SelKey(this), selected);
        int x = getX(), y = getY(), w = getWidth(), hh = getHeight();
        int bg = Ui.lerpColor(0xE0181824, Ui.alpha(Ui.darken(accent, 0.6f), 0xF0), Math.max(h * 0.8f, s));
        if (!active) bg = 0xC0101014;
        Ui.fillRounded(g, x, y, w, hh, bg);
        g.fillGradient(x + 1, y + 1, x + w - 1, y + hh / 2, Ui.alpha(0xFFFFFF, (int) (0x18 + 0x20 * h)), 0x00FFFFFF);
        int border = active ? Ui.lerpColor(Ui.alpha(accent, 0x90), Ui.brighten(accent, 0.3f), Math.max(h, s)) : 0xFF333340;
        Ui.outlineRounded(g, x, y, w, hh, border);
        if (s > 0.01f) {
            int lw = (int) ((w - 6) * s);
            g.fill(x + (w - lw) / 2, y + hh - 2, x + (w + lw) / 2, y + hh - 1, Ui.brighten(accent, 0.4f));
        }
        Font font = Minecraft.getInstance().font;
        int color = active ? Ui.lerpColor(Ui.TEXT, Ui.brighten(accent, 0.6f), Math.max(h, s)) : Ui.TEXT_FAINT;
        Component msg = getMessage();
        String text = Ui.ellipsize(font, msg.getString(), w - 6);
        int tw = font.width(text);
        int ty = y + (hh - 8) / 2;
        if (text.length() == msg.getString().length()) {
            g.drawString(font, msg, x + (w - tw) / 2, ty, color, true);
        } else {
            g.drawString(font, text, x + (w - tw) / 2, ty, color, true);
        }
    }

    /** Separate animation key for the "selected" state. */
    private record SelKey(FancyButton b) {
    }
}
