package com.williamgame.modcritic.client;

import com.williamgame.modcritic.Criterion;
import com.williamgame.modcritic.Scoring;
import net.minecraft.ChatFormatting;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.network.chat.Component;

import java.util.ArrayList;
import java.util.List;

/** Adjust how much each criterion counts in the weighted total (0..5 in steps of 0.5). */
public class WeightsScreen extends Screen {
    private static final int STEPS = 10; // 0..5 by 0.5

    private final Screen parent;
    private final double[] weights;
    private final StepSlider[] sliders = new StepSlider[Criterion.COUNT];

    private int px, py, pw, ph, rowsTop, rowH, labelW, sliderX, sliderW, shareX, shareW;

    public WeightsScreen(Screen parent) {
        super(Component.translatable("modcritic.weights.title"));
        this.parent = parent;
        this.weights = LocalStore.weights().clone();
    }

    @Override
    protected void init() {
        pw = Math.min(380, width - 16);
        int previewH = 46;
        ph = Math.min(height - 70, 30 + Criterion.COUNT * 20 + previewH + 8);
        px = (width - pw) / 2;
        py = 34;
        rowsTop = py + 26;
        rowH = Math.max(13, Math.min(20, (ph - 26 - previewH - 8) / Criterion.COUNT));
        labelW = 0;
        for (Criterion c : Criterion.values()) labelW = Math.max(labelW, font.width(Component.translatable(c.nameKey())) + 12);
        labelW = Math.min(labelW, pw / 3);
        shareW = Math.max(40, pw / 5);
        sliderX = px + 10 + labelW + 4;
        shareX = px + pw - 10 - shareW;
        sliderW = Math.max(40, shareX - 40 - sliderX);
        int sh = Math.max(9, Math.min(14, rowH - 4));
        for (Criterion c : Criterion.values()) {
            int i = c.ordinal();
            int y = rowsTop + i * rowH + (rowH - sh) / 2;
            sliders[i] = addRenderableWidget(new StepSlider(sliderX, y, sliderW, sh, STEPS,
                    (int) Math.round(weights[i] * 2), c.color, step -> weights[i] = step / 2.0));
        }

        int by = height - 26;
        int n = 4, gap = 4;
        int bw = Math.min(110, (width - 16 - gap * (n - 1)) / n);
        int bx = (width - (bw * n + gap * (n - 1))) / 2;
        addRenderableWidget(new FancyButton(bx, by, bw, 20, Component.translatable("modcritic.weights.equal"), 0xFF8A8AB0,
                b -> preset(new double[]{1, 1, 1, 1, 1, 1, 1, 1})));
        addRenderableWidget(new FancyButton(bx + (bw + gap), by, bw, 20, Component.translatable("modcritic.weights.gameplay"), 0xFF4FC36A,
                b -> preset(new double[]{1.5, 0.5, 2.5, 1, 0.5, 2, 1, 2})));
        addRenderableWidget(new FancyButton(bx + (bw + gap) * 2, by, bw, 20, Component.translatable("modcritic.weights.atmosphere"), 0xFF9B6BE0,
                b -> preset(new double[]{1.5, 2.5, 1, 2, 2, 0.5, 1.5, 0.5})));
        addRenderableWidget(new FancyButton(bx + (bw + gap) * 3, by, bw, 20, Component.translatable("modcritic.button.done"), Ui.GOLD,
                b -> onClose()));
    }

    private void preset(double[] w) {
        for (int i = 0; i < Criterion.COUNT; i++) {
            weights[i] = w[i];
            sliders[i].setStepSilently((int) Math.round(w[i] * 2));
        }
    }

    @Override
    public void onClose() {
        LocalStore.setWeights(weights);
        LocalStore.save();
        minecraft.setScreen(parent);
    }

    @Override
    public void renderBackground(GuiGraphics g, int mx, int my, float pt) {
        super.renderBackground(g, mx, my, pt);
        Ui.tickFrame();
        g.fillGradient(0, 0, width, 32, 0x90000000, 0x00000000);
        Ui.panel(g, px, py, pw, ph, Ui.alpha(0xFF9B6BE0, 0x90));
        for (int i = 0; i < Criterion.COUNT; i++) {
            int y = rowsTop + i * rowH;
            float a = Ui.anim("wrow" + i, Ui.inside(mx, my, px + 4, y, pw - 8, rowH));
            int base = (i % 2 == 0) ? 0x14FFFFFF : 0x08FFFFFF;
            g.fill(px + 4, y, px + pw - 4, y + rowH, Ui.lerpColor(base, Ui.alpha(Criterion.values()[i].color, 0x30), a));
        }
    }

