package com.williamgame.modcritic.client;

import com.williamgame.modcritic.Criterion;
import com.williamgame.modcritic.RatingEntry;
import com.williamgame.modcritic.Scoring;
import net.minecraft.ChatFormatting;
import net.minecraft.Util;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Tooltip;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.sounds.SoundEvents;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;

/**
 * Results: ranking with weighted totals and badges, per-criterion bar charts, two-mod comparison.
 * Data source: my local ratings, the server average, or one player's ratings from the server.
 */
public class ResultsScreen extends Screen {
    public static final int SOURCE_MINE = 0;
    public static final int SOURCE_SERVER = 1;
    public static final int SOURCE_PLAYER = 2;

    private static final int TAB_RANKING = 0;
    private static final int TAB_CRITERIA = 1;
    private static final int TAB_COMPARE = 2;

    private static final int[] MEDALS = {0xFFFFC94A, 0xFFD8D8E8, 0xFFD08A4A};

    private final Screen parent;
    private int source;
    private String player;
    private int tab = TAB_RANKING;
    private final double[] scroll = new double[3];
    private int criterion = Criterion.ATMOSPHERE.ordinal();
    private int compareA = 0, compareB = 1;
    private boolean requested;

    private List<Scoring.Row> rows = new ArrayList<>();
    private Scoring.Row[] best = new Scoring.Row[Criterion.COUNT];

    private Component status;
    private long statusTime;
    private int statusColor = Ui.GOOD;

    // layout
    private int px, py, pw, ph;
    private int viewY, viewH;

    public ResultsScreen(Screen parent, int source) {
        super(Component.translatable("modcritic.results.title"));
        this.parent = parent;
        this.source = source;
    }

    // ------------------------------------------------------------------ data

    private List<Object> sources() {
        List<Object> list = new ArrayList<>();
        list.add(SOURCE_MINE);
        Map<String, Collection<RatingEntry>> sd = ClientHooks.serverData();
        if (ClientNet.serverHasMod() || sd != null) {
            list.add(SOURCE_SERVER);
            if (sd != null) list.addAll(sd.keySet());
        }
        return list;
    }

    private void recompute() {
        double[] w = LocalStore.weights();
        Map<String, Collection<RatingEntry>> sd = ClientHooks.serverData();
        if (source == SOURCE_SERVER) {
            rows = sd == null ? new ArrayList<>() : Scoring.average(sd, w);
        } else if (source == SOURCE_PLAYER) {
            Collection<RatingEntry> entries = sd == null || player == null ? null : sd.get(player);
            if (entries == null) {
                source = SOURCE_MINE;
                rows = Scoring.rowsOf(LocalStore.ratings().values(), w);
            } else {
                rows = Scoring.rowsOf(entries, w);
            }
        } else {
            rows = Scoring.rowsOf(LocalStore.ratings().values(), w);
        }
        best = rows.size() >= 2 ? Scoring.badges(rows) : new Scoring.Row[Criterion.COUNT];
        if (compareA >= rows.size()) compareA = 0;
        if (compareB >= rows.size() || compareB == compareA) compareB = rows.size() > 1 ? (compareA == 0 ? 1 : 0) : 0;
    }

    /** Called by ClientHooks when a fresh server packet arrives. */
    public void onServerData() {
        recompute();
        rebuildWidgets();
        setStatus(Component.translatable("modcritic.status.server_updated"), Ui.GOOD);
    }

    private Component sourceName() {
        if (source == SOURCE_SERVER) return Component.translatable("modcritic.source.server");
        if (source == SOURCE_PLAYER) return Component.translatable("modcritic.source.player", player);
        return Component.translatable("modcritic.source.mine");
    }

    private void cycleSource() {
        List<Object> list = sources();
        int cur = 0;
        for (int i = 0; i < list.size(); i++) {
            Object o = list.get(i);
            if (source == SOURCE_PLAYER ? player != null && player.equals(o) : Integer.valueOf(source).equals(o)) cur = i;
        }
        Object next = list.get((cur + 1) % list.size());
        if (next instanceof String name) {
            source = SOURCE_PLAYER;
            player = name;
        } else {
            source = (Integer) next;
            player = null;
        }
        if (source != SOURCE_MINE && ClientHooks.serverData() == null) ClientNet.requestResults();
        scroll[0] = scroll[1] = scroll[2] = 0;
        recompute();
        rebuildWidgets();
    }

