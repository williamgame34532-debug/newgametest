package com.zone19.scp.client.screen;

import com.zone19.scp.client.ClientState;
import com.zone19.scp.story.Chapters;
import net.minecraft.ChatFormatting;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.network.chat.Component;
import net.minecraft.util.FormattedCharSequence;
import org.jetbrains.annotations.Nullable;

/**
 * In-world menu of the Zone-19 security terminal (opens on first entry and with [J]):
 * briefing for the current chapter, the chapter list, personnel and the archive.
 */
public class TerminalScreen extends Screen {
    private enum Tab { BRIEFING, CHAPTERS }

    @Nullable
    private final Screen parent;
    private Tab tab = Tab.BRIEFING;
    private ScpButton briefingButton, chaptersButton;

    public TerminalScreen(@Nullable Screen parent) {
        super(Component.translatable("gui.scpzone19.terminal"));
        this.parent = parent;
    }

    @Override
    protected void init() {
        int x = width / 2 - 200, y = 48;
        briefingButton = addRenderableWidget(new ScpButton(x, y, 110, 20, Component.translatable("gui.scpzone19.tab.briefing"), b -> setTab(Tab.BRIEFING)));
        chaptersButton = addRenderableWidget(new ScpButton(x, y + 24, 110, 20, Component.translatable("gui.scpzone19.tab.chapters"), b -> setTab(Tab.CHAPTERS)));
        addRenderableWidget(new ScpButton(x, y + 48, 110, 20, Component.translatable("gui.scpzone19.tab.personnel"),
                b -> minecraft.setScreen(new SkinSelectScreen(this))));
        addRenderableWidget(new ScpButton(x, y + 72, 110, 20, Component.translatable("gui.scpzone19.tab.archive"),
                b -> minecraft.setScreen(new ArchiveScreen(this))));
        addRenderableWidget(new ScpButton(x, y + 108, 110, 20, Component.translatable("gui.scpzone19.tab.start"), b -> onClose()));
        setTab(tab);
    }

    private void setTab(Tab t) {
        tab = t;
        briefingButton.selected(t == Tab.BRIEFING);
        chaptersButton.selected(t == Tab.CHAPTERS);
    }

    @Override
    public void render(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        renderBackground(g);
        g.fill(0, 0, width, height, 0x90000000);
        int x = width / 2 - 200;
        ScpStyle.emblem(g, x, 8, 32, 0.9F);
        g.drawString(font, title, x + 40, 14, ScpStyle.TEXT, false);
        g.drawString(font, Component.translatable("gui.scpzone19.terminal.sub"), x + 40, 26, ScpStyle.DIM, false);

        int px = x + 120, py = 48, pw = 280, ph = height - 90;
        ScpStyle.panel(g, px, py, pw, ph);
        if (tab == Tab.BRIEFING) briefing(g, px + 10, py + 10, pw - 20);
        else chapters(g, px + 10, py + 10, pw - 20);

        g.drawString(font, Component.translatable("gui.scpzone19.terminal.keys"), x, height - 30, ScpStyle.DIM, false);
        ScpStyle.scanlines(g, width, height);
        super.render(g, mouseX, mouseY, partialTick);
    }

    private int wrap(GuiGraphics g, Component text, int x, int y, int w, int color) {
        for (FormattedCharSequence line : font.split(text, w)) {
            g.drawString(font, line, x, y, color, false);
            y += 10;
        }
        return y;
    }

    private void briefing(GuiGraphics g, int x, int y, int w) {
        if (ClientState.chapter <= 0) {
            ScpStyle.header(g, font, x, y, w, Component.translatable("gui.scpzone19.briefing.idle"));
            wrap(g, Component.translatable("gui.scpzone19.briefing.idle.text"), x, y + 18, w, 0xFFC4C7CB);
            return;
        }
        if (ClientState.finished) {
            ScpStyle.header(g, font, x, y, w, Component.translatable("ending.scpzone19.title"));
            wrap(g, Component.translatable("gui.scpzone19.briefing.done"), x, y + 18, w, 0xFFC4C7CB);
            return;
        }
        int n = ClientState.chapter;
        ScpStyle.header(g, font, x, y, w, Component.translatable("gui.scpzone19.chapter_n", n));
        y += 16;
        g.drawString(font, Component.translatable("chapter.scpzone19." + n + ".title").withStyle(ChatFormatting.BOLD), x, y, ScpStyle.RED, false);
        y += 11;
        g.drawString(font, Component.translatable("chapter.scpzone19." + n + ".subtitle"), x, y, ScpStyle.DIM, false);
        y += 16;
        y = wrap(g, Component.translatable("chapter.scpzone19." + n + ".desc"), x, y, w, 0xFFC4C7CB);
        y += 10;
        ScpStyle.header(g, font, x, y, w, Component.translatable("gui.scpzone19.objective"));
        y += 16;
        Component obj = Component.translatable(ClientState.objective);
        if (ClientState.required > 1) {
            obj = Component.translatable("gui.scpzone19.objective_progress", obj, ClientState.progress, ClientState.required);
        }
        wrap(g, obj, x, y, w, ScpStyle.AMBER);
    }

    private void chapters(GuiGraphics g, int x, int y, int w) {
        ScpStyle.header(g, font, x, y, w, Component.translatable("gui.scpzone19.tab.chapters"));
        y += 18;
        for (int n = 1; n <= Chapters.COUNT; n++) {
            boolean done = ClientState.finished || n < ClientState.chapter;
            boolean current = !ClientState.finished && n == ClientState.chapter;
            int color = done ? ScpStyle.GREEN : current ? ScpStyle.AMBER : 0xFF55585C;
            String mark = done ? "[+]" : current ? "[>]" : "[ ]";
            g.drawString(font, mark, x, y, color, false);
            Component name = done || current
                    ? Component.translatable("chapter.scpzone19." + n + ".title")
                    : Component.translatable("gui.scpzone19.redacted");
            g.drawString(font, Component.translatable("gui.scpzone19.chapter_n", n), x + 22, y, color, false);
            g.drawString(font, name, x + 22, y + 10, done || current ? ScpStyle.TEXT : 0xFF3A3C40, false);
            y += 26;
        }
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