    @Override
    public void render(GuiGraphics g, int mx, int my, float pt) {
        super.render(g, mx, my, pt);
        Ui.centeredScaled(g, font, title, width / 2, 7, 1.5f, 0xFFC9A8FF);
        g.drawCenteredString(font, Component.translatable("modcritic.weights.subtitle"), width / 2, 22, Ui.TEXT_DIM);

        g.drawString(font, Component.translatable("modcritic.weights.criterion"), px + 10, py + 9, Ui.TEXT_FAINT, false);
        Component shareLabel = Component.translatable("modcritic.weights.share");
        g.drawString(font, shareLabel, shareX + shareW - font.width(shareLabel), py + 9, Ui.TEXT_FAINT, false);

        double sum = 0;
        for (double w : weights) sum += w;
        for (Criterion c : Criterion.values()) {
            int i = c.ordinal();
            int y = rowsTop + i * rowH;
            int cy = y + (rowH - 8) / 2;
            g.fill(px + 10, cy + 1, px + 16, cy + 7, c.color);
            g.drawString(font, Ui.ellipsize(font, Component.translatable(c.nameKey()).getString(), labelW - 12), px + 20, cy, Ui.TEXT, true);
            String v = "×" + (weights[i] == Math.floor(weights[i]) ? String.valueOf((int) weights[i]) : String.valueOf(weights[i]));
            g.drawString(font, v, sliderX + sliderW + 6, cy, weights[i] == 0 ? Ui.TEXT_FAINT : Ui.TEXT, true);
            float share = sum <= 0 ? 1f / Criterion.COUNT : (float) (weights[i] / sum);
            Ui.bar(g, shareX, y + (rowH - 8) / 2, shareW - 26, 8, share * 2.5f, c.color);
            String pct = Math.round(share * 100) + "%";
            g.drawString(font, pct, shareX + shareW - font.width(pct), cy, Ui.TEXT_DIM, false);
        }

        // live preview of the top 3 with these weights
        int y0 = rowsTop + Criterion.COUNT * rowH + 6;
        g.fill(px + 6, y0 - 3, px + pw - 6, y0 - 2, 0x30FFFFFF);
        g.drawString(font, Component.translatable("modcritic.weights.preview"), px + 10, y0 + 2, Ui.GOLD_DARK, false);
        List<Scoring.Row> rows = Scoring.rowsOf(new ArrayList<>(LocalStore.ratings().values()), weights);
        if (rows.isEmpty()) {
            g.drawString(font, Component.translatable("modcritic.results.empty_mine").withStyle(ChatFormatting.ITALIC), px + 10, y0 + 16, Ui.TEXT_FAINT, false);
        } else {
            int colW = (pw - 20) / 3;
            for (int k = 0; k < Math.min(3, rows.size()); k++) {
                Scoring.Row r = rows.get(k);
                int x = px + 10 + k * colW;
                int medal = k == 0 ? 0xFFFFC94A : k == 1 ? 0xFFD8D8E8 : 0xFFD08A4A;
                g.drawString(font, "#" + (k + 1), x, y0 + 16, medal, true);
                g.drawString(font, Ui.ellipsize(font, r.modName, colW - 20), x + 16, y0 + 16, Ui.TEXT, true);
                g.drawString(font, Scoring.fmt2(r.total), x + 16, y0 + 28, Ui.scoreColor(r.total), true);
            }
        }

        for (Criterion c : Criterion.values()) {
            int y = rowsTop + c.ordinal() * rowH;
            if (Ui.inside(mx, my, px + 8, y, labelW + 10, rowH)) {
                List<Component> lines = new ArrayList<>();
                lines.add(Component.translatable(c.nameKey()).withStyle(s -> s.withColor(c.color & 0xFFFFFF)));
                lines.add(Component.translatable(c.descKey()).withStyle(ChatFormatting.GRAY));
                Ui.tooltip(g, font, lines, mx, my, 200);
            }
        }
    }

    @Override
    public boolean isPauseScreen() {
        return true;
    }
}