    // ------------------------------------------------------------------ init

    @Override
    protected void init() {
        if (!requested) {
            requested = true;
            ClientNet.requestResults();
        }
        recompute();

        px = 8;
        py = 52;
        pw = width - 16;
        ph = height - py - 32;

        // tabs
        int tabW = Math.min(100, (pw - 140) / 3);
        String[] tabKeys = {"modcritic.tab.ranking", "modcritic.tab.criteria", "modcritic.tab.compare"};
        for (int i = 0; i < 3; i++) {
            final int t = i;
            FancyButton b = new FancyButton(px + i * (tabW + 3), py - 20, tabW, 18, Component.translatable(tabKeys[i]), Ui.GOLD, btn -> {
                tab = t;
                rebuildWidgets();
            });
            b.setSelected(tab == i);
            addRenderableWidget(b);
        }
        // source + refresh
        int srcW = Math.min(170, pw - 3 * (tabW + 3) - 26);
        FancyButton src = new FancyButton(px + pw - srcW - 22, py - 20, srcW, 18,
                Component.translatable("modcritic.source.label", sourceName()), 0xFF45B0EA, b -> cycleSource());
        src.setTooltip(Tooltip.create(Component.translatable("modcritic.source.tooltip")));
        addRenderableWidget(src);
        FancyButton refresh = new FancyButton(px + pw - 18, py - 20, 18, 18, Component.literal("⟳"), 0xFF45B0EA, b -> {
            if (ClientNet.requestResults()) setStatus(Component.translatable("modcritic.status.requesting"), 0xFF45B0EA);
            else setStatus(Component.translatable("modcritic.status.no_server"), Ui.BAD);
        });
        refresh.setTooltip(Tooltip.create(Component.translatable("modcritic.button.refresh.tooltip")));
        refresh.active = ClientNet.serverHasMod();
        addRenderableWidget(refresh);

        viewY = py + 6;
        viewH = ph - 12;

        if (tab == TAB_CRITERIA) {
            int chipsH = chipsHeight();
            viewY = py + 6 + chipsH + 18;
            viewH = py + ph - 6 - viewY;
        } else if (tab == TAB_COMPARE && rows.size() >= 2) {
            int half = pw / 2;
            addRenderableWidget(new FancyButton(px + 8, py + 6, 16, 16, Component.literal("<"), Ui.COMPARE_A, b -> stepCompare(true, -1)));
            addRenderableWidget(new FancyButton(px + half - 26, py + 6, 16, 16, Component.literal(">"), Ui.COMPARE_A, b -> stepCompare(true, 1)));
            addRenderableWidget(new FancyButton(px + half + 10, py + 6, 16, 16, Component.literal("<"), Ui.COMPARE_B, b -> stepCompare(false, -1)));
            addRenderableWidget(new FancyButton(px + pw - 24, py + 6, 16, 16, Component.literal(">"), Ui.COMPARE_B, b -> stepCompare(false, 1)));
        }

        // bottom buttons
        int by = height - 26;
        int n = 4, gap = 4;
        int bw = Math.min(120, (width - 16 - gap * (n - 1)) / n);
        int bx = (width - (bw * n + gap * (n - 1))) / 2;
        FancyButton export = new FancyButton(bx, by, bw, 20, Component.translatable("modcritic.button.export"), Ui.GOOD, b -> export(false));
        export.setTooltip(Tooltip.create(Component.translatable("modcritic.button.export.tooltip")));
        addRenderableWidget(export);
        FancyButton copy = new FancyButton(bx + (bw + gap), by, bw, 20, Component.translatable("modcritic.button.copy"), 0xFF35D3C0, b -> export(true));
        copy.setTooltip(Tooltip.create(Component.translatable("modcritic.button.copy.tooltip")));
        addRenderableWidget(copy);
        FancyButton send = new FancyButton(bx + (bw + gap) * 2, by, bw, 20, Component.translatable("modcritic.button.send_all"), 0xFF45B0EA, b -> {
            int sent = ClientNet.submitAll();
            if (sent > 0) {
                ClientNet.requestResults();
                setStatus(Component.translatable("modcritic.status.saved_sent", sent), Ui.GOOD);
            } else {
                setStatus(Component.translatable("modcritic.status.nothing_sent"), Ui.BAD);
            }
        });
        send.setTooltip(Tooltip.create(Component.translatable("modcritic.button.send_all.tooltip")));
        send.active = ClientNet.serverHasMod();
        addRenderableWidget(send);
        addRenderableWidget(new FancyButton(bx + (bw + gap) * 3, by, bw, 20, Component.translatable("modcritic.button.back"), 0xFF8A8AB0, b -> onClose()));
    }

