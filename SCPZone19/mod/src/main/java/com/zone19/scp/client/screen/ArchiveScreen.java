package com.zone19.scp.client.screen;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.network.chat.Component;
import net.minecraft.util.FormattedCharSequence;
import org.jetbrains.annotations.Nullable;

import java.util.List;

/** Foundation archive: containment documents for every anomaly in the campaign. */
public class ArchiveScreen extends Screen {
    private static final String[] FILES = {"173", "096", "106", "049"};
    @Nullable
    private final Screen parent;

    public ArchiveScreen(@Nullable Screen parent) {
        super(Component.translatable("gui.scpzone19.archive"));
        this.parent = parent;
    }

    @Override
    protected void init() {
        int y = 60;
        for (String f : FILES) {
            addRenderableWidget(new ScpButton(width / 2 - 160, y, 120, 20, Component.translatable("doc.scpzone19." + f + ".name"),
                    b -> minecraft.setScreen(new DocumentScreen(this, f))));
            y += 52;
        }
        addRenderableWidget(new ScpButton(width / 2 - 160, height - 34, 100, 20, Component.translatable("gui.back"), b -> onClose()));
    }

    @Override
    public void render(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        if (minecraft.level == null) ScpStyle.background(g, width, height);
        else renderBackground(g);
        ScpStyle.header(g, font, width / 2 - 160, 34, 320, title);
        int y = 60;
        for (String f : FILES) {
            int tx = width / 2 - 32;
            g.drawString(font, Component.translatable("doc.scpzone19." + f + ".class"), tx, y + 2, ScpStyle.RED, false);
            int ly = y + 14;
            List<FormattedCharSequence> lines = font.split(Component.translatable("doc.scpzone19." + f + ".short"), 190);
            for (int i = 0; i < Math.min(3, lines.size()); i++) {
                g.drawString(font, lines.get(i), tx, ly, 0xFFB0B3B7, false);
                ly += 10;
            }
            y += 52;
        }
        ScpStyle.scanlines(g, width, height);
        super.render(g, mouseX, mouseY, partialTick);
    }

    @Override
    public void onClose() {
        minecraft.setScreen(parent);
    }
}
