package com.zone19.scp.client.screen;

import com.zone19.scp.Zone19Mod;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.FormattedCharSequence;
import org.jetbrains.annotations.Nullable;

/** A containment document: the scanned page on the left, a translated summary on the right. */
public class DocumentScreen extends Screen {
    @Nullable
    private final Screen parent;
    private final String scp;
    private final ResourceLocation page;

    public DocumentScreen(@Nullable Screen parent, String scp) {
        super(Component.translatable("doc.scpzone19." + scp + ".name"));
        this.parent = parent;
        this.scp = scp;
        this.page = Zone19Mod.id("textures/gui/docs/doc_" + scp + ".png");
    }

    @Override
    protected void init() {
        addRenderableWidget(new ScpButton(width - 110, height - 30, 100, 20, Component.translatable("gui.back"), b -> onClose()));
    }

    @Override
    public void render(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        if (minecraft.level == null) ScpStyle.background(g, width, height);
        else renderBackground(g);
        int ph = height - 20, pw = ph * 400 / 564;
        g.blit(page, 10, 10, pw, ph, 0, 0, 400, 564, 400, 564);

        int tx = pw + 24, tw = width - tx - 14;
        ScpStyle.panel(g, tx - 6, 10, tw + 6, height - 50);
        g.drawString(font, title, tx, 18, ScpStyle.TEXT, false);
        g.drawString(font, Component.translatable("doc.scpzone19." + scp + ".class"), tx, 30, ScpStyle.RED, false);
        int y = 46;
        for (FormattedCharSequence line : font.split(Component.translatable("doc.scpzone19." + scp + ".summary"), tw - 6)) {
            if (y > height - 52) break;
            g.drawString(font, line, tx, y, 0xFFC4C7CB, false);
            y += 10;
        }
        super.render(g, mouseX, mouseY, partialTick);
    }

    @Override
    public void onClose() {
        minecraft.setScreen(parent);
    }

    @Override
    public boolean isPauseScreen() {
        return false;
    }
}