    private void stepCompare(boolean a, int dir) {
        int n = rows.size();
        if (n < 2) return;
        if (a) {
            do compareA = (compareA + dir + n) % n; while (compareA == compareB);
        } else {
            do compareB = (compareB + dir + n) % n; while (compareB == compareA);
        }
    }

    private void export(boolean clipboard) {
        String md = MarkdownExport.build(LocalStore.ratings().values(), LocalStore.weights(), ClientHooks.serverData());
        if (clipboard) {
            minecraft.keyboardHandler.setClipboard(md);
            setStatus(Component.translatable("modcritic.status.copied"), Ui.GOOD);
        } else {
            Path p = MarkdownExport.write(md);
            if (p != null) setStatus(Component.translatable("modcritic.status.exported", p.getFileName().toString()), Ui.GOOD);
            else setStatus(Component.translatable("modcritic.status.export_failed"), Ui.BAD);
        }
        minecraft.getSoundManager().play(SimpleSoundInstance.forUI(SoundEvents.EXPERIENCE_ORB_PICKUP, 1.2f, 0.4f));
    }

    private void setStatus(Component c, int color) {
        status = c;
        statusColor = color;
        statusTime = Util.getMillis();
    }

    @Override
    public void onClose() {
        minecraft.setScreen(parent);
    }

    @Override
    public boolean isPauseScreen() {
        return true;
    }

    // ------------------------------------------------------------------ geometry

    private int rankRowH() {
        return height < 260 ? 26 : 30;
    }

    private int chipCols() {
        return pw >= 420 ? 4 : 2;
    }

    private int chipsHeight() {
        int rowsOfChips = (Criterion.COUNT + chipCols() - 1) / chipCols();
        return rowsOfChips * 24;
    }

    private int contentHeight() {
        return switch (tab) {
            case TAB_RANKING -> rows.size() * rankRowH();
            case TAB_CRITERIA -> rows.size() * 14;
            default -> 0;
        };
    }

    private void clampScroll() {
        int max = Math.max(0, contentHeight() - viewH);
        scroll[tab] = Math.max(0, Math.min(max, scroll[tab]));
    }

    // ------------------------------------------------------------------ input

    @Override
    public boolean mouseScrolled(double mx, double my, double sx, double sy) {
        if (Ui.inside(mx, my, px, viewY, pw, viewH)) {
            scroll[tab] -= sy * 20;
            clampScroll();
            return true;
        }
        return super.mouseScrolled(mx, my, sx, sy);
    }

    @Override
    public boolean mouseClicked(double mx, double my, int button) {
        if (super.mouseClicked(mx, my, button)) return true;
        if (tab == TAB_CRITERIA) {
            int cols = chipCols();
            int cw = (pw - 12) / cols;
            for (int i = 0; i < Criterion.COUNT; i++) {
                int cx = px + 6 + (i % cols) * cw;
                int cy = py + 6 + (i / cols) * 24;
                if (Ui.inside(mx, my, cx, cy, cw - 4, 22)) {
                    criterion = i;
                    scroll[TAB_CRITERIA] = 0;
                    minecraft.getSoundManager().play(SimpleSoundInstance.forUI(SoundEvents.UI_BUTTON_CLICK.value(), 1.3f, 0.35f));
                    return true;
                }
            }
        }
        if (tab == TAB_RANKING && rows.size() >= 2) {
            // clicking a mod in the ranking opens it in the comparison (left side)
            Scoring.Row r = rankingRowAt(mx, my);
            if (r != null) {
                compareA = rows.indexOf(r);
                if (compareB == compareA) compareB = compareA == 0 ? 1 : 0;
                tab = TAB_COMPARE;
                rebuildWidgets();
                return true;
            }
        }
        return false;
    }

