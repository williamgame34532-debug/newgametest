package com.williamgame.hideandhunt.client;

import com.williamgame.hideandhunt.game.Side;
import com.williamgame.hideandhunt.network.ResultsPacket;
import net.minecraft.ChatFormatting;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.network.chat.Component;
import net.minecraft.util.Mth;

/** End-of-round results: winner banner, highlight cards and a scrollable score table. */
public class ResultsScreen extends Screen {
    private final ResultsPacket results;
    private int scroll;
    private int openTicks;

    private int px, py, pw, ph;
    private int tableTop, rowsVisible;
    private static final int ROW_H = 13;

    public ResultsScreen(ResultsPacket results) {
        super(Component.translatable("hideandhunt.results.title"));
        this.results = results;
    }

    @Override
    protected void init() {
        pw = Math.min(420, width - 20);
        ph = Math.min(280, height - 20);
        px = (width - pw) / 2;
        py = (height - ph) / 2;
        tableTop = py + 112;
        rowsVisible = Math.max(1, (py + ph - 30 - tableTop - ROW_H) / ROW_H);
        addRenderableWidget(Button.builder(Component.translatable("hideandhunt.gui.close"), b -> onClose())
                .bounds(px + pw / 2 - 50, py + ph - 24, 100, 18).build());
    }

    @Override
    public void tick() {
        openTicks++;
    }

    @Override
    public boolean isPauseScreen() {
        return false;
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double dx, double dy) {
        int max = Math.max(0, results.entries().size() - rowsVisible);
        scroll = Mth.clamp(scroll - (int) Math.signum(dy), 0, max);
        return true;
    }

    @Override
    public void renderBackground(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        super.renderBackground(g, mouseX, mouseY, partialTick);
        drawContent(g, partialTick);
    }

