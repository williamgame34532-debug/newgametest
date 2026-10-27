package com.williamgame.modcritic.client;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractSliderButton;
import net.minecraft.network.chat.Component;
import org.lwjgl.glfw.GLFW;

import java.util.function.IntConsumer;

/**
 * A slider snapping to integer steps {@code 0..steps}. Custom-drawn: coloured gradient track,
 * tick marks and a glowing knob. The step index is reported to {@code onChange}.
 */
public class StepSlider extends AbstractSliderButton {
    private final int steps;
    private final IntConsumer onChange;
    private int color;
    private int step;
    private boolean dim;

    public StepSlider(int x, int y, int w, int h, int steps, int initial, int color, IntConsumer onChange) {
        super(x, y, w, h, Component.empty(), 0.0);
        this.steps = Math.max(1, steps);
        this.color = color;
        this.onChange = onChange;
        setStepSilently(initial);
    }

    public int getStep() {
        return step;
    }

    /** Moves the knob without firing onChange. */
    public void setStepSilently(int s) {
        step = Math.max(0, Math.min(steps, s));
        value = step / (double) steps;
        updateMessage();
    }

    public void setColor(int color) {
        this.color = color;
    }

    /** Dim = shows a default value for an unrated mod. */
    public void setDim(boolean dim) {
        this.dim = dim;
    }

    @Override
    protected void updateMessage() {
        setMessage(Component.literal(String.valueOf(step)));
    }

    @Override
    protected void applyValue() {
        int s = (int) Math.round(value * steps);
        s = Math.max(0, Math.min(steps, s));
        value = s / (double) steps;
        if (s != step) {
            step = s;
            updateMessage();
            onChange.accept(step);
        }
    }

    @Override
    public boolean keyPressed(int keyCode, int scanCode, int modifiers) {
        if (keyCode == GLFW.GLFW_KEY_LEFT || keyCode == GLFW.GLFW_KEY_RIGHT) {
            int s = step + (keyCode == GLFW.GLFW_KEY_LEFT ? -1 : 1);
            s = Math.max(0, Math.min(steps, s));
            if (s != step) {
                value = s / (double) steps;
                step = s;
                updateMessage();
                onChange.accept(step);
            }
            return true;
        }
        return super.keyPressed(keyCode, scanCode, modifiers);
    }

    @Override
    public void renderWidget(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        float hov = Ui.anim(this, isHoveredOrFocused());
        int x = getX(), y = getY(), w = getWidth(), h = getHeight();
        int trackH = Math.max(4, Math.min(6, h / 2));
        int ty = y + (h - trackH) / 2;
        int c = dim ? 0xFF6A6A80 : color;

        // track
        Ui.fillRounded(g, x, ty, w, trackH, 0xC0000000);
        Ui.outlineRounded(g, x, ty, w, trackH, Ui.alpha(0xFFFFFF, (int) (0x30 + 0x40 * hov)));
        int knobW = 6;
        int travel = w - knobW;
        int kx = x + (int) Math.round(value * travel);
        int fillTo = kx + knobW / 2;
        if (fillTo > x + 1) {
            g.fillGradient(x + 1, ty + 1, fillTo, ty + trackH - 1, Ui.brighten(c, 0.3f), Ui.darken(c, 0.2f));
        }
        // tick marks
        for (int i = 0; i <= steps; i++) {
            int tx = x + knobW / 2 + (int) Math.round(i * travel / (double) steps);
            g.fill(tx, ty + trackH, tx + 1, ty + trackH + 2, Ui.alpha(0xFFFFFF, i <= step ? 0x70 : 0x30));
        }
        // knob with glow
        if (hov > 0.01f) {
            Ui.fillRounded(g, kx - 2, y - 1, knobW + 4, h + 2, Ui.alpha(c, (int) (0x60 * hov)));
        }
        Ui.fillRounded(g, kx, y + 1, knobW, h - 2, Ui.lerpColor(0xFFDADAE6, 0xFFFFFFFF, hov));
        g.fill(kx + 1, y + 2, kx + knobW - 1, y + h / 2, 0x40FFFFFF);
        Ui.outlineRounded(g, kx, y + 1, knobW, h - 2, Ui.darken(c, 0.3f));
    }
}