    private Scoring.Row rankingRowAt(double mx, double my) {
        if (!Ui.inside(mx, my, px, viewY, pw, viewH)) return null;
        int idx = (int) ((my - viewY + scroll[TAB_RANKING]) / rankRowH());
        return idx >= 0 && idx < rows.size() ? rows.get(idx) : null;
    }

    // ------------------------------------------------------------------ rendering

    @Override
    public void renderBackground(GuiGraphics g, int mx, int my, float pt) {
        super.renderBackground(g, mx, my, pt);
        Ui.tickFrame();
        g.fillGradient(0, 0, width, 32, 0x90000000, 0x00000000);
        Ui.panel(g, px, py, pw, ph, Ui.alpha(Ui.GOLD, 0x70));
    }

    @Override
    public void render(GuiGraphics g, int mx, int my, float pt) {
        super.render(g, mx, my, pt);
        Ui.centeredScaled(g, font, Component.literal("★ ").append(title).append(" ★"), width / 2, 7, 1.5f, Ui.GOLD);
        MutableComponent sub = Component.empty().append(sourceName());
        if (source == SOURCE_SERVER && ClientHooks.serverData() != null) {
            sub.append(Component.literal(" • ")).append(Component.translatable("modcritic.results.players", ClientHooks.serverData().size()));
        }
        sub.append(Component.literal(" • ")).append(Component.translatable("modcritic.results.mods", rows.size()));
        g.drawCenteredString(font, sub, width / 2, 22, Ui.TEXT_DIM);

        clampScroll();
        if (rows.isEmpty()) {
            Component empty;
            if (source == SOURCE_MINE) empty = Component.translatable("modcritic.results.empty_mine");
            else if (ClientHooks.serverData() == null) empty = Component.translatable("modcritic.results.loading");
            else empty = Component.translatable("modcritic.results.empty_server");
            g.drawCenteredString(font, empty, px + pw / 2, py + ph / 2 - 4, Ui.TEXT_DIM);
        } else {
            switch (tab) {
                case TAB_RANKING -> renderRanking(g, mx, my);
                case TAB_CRITERIA -> renderCriteria(g, mx, my);
                default -> renderCompare(g, mx, my);
            }
        }

        if (status != null) {
            long age = Util.getMillis() - statusTime;
            if (age < 3500) {
                int a = age > 2800 ? (int) (255 * (1 - (age - 2800) / 700.0)) : 255;
                int w = font.width(status) + 16;
                int x = (width - w) / 2, y = height - 48;
                Ui.fillRounded(g, x, y, w, 16, Ui.alpha(0x101018, Math.min(230, a)));
                Ui.outlineRounded(g, x, y, w, 16, Ui.alpha(statusColor, a));
                if (a > 8) g.drawCenteredString(font, status, width / 2, y + 4, Ui.alpha(statusColor, a));
            } else {
                status = null;
            }
        }

        if (!rows.isEmpty() && tab == TAB_RANKING) {
            Scoring.Row r = rankingRowAt(mx, my);
            if (r != null) Ui.tooltip(g, font, rowTooltip(r), mx, my, 240);
        }
    }

    private List<Component> rowTooltip(Scoring.Row r) {
        List<Component> lines = new ArrayList<>();
        lines.add(Component.literal(r.modName).withStyle(ChatFormatting.GOLD));
        for (Criterion c : Criterion.values()) {
            double v = r.scores[c.ordinal()];
            lines.add(Component.translatable(c.nameKey()).withStyle(s -> s.withColor(c.color & 0xFFFFFF))
                    .append(Component.literal(": " + Scoring.fmt(v) + "  " + Scoring.textStars(v)).withStyle(ChatFormatting.GRAY)));
        }
        if (r.voters > 1) lines.add(Component.translatable("modcritic.results.votes", r.voters).withStyle(ChatFormatting.DARK_GRAY));
        for (String comment : r.comments) {
            lines.add(Component.literal("“" + comment + "”").withStyle(ChatFormatting.ITALIC, ChatFormatting.AQUA));
        }
        if (rows.size() >= 2) lines.add(Component.translatable("modcritic.results.click_compare").withStyle(ChatFormatting.DARK_GRAY));
        return lines;
    }