    private void drawContent(GuiGraphics g, float partialTick) {
        Side winner = Side.byOrdinal(results.winner());
        int accent = winner == Side.HIDER ? 0xFF55FF7F : winner == Side.HUNTER ? 0xFFFF5555 : 0xFFFFAA00;
        UiDraw.panel(g, px, py, pw, ph, accent, 1F);

        // ---- banner
        float t = openTicks + partialTick;
        float pop = 1F + 0.35F * Math.max(0F, 1F - t / 10F);
        Component banner = Component.translatable(winner == Side.HIDER ? "hideandhunt.results.hiders_win" : "hideandhunt.results.hunters_win")
                .withStyle(ChatFormatting.BOLD);
        int glow = UiDraw.withAlpha(accent, 0.25F + 0.15F * Mth.sin(t * 0.25F));
        g.fillGradient(px + 1, py + 2, px + pw - 1, py + 40, glow, 0x00000000);
        UiDraw.scaledCentered(g, font, banner, width / 2, py + 10, Math.min(3F, 2.2F * pop), accent);
        Component sub = Component.translatable("hideandhunt.results.sub", results.arena(), UiDraw.clock(results.durationSec()),
                Component.translatable(results.infection() ? "hideandhunt.choice.mode.infection" : "hideandhunt.choice.mode.classic"));
        g.drawCenteredString(font, sub, width / 2, py + 34, 0xFFAAAABB);

        // ---- highlight cards
        int cw = (pw - 32) / 3;
        int cy = py + 50;
        card(g, px + 8, cy, cw, Component.translatable("hideandhunt.results.best_hider"),
                results.bestHider().isEmpty() ? "-" : results.bestHider(),
                results.bestHider().isEmpty() ? "" : UiDraw.clock(results.bestHiderSec()), 0xFF55FF7F);
        card(g, px + 16 + cw, cy, cw, Component.translatable("hideandhunt.results.top_hunter"),
                results.topHunter().isEmpty() ? "-" : results.topHunter(),
                results.topHunter().isEmpty() ? "" : Component.translatable("hideandhunt.results.catches_n", results.topHunterCatches()).getString(), 0xFFFF5555);
        card(g, px + 24 + cw * 2, cy, cw, Component.translatable("hideandhunt.results.mvp"),
                results.mvp().isEmpty() ? "-" : results.mvp(), "★", 0xFFFFD54A);

        // ---- table
        int x0 = px + 10, x1 = px + pw - 10;
        int[] col = {x0 + 2, x0 + 16, x0 + (int) ((x1 - x0) * 0.36), x0 + (int) ((x1 - x0) * 0.53),
                x0 + (int) ((x1 - x0) * 0.63), x0 + (int) ((x1 - x0) * 0.75), x0 + (int) ((x1 - x0) * 0.91)};
        int hy = tableTop;
        g.fill(x0, hy - 2, x1, hy + 10, 0xFF22223A);
        String[] heads = {"#", "player", "role", "catches", "survived", "caught_by", "points"};
        for (int i = 0; i < heads.length; i++) {
            Component h = i == 0 ? Component.literal("#") : Component.translatable("hideandhunt.results.col." + heads[i]);
            g.drawString(font, h, col[i], hy, 0xFFBBBBDD, false);
        }
        int y = hy + ROW_H;
        int end = Math.min(results.entries().size(), scroll + rowsVisible);
        for (int i = scroll; i < end; i++) {
            ResultsPacket.Entry e = results.entries().get(i);
            Side start = Side.byOrdinal(e.startSide());
            Side fin = Side.byOrdinal(e.endSide());
            if (i % 2 == 0) g.fill(x0, y - 2, x1, y + ROW_H - 2, 0x30FFFFFF);
            boolean mvp = e.name().equals(results.mvp());
            g.drawString(font, String.valueOf(i + 1), col[0], y, mvp ? 0xFFFFD54A : 0xFF888899, false);
            g.drawString(font, (mvp ? "★ " : "") + e.name(), col[1], y, start.argb, false);
            Component role;
            if (start != fin && fin == Side.HUNTER) {
                role = Component.translatable("hideandhunt.results.infected").withStyle(ChatFormatting.DARK_RED);
            } else {
                role = start.displayName();
            }
            g.drawString(font, role, col[2], y, 0xFFFFFFFF, false);
            g.drawString(font, e.catches() > 0 ? String.valueOf(e.catches()) : "-", col[3], y, 0xFFFF8888, false);
            String surv = start == Side.HIDER ? UiDraw.clock(e.surviveSec()) + (e.survived() ? " ✔" : "") : "-";
            g.drawString(font, surv, col[4], y, e.survived() ? 0xFF55FF7F : 0xFFCCCCCC, false);
            String by = start == Side.HIDER && !e.survived()
                    ? (e.caughtBy().isEmpty() ? Component.translatable("hideandhunt.results.left").getString() : e.caughtBy()) : "-";
            g.drawString(font, font.plainSubstrByWidth(by, col[6] - col[5] - 4), col[5], y, 0xFFCCCCCC, false);
            g.drawString(font, String.valueOf(e.points()), col[6], y, 0xFFFFD54A, false);
            y += ROW_H;
        }
        if (results.entries().size() > rowsVisible) {
            int trackH = rowsVisible * ROW_H;
            int max = results.entries().size() - rowsVisible;
            int thumbH = Math.max(10, trackH * rowsVisible / results.entries().size());
            int ty = hy + ROW_H + (trackH - thumbH) * scroll / Math.max(1, max);
            g.fill(x1 + 2, hy + ROW_H, x1 + 4, hy + ROW_H + trackH, 0xFF22223A);
            g.fill(x1 + 2, ty, x1 + 4, ty + thumbH, 0xFF8888AA);
        }
    }

    private void card(GuiGraphics g, int x, int y, int w, Component title, String name, String value, int color) {
        g.fill(x, y, x + w, y + 50, 0xC0181826);
        g.fill(x, y, x + w, y + 2, color);
        g.drawCenteredString(font, title, x + w / 2, y + 6, UiDraw.darker(color, 0.85F) | 0xFF000000);
        g.drawCenteredString(font, font.plainSubstrByWidth(name, w - 6), x + w / 2, y + 20, 0xFFFFFFFF);
        g.drawCenteredString(font, value, x + w / 2, y + 34, color);
    }
}