    private void medal(GuiGraphics g, int x, int y, int size, int rank) {
        int color = rank <= 3 ? MEDALS[rank - 1] : 0xFF3A3A50;
        Ui.fillRounded(g, x, y, size, size, Ui.darken(color, 0.15f));
        g.fillGradient(x + 1, y + 1, x + size - 1, y + size / 2, Ui.brighten(color, 0.35f), color);
        Ui.outlineRounded(g, x, y, size, size, Ui.darken(color, 0.5f));
        String t = String.valueOf(rank);
        g.drawString(font, t, x + (size - font.width(t)) / 2 + 1, y + (size - 8) / 2 + 1, rank <= 3 ? 0xFF2A1A00 : Ui.TEXT, false);
    }

    private void renderRanking(GuiGraphics g, int mx, int my) {
        int rh = rankRowH();
        int barW = Math.max(60, Math.min(170, pw / 4));
        int right = px + pw - 12;
        int barX = right - barW - 34;
        g.enableScissor(px + 2, viewY, px + pw - 2, viewY + viewH);
        int y = viewY - (int) scroll[TAB_RANKING];
        for (int i = 0; i < rows.size(); i++, y += rh) {
            if (y + rh < viewY || y > viewY + viewH) continue;
            Scoring.Row r = rows.get(i);
            int rank = i + 1;
            boolean hov = Ui.inside(mx, my, px + 4, y, pw - 8, rh) && Ui.inside(mx, my, px, viewY, pw, viewH);
            float ha = Ui.anim("rk:" + r.modId, hov);
            int base = rank <= 3 ? Ui.alpha(MEDALS[rank - 1], 0x22) : (i % 2 == 0 ? 0x12FFFFFF : 0x06FFFFFF);
            Ui.fillRounded(g, px + 4, y + 1, pw - 8, rh - 2, Ui.lerpColor(base, 0x30FFFFFF, ha));
            if (rank <= 3) g.fill(px + 4, y + 3, px + 6, y + rh - 3, MEDALS[rank - 1]);

            int ms = rh - 10;
            medal(g, px + 10, y + 5, ms, rank);
            int nx = px + 16 + ms;
            int nameMax = barX - nx - 10;
            int nameColor = rank == 1 ? 0xFFFFE9A8 : Ui.TEXT;
            g.drawString(font, Ui.ellipsize(font, r.modName, nameMax), nx + (int) (2 * ha), y + 5, nameColor, true);
            // badges
            int bx = nx;
            int by = y + rh - 14;
            for (Criterion c : Criterion.values()) {
                if (best[c.ordinal()] != r) continue;
                Component b = Component.translatable(c.badgeKey());
                int bw = Ui.badgeWidth(font, b);
                if (bx + bw > barX - 8) {
                    g.drawString(font, "+", bx, by + 2, Ui.TEXT_DIM, false);
                    break;
                }
                bx += Ui.badge(g, font, b, bx, by, c.color) + 3;
            }
            if (bx == nx && r.voters > 1) {
                g.drawString(font, Component.translatable("modcritic.results.votes", r.voters), nx, by + 2, Ui.TEXT_FAINT, false);
            } else if (bx == nx && !r.comments.isEmpty()) {
                g.drawString(font, Ui.ellipsize(font, "“" + r.comments.get(0) + "”", nameMax), nx, by + 2, 0xFF6FA8B8, false);
            }
            // total bar + value + stars
            Ui.bar(g, barX, y + 6, barW, 8, (float) (r.total / 10.0), Ui.scoreColor(r.total));
            String t = Scoring.fmt2(r.total);
            g.drawString(font, t, right - font.width(t), y + 6, Ui.scoreColor(r.total), true);
            Ui.stars(g, barX, y + rh - 12, r.total);
        }
        g.disableScissor();
        Ui.scrollbar(g, px + pw - 5, viewY, viewH, contentHeight(), viewH, scroll[TAB_RANKING]);
    }

    private void renderCriteria(GuiGraphics g, int mx, int my) {
        int cols = chipCols();
        int cw = (pw - 12) / cols;
        for (int i = 0; i < Criterion.COUNT; i++) {
            Criterion c = Criterion.values()[i];
            int cx = px + 6 + (i % cols) * cw;
            int cy = py + 6 + (i / cols) * 24;
            boolean sel = i == criterion;
            boolean hov = Ui.inside(mx, my, cx, cy, cw - 4, 22);
            float ha = Ui.anim("chip" + i, hov);
            float sa = Ui.anim("chipsel" + i, sel);
            int bg = Ui.lerpColor(0x90000000, Ui.alpha(Ui.darken(c.color, 0.55f), 0xE0), Math.max(sa, ha * 0.6f));
            Ui.fillRounded(g, cx, cy, cw - 4, 22, bg);
            Ui.outlineRounded(g, cx, cy, cw - 4, 22, Ui.lerpColor(Ui.alpha(c.color, 0x60), c.color, Math.max(sa, ha)));
            Scoring.Row w = best[i];
            Component head = w != null ? Component.literal("✦ ").append(Component.translatable(c.badgeKey())) : Component.translatable(c.nameKey());
            g.drawString(font, Ui.ellipsize(font, head.getString(), cw - 12), cx + 4, cy + 3, Ui.brighten(c.color, 0.4f), true);
            String winner = w == null ? "—" : w.modName + " • " + Scoring.fmt(w.scores[i]);
            g.drawString(font, Ui.ellipsize(font, winner, cw - 12), cx + 4, cy + 12, sel ? Ui.TEXT : Ui.TEXT_DIM, false);
        }

        Criterion c = Criterion.values()[criterion];
        int titleY = viewY - 14;
        g.drawString(font, Component.translatable("modcritic.results.chart", Component.translatable(c.nameKey())), px + 10, titleY, Ui.brighten(c.color, 0.3f), true);
        g.fill(px + 6, titleY + 10, px + pw - 6, titleY + 11, Ui.alpha(c.color, 0x50));

        List<Scoring.Row> sorted = new ArrayList<>(rows);
        final int ci = criterion;
        sorted.sort((a, b) -> Double.compare(b.scores[ci], a.scores[ci]));
        int labelW = Math.min(160, pw / 3);
        int barX = px + 12 + labelW;
        int barW = px + pw - 44 - barX;
        g.enableScissor(px + 2, viewY, px + pw - 2, viewY + viewH);
        int y = viewY - (int) scroll[TAB_CRITERIA];
        for (int i = 0; i < sorted.size(); i++, y += 14) {
            if (y + 14 < viewY || y > viewY + viewH) continue;
            Scoring.Row r = sorted.get(i);
            boolean hov = Ui.inside(mx, my, px + 4, y, pw - 8, 14) && Ui.inside(mx, my, px, viewY, pw, viewH);
            float ha = Ui.anim("cr:" + r.modId, hov);
            if (ha > 0.01f) Ui.fillRounded(g, px + 4, y, pw - 8, 14, Ui.alpha(0xFFFFFF, (int) (0x20 * ha)));
            String name = Ui.ellipsize(font, r.modName, labelW - 12);
            boolean top = best[ci] == r;
            g.drawString(font, name, barX - 6 - font.width(name), y + 3, top ? Ui.GOLD : Ui.TEXT, true);
            if (top) Ui.star(g, px + 8, y + 2, 1f);
            Ui.bar(g, barX, y + 3, barW, 9, (float) (r.scores[ci] / 10.0), c.color);
            String v = Scoring.fmt(r.scores[ci]);
            g.drawString(font, v, barX + barW + 6, y + 3, Ui.scoreColor(r.scores[ci]), true);
        }
        g.disableScissor();
        Ui.scrollbar(g, px + pw - 5, viewY, viewH, contentHeight(), viewH, scroll[TAB_CRITERIA]);
    }

    private void renderCompare(GuiGraphics g, int mx, int my) {
        if (rows.size() < 2) {
            g.drawCenteredString(font, Component.translatable("modcritic.compare.need_two"), px + pw / 2, py + ph / 2 - 4, Ui.TEXT_DIM);
            return;
        }
        Scoring.Row a = rows.get(compareA);
        Scoring.Row b = rows.get(compareB);
        int half = pw / 2;
        // selectors
        String an = Ui.ellipsize(font, a.modName, half - 60);
        String bn = Ui.ellipsize(font, b.modName, half - 60);
        g.drawCenteredString(font, an, px + half / 2 + 4, py + 10, Ui.brighten(Ui.COMPARE_A, 0.3f));
        g.drawCenteredString(font, bn, px + half + half / 2 - 4, py + 10, Ui.brighten(Ui.COMPARE_B, 0.3f));
        Ui.centeredScaled(g, font, Component.literal("VS"), px + half, py + 8, 1.3f, Ui.GOLD);

        int centerW = Math.min(110, pw / 4);
        int cx0 = px + half - centerW / 2;
        int barW = Math.max(30, cx0 - px - 44);
        int top = py + 30;
        int avail = py + ph - 40 - top;
        int rh = Math.max(12, Math.min(20, avail / Criterion.COUNT));
        int winsA = 0, winsB = 0;
        for (Criterion c : Criterion.values()) {
            int i = c.ordinal();
            int y = top + i * rh;
            double va = a.scores[i], vb = b.scores[i];
            if (va > vb + 1e-9) winsA++;
            else if (vb > va + 1e-9) winsB++;
            boolean hov = Ui.inside(mx, my, px + 4, y, pw - 8, rh);
            float ha = Ui.anim("cmp" + i, hov);
            g.fill(px + 4, y, px + pw - 4, y + rh, Ui.lerpColor(i % 2 == 0 ? 0x10FFFFFF : 0x04FFFFFF, Ui.alpha(c.color, 0x28), ha));
            Component label = Component.translatable(c.nameKey());
            String ls = Ui.ellipsize(font, label.getString(), centerW - 4);
            g.drawString(font, ls, px + half - font.width(ls) / 2, y + (rh - 8) / 2, Ui.brighten(c.color, 0.35f), true);
            int bh = Math.min(10, rh - 4);
            int by = y + (rh - bh) / 2;
            // A: grows to the left from the centre column
            Ui.barLeft(g, cx0 - 4 - barW, by, barW, bh, (float) (va / 10.0), Ui.COMPARE_A);
            // B: grows to the right
            Ui.bar(g, cx0 + centerW + 4, by, barW, bh, (float) (vb / 10.0), Ui.COMPARE_B);
            String sa = Scoring.fmt(va), sb = Scoring.fmt(vb);
            g.drawString(font, sa, cx0 - 8 - barW - font.width(sa), y + (rh - 8) / 2, va >= vb ? Ui.TEXT : Ui.TEXT_FAINT, true);
            g.drawString(font, sb, cx0 + centerW + 8 + barW, y + (rh - 8) / 2, vb >= va ? Ui.TEXT : Ui.TEXT_FAINT, true);
            if (va > vb + 1e-9) g.drawString(font, "◀", cx0 - 2 - font.width("◀"), y + (rh - 8) / 2, Ui.COMPARE_A, false);
            if (vb > va + 1e-9) g.drawString(font, "▶", cx0 + centerW + 2, y + (rh - 8) / 2, Ui.COMPARE_B, false);
        }

        // totals + verdict
        int ty = top + Criterion.COUNT * rh + 6;
        g.fill(px + 6, ty - 3, px + pw - 6, ty - 2, 0x30FFFFFF);
        String ta = Scoring.fmt2(a.total), tb = Scoring.fmt2(b.total);
        Ui.scaledText(g, font, Component.literal(ta), cx0 - 4 - (int) (font.width(ta) * 1.4f), ty, 1.4f, Ui.scoreColor(a.total), true);
        Ui.stars(g, cx0 - 4 - (int) (font.width(ta) * 1.4f) - 8 - Ui.STARS_WIDTH, ty + 1, a.total);
        Ui.scaledText(g, font, Component.literal(tb), cx0 + centerW + 4, ty, 1.4f, Ui.scoreColor(b.total), true);
        Ui.stars(g, cx0 + centerW + 4 + (int) (font.width(tb) * 1.4f) + 8, ty + 1, b.total);
        g.drawCenteredString(font, Component.translatable("modcritic.compare.total"), px + half, ty + 2, Ui.TEXT_DIM);

        Component verdict;
        if (Math.abs(a.total - b.total) < 0.005) {
            verdict = Component.translatable("modcritic.compare.tie", winsA, winsB);
        } else {
            Scoring.Row w = a.total > b.total ? a : b;
            int wins = a.total > b.total ? winsA : winsB;
            verdict = Component.translatable("modcritic.compare.verdict", w.modName, wins, Criterion.COUNT);
        }
        g.drawCenteredString(font, verdict, px + half, ty + 16, Ui.GOLD);
    }
}
