package com.williamgame.modcritic.client;

import com.williamgame.modcritic.Criterion;
import com.williamgame.modcritic.RatingEntry;
import com.williamgame.modcritic.Scoring;
import net.minecraft.ChatFormatting;
import net.minecraft.Util;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.components.Tooltip;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.network.chat.Component;
import net.minecraft.sounds.SoundEvents;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Main screen: mod list on the left, the rating editor (8 criteria sliders with stars + comment) on the right.
 */
public class CriticScreen extends Screen {
    private static final int ROW_H = 18;
    private static final int HEADER_H = 13;

    private final Screen parent;

    // state that survives re-init (resize)
    private String selectedId;
    private String search = "";
    private double listScroll;
    /** modId -> true = submit, false = remove; sent to the server on save. */
    private final Map<String, Boolean> pending = new LinkedHashMap<>();
    private Component status;
    private long statusTime;
    private int statusColor = Ui.GOOD;

    // layout
    private int lx, ly, lw, lh, rx, rw;
    private int listX, listY, listW, listH;
    private int rowsTop, rowH, labelW, sliderX, sliderW;
    private boolean showStars;

    // widgets
    private EditBox searchBox;
    private EditBox commentBox;
    private final StepSlider[] sliders = new StepSlider[Criterion.COUNT];
    private FancyButton resetButton;
    private boolean suppressResponders;

    private List<Item> items = new ArrayList<>();

    /** Mod list item: either a group header or a mod. */
    private record Item(Component header, ModCatalog.ModInfo mod) {
    }

    public CriticScreen(Screen parent) {
        super(Component.translatable("modcritic.title"));
        this.parent = parent;
    }

    // ------------------------------------------------------------------ init

    @Override
    protected void init() {
        LocalStore.get();
        if (selectedId == null) {
            List<ModCatalog.ModInfo> all = ModCatalog.all();
            if (!all.isEmpty()) selectedId = all.get(0).id();
        }

        int top = 34;
        int bottom = height - 32;
        lx = 8;
        ly = top;
        lw = Math.max(110, Math.min(180, (int) (width * 0.3)));
        lh = bottom - top;
        rx = lx + lw + 6;
        rw = width - 8 - rx;

        // search
        suppressResponders = true;
        searchBox = new EditBox(font, lx + 10, ly + 9, lw - 20, 10, Component.translatable("modcritic.search"));
        searchBox.setBordered(false);
        searchBox.setMaxLength(64);
        searchBox.setTextColor(0xEDEDF5);
        searchBox.setHint(Component.translatable("modcritic.search").withStyle(ChatFormatting.DARK_GRAY));
        searchBox.setValue(search);
        searchBox.setResponder(s -> {
            if (suppressResponders) return;
            search = s;
            listScroll = 0;
            rebuildItems();
        });
        addRenderableWidget(searchBox);

        listX = lx + 4;
        listY = ly + 26;
        listW = lw - 8;
        listH = lh - 30;

        // criteria rows
        rowsTop = ly + 46;
        int commentArea = 34;
        int area = ly + lh - commentArea - rowsTop;
        rowH = Math.max(13, Math.min(22, area / Criterion.COUNT));
        labelW = 0;
        for (Criterion c : Criterion.values()) {
            labelW = Math.max(labelW, font.width(Component.translatable(c.nameKey())) + 12);
        }
        labelW = Math.min(labelW, Math.max(60, rw / 3));
        showStars = rw >= 260;
        int valueW = 18;
        sliderX = rx + 10 + labelW + 4;
        sliderW = rw - 20 - labelW - 4 - valueW - (showStars ? Ui.STARS_WIDTH + 6 : 0);
        sliderW = Math.max(40, sliderW);
        int sh = Math.max(9, Math.min(14, rowH - 4));
        for (Criterion c : Criterion.values()) {
            final int idx = c.ordinal();
            int y = rowsTop + idx * rowH + (rowH - sh) / 2;
            StepSlider s = new StepSlider(sliderX, y, sliderW, sh, 9, Criterion.DEFAULT_SCORE - 1, c.color,
                    step -> onScore(idx, step + 1));
            sliders[idx] = s;
            addRenderableWidget(s);
        }

        // comment
        commentBox = new EditBox(font, rx + 14, ly + lh - 22, rw - 28, 10, Component.translatable("modcritic.comment"));
        commentBox.setBordered(false);
        commentBox.setMaxLength(RatingEntry.MAX_COMMENT);
        commentBox.setTextColor(0xEDEDF5);
        commentBox.setHint(Component.translatable("modcritic.comment.hint").withStyle(ChatFormatting.DARK_GRAY));
        commentBox.setResponder(this::onComment);
        addRenderableWidget(commentBox);

        // bottom buttons
        int by = height - 26;
        int n = 5;
        int gap = 4;
        int bw = Math.min(110, (width - 16 - gap * (n - 1)) / n);
        int bx = (width - (bw * n + gap * (n - 1))) / 2;
        FancyButton save = new FancyButton(bx, by, bw, 20, Component.translatable("modcritic.button.save"), Ui.GOOD, b -> saveAll(true));
        save.setTooltip(Tooltip.create(Component.translatable("modcritic.button.save.tooltip")));
        addRenderableWidget(save);
        resetButton = new FancyButton(bx + (bw + gap), by, bw, 20, Component.translatable("modcritic.button.reset"), Ui.BAD, b -> resetSelected());
        resetButton.setTooltip(Tooltip.create(Component.translatable("modcritic.button.reset.tooltip")));
        addRenderableWidget(resetButton);
        addRenderableWidget(new FancyButton(bx + (bw + gap) * 2, by, bw, 20, Component.translatable("modcritic.button.weights"), 0xFF9B6BE0, b -> {
            saveAll(false);
            minecraft.setScreen(new WeightsScreen(this));
        }));
        addRenderableWidget(new FancyButton(bx + (bw + gap) * 3, by, bw, 20, Component.translatable("modcritic.button.results"), Ui.GOLD, b -> {
            saveAll(false);
            minecraft.setScreen(new ResultsScreen(this, ResultsScreen.SOURCE_MINE));
        }));
        addRenderableWidget(new FancyButton(bx + (bw + gap) * 4, by, bw, 20, Component.translatable("modcritic.button.done"), 0xFF8A8AB0, b -> onClose()));

        suppressResponders = false;
        rebuildItems();
        loadSelected();
    }

    private void rebuildItems() {
        items = new ArrayList<>();
        String q = search.trim().toLowerCase(Locale.ROOT);
        boolean pinnedHeader = false, otherHeader = false;
        for (ModCatalog.ModInfo m : ModCatalog.all()) {
            if (!q.isEmpty() && !m.name().toLowerCase(Locale.ROOT).contains(q) && !m.id().toLowerCase(Locale.ROOT).contains(q)) continue;
            if (m.pinned() && !pinnedHeader) {
                items.add(new Item(Component.translatable("modcritic.list.pack"), null));
                pinnedHeader = true;
            } else if (!m.pinned() && !otherHeader) {
                items.add(new Item(Component.translatable("modcritic.list.other"), null));
                otherHeader = true;
            }
            items.add(new Item(null, m));
        }
        clampScroll();
    }

    private int itemHeight(Item it) {
        return it.header() != null ? HEADER_H : ROW_H;
    }

    private int contentHeight() {
        int h = 0;
        for (Item it : items) h += itemHeight(it);
        return h;
    }

    private void clampScroll() {
        int max = Math.max(0, contentHeight() - listH);
        listScroll = Math.max(0, Math.min(max, listScroll));
    }

    // ------------------------------------------------------------------ editing

    private ModCatalog.ModInfo selectedMod() {
        return selectedId == null ? null : ModCatalog.find(selectedId);
    }

    private void select(String id) {
        if (id.equals(selectedId)) return;
        selectedId = id;
        loadSelected();
        minecraft.getSoundManager().play(SimpleSoundInstance.forUI(SoundEvents.UI_BUTTON_CLICK.value(), 1.4f, 0.35f));
    }

    /** Pushes the selected mod's rating into the widgets. */
    private void loadSelected() {
        suppressResponders = true;
        RatingEntry e = selectedId == null ? null : LocalStore.rating(selectedId);
        for (Criterion c : Criterion.values()) {
            StepSlider s = sliders[c.ordinal()];
            s.setStepSilently((e == null ? Criterion.DEFAULT_SCORE : e.scores[c.ordinal()]) - 1);
            s.setDim(e == null);
            s.active = selectedId != null;
        }
        commentBox.setValue(e == null ? "" : e.comment);
        commentBox.setEditable(selectedId != null);
        resetButton.active = e != null;
        suppressResponders = false;
    }

    /** Returns the entry of the selected mod, creating it (all defaults) on first edit. */
    private RatingEntry editable() {
        if (selectedId == null) return null;
        RatingEntry e = LocalStore.rating(selectedId);
        if (e == null) {
            ModCatalog.ModInfo m = selectedMod();
            e = new RatingEntry(selectedId, m == null ? selectedId : m.name());
            LocalStore.put(e);
            for (StepSlider s : sliders) s.setDim(false);
            resetButton.active = true;
        }
        return e;
    }

    private void onScore(int criterion, int score) {
        if (suppressResponders) return;
        RatingEntry e = editable();
        if (e == null) return;
        e.scores[criterion] = Criterion.clampScore(score);
        e.time = System.currentTimeMillis();
        pending.put(e.modId, true);
    }

    private void onComment(String text) {
        if (suppressResponders || selectedId == null) return;
        RatingEntry existing = LocalStore.rating(selectedId);
        if (existing == null && text.isBlank()) return;
        RatingEntry e = editable();
        e.comment = text;
        e.time = System.currentTimeMillis();
        pending.put(e.modId, true);
    }

    private void resetSelected() {
        if (selectedId == null) return;
        RatingEntry e = LocalStore.rating(selectedId);
        if (e == null) return;
        LocalStore.remove(selectedId);
        pending.put(selectedId, false);
        loadSelected();
        setStatus(Component.translatable("modcritic.status.reset", e.modName), Ui.BAD);
    }

    /** Writes ratings.json and sends pending changes to the server (if it has the mod). */
    private void saveAll(boolean announce) {
        boolean ok = LocalStore.save();
        int sent = 0;
        if (ClientNet.serverHasMod()) {
            for (Map.Entry<String, Boolean> p : pending.entrySet()) {
                if (p.getValue()) {
                    RatingEntry e = LocalStore.rating(p.getKey());
                    if (e != null && ClientNet.submit(e)) sent++;
                } else {
                    ModCatalog.ModInfo m = ModCatalog.find(p.getKey());
                    if (ClientNet.remove(p.getKey(), m == null ? p.getKey() : m.name())) sent++;
                }
            }
            pending.clear();
        }
        if (!announce) return;
        if (!ok) {
            setStatus(Component.translatable("modcritic.status.save_failed"), Ui.BAD);
        } else if (sent > 0) {
            setStatus(Component.translatable("modcritic.status.saved_sent", sent), Ui.GOOD);
        } else {
            setStatus(Component.translatable("modcritic.status.saved"), Ui.GOOD);
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
        saveAll(false);
        minecraft.setScreen(parent);
    }

    // ------------------------------------------------------------------ input

    @Override
    public boolean mouseClicked(double mx, double my, int button) {
        if (super.mouseClicked(mx, my, button)) return true;
        if (button == 0 && Ui.inside(mx, my, listX, listY, listW, listH)) {
            Item it = itemAt(mx, my);
            if (it != null && it.mod() != null) {
                setFocused(null);
                select(it.mod().id());
                return true;
            }
        }
        return false;
    }

    private Item itemAt(double mx, double my) {
        if (!Ui.inside(mx, my, listX, listY, listW, listH)) return null;
        int y = listY - (int) listScroll;
        for (Item it : items) {
            int h = itemHeight(it);
            if (my >= y && my < y + h) return it;
            y += h;
        }
        return null;
    }

    @Override
    public boolean mouseScrolled(double mx, double my, double sx, double sy) {
        if (Ui.inside(mx, my, lx, ly, lw, lh)) {
            listScroll -= sy * ROW_H * 1.5;
            clampScroll();
            return true;
        }
        return super.mouseScrolled(mx, my, sx, sy);
    }

    @Override
    public boolean keyPressed(int key, int scan, int modifiers) {
        // Up/Down walk through the mod list when no text box is focused.
        boolean typing = (searchBox != null && searchBox.isFocused()) || (commentBox != null && commentBox.isFocused());
        if (!typing && (key == org.lwjgl.glfw.GLFW.GLFW_KEY_UP || key == org.lwjgl.glfw.GLFW.GLFW_KEY_DOWN)) {
            List<ModCatalog.ModInfo> mods = new ArrayList<>();
            for (Item it : items) if (it.mod() != null) mods.add(it.mod());
            int idx = -1;
            for (int i = 0; i < mods.size(); i++) if (mods.get(i).id().equals(selectedId)) idx = i;
            int next = Math.max(0, Math.min(mods.size() - 1, idx + (key == org.lwjgl.glfw.GLFW.GLFW_KEY_UP ? -1 : 1)));
            if (!mods.isEmpty()) {
                select(mods.get(next).id());
                ensureVisible(selectedId);
            }
            return true;
        }
        return super.keyPressed(key, scan, modifiers);
    }

    private void ensureVisible(String id) {
        int y = 0;
        for (Item it : items) {
            if (it.mod() != null && it.mod().id().equals(id)) {
                if (y < listScroll) listScroll = Math.max(0, y - HEADER_H);
                else if (y + ROW_H > listScroll + listH) listScroll = y + ROW_H - listH;
                clampScroll();
                return;
            }
            y += itemHeight(it);
        }
    }

    @Override
    public boolean isPauseScreen() {
        return true;
    }

    // ------------------------------------------------------------------ rendering

    @Override
    public void renderBackground(GuiGraphics g, int mx, int my, float pt) {
        super.renderBackground(g, mx, my, pt);
        Ui.tickFrame();
        // title bar glow
        g.fillGradient(0, 0, width, 32, 0x90000000, 0x00000000);
        Ui.panel(g, lx, ly, lw, lh);
        Ui.panel(g, rx, ly, rw, lh, Ui.alpha(Ui.GOLD, 0x70));
        // search box
        float sf = Ui.anim(searchBox, searchBox.isFocused());
        Ui.fillRounded(g, lx + 6, ly + 5, lw - 12, 16, 0xC0000000);
        Ui.outlineRounded(g, lx + 6, ly + 5, lw - 12, 16, Ui.lerpColor(0xFF3A3A50, Ui.GOLD, sf));
        // comment box
        float cf = Ui.anim(commentBox, commentBox.isFocused());
        Ui.fillRounded(g, rx + 10, ly + lh - 26, rw - 20, 18, 0xC0000000);
        Ui.outlineRounded(g, rx + 10, ly + lh - 26, rw - 20, 18, Ui.lerpColor(0xFF3A3A50, 0xFF45B0EA, cf));
        // row stripes behind sliders
        for (int i = 0; i < Criterion.COUNT; i++) {
            int y = rowsTop + i * rowH;
            boolean hov = Ui.inside(mx, my, rx + 4, y, rw - 8, rowH);
            float a = Ui.anim("row" + i, hov);
            int base = (i % 2 == 0) ? 0x14FFFFFF : 0x08FFFFFF;
            g.fill(rx + 4, y, rx + rw - 4, y + rowH, Ui.lerpColor(base, Ui.alpha(Criterion.values()[i].color, 0x30), a));
        }
    }

    @Override
    public void render(GuiGraphics g, int mx, int my, float pt) {
        super.render(g, mx, my, pt);

        // ---- header
        Ui.centeredScaled(g, font, Component.literal("★ ").append(title).append(" ★"), width / 2, 7, 1.5f, Ui.GOLD);
        Component online = ClientNet.serverHasMod()
                ? Component.translatable("modcritic.status.online")
                : ClientNet.inWorld() ? Component.translatable("modcritic.status.offline_server") : Component.translatable("modcritic.status.local");
        g.drawCenteredString(font, online, width / 2, 22, ClientNet.serverHasMod() ? 0xFF7FE08A : Ui.TEXT_DIM);

        renderList(g, mx, my);
        renderEditor(g, mx, my);

        // ---- status toast
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

        renderTooltips(g, mx, my);
    }

    private void renderList(GuiGraphics g, int mx, int my) {
        g.enableScissor(listX, listY, listX + listW, listY + listH);
        int y = listY - (int) listScroll;
        for (Item it : items) {
            int h = itemHeight(it);
            if (y + h >= listY && y <= listY + listH) {
                if (it.header() != null) {
                    g.drawString(font, it.header(), listX + 4, y + 3, Ui.GOLD_DARK, false);
                    int tw = font.width(it.header());
                    g.fill(listX + 8 + tw, y + 7, listX + listW - 6, y + 8, 0x40FFC94A);
                } else {
                    renderModRow(g, it.mod(), listX, y, listW - 4, h, mx, my);
                }
            }
            y += h;
        }
        if (items.isEmpty()) {
            g.drawCenteredString(font, Component.translatable("modcritic.list.empty"), listX + listW / 2, listY + 10, Ui.TEXT_DIM);
        }
        g.disableScissor();
        Ui.scrollbar(g, listX + listW - 3, listY, listH, contentHeight(), listH, listScroll);
    }

    private void renderModRow(GuiGraphics g, ModCatalog.ModInfo m, int x, int y, int w, int h, int mx, int my) {
        boolean selected = m.id().equals(selectedId);
        boolean hovered = Ui.inside(mx, my, x, y, w, h) && Ui.inside(mx, my, listX, listY, listW, listH);
        float ha = Ui.anim("mod:" + m.id(), hovered);
        float sa = Ui.anim("sel:" + m.id(), selected);
        int bg = Ui.lerpColor(0x00FFFFFF, 0x26FFFFFF, ha);
        bg = Ui.lerpColor(bg, 0x40FFC94A, sa);
        if ((bg >>> 24) > 0) Ui.fillRounded(g, x + 1, y + 1, w - 2, h - 2, bg);
        if (sa > 0.01f) {
            int sh = (int) ((h - 4) * sa);
            g.fill(x + 1, y + (h - sh) / 2, x + 3, y + (h + sh) / 2, Ui.GOLD);
        }
        RatingEntry e = LocalStore.rating(m.id());
        int textX = x + 6 + (int) (2 * ha);
        if (m.pinned()) {
            Ui.star(g, textX, y + (h - 9) / 2, 1f);
            textX += 12;
        }
        String scoreText = e == null ? "—" : Scoring.fmt(Scoring.weighted(e.scoresAsDouble(), LocalStore.weights()));
        int scoreW = font.width(scoreText);
        int nameMax = x + w - 8 - scoreW - textX;
        int nameColor = !m.installed() ? Ui.TEXT_FAINT : selected ? 0xFFFFE9A8 : Ui.lerpColor(Ui.TEXT, 0xFFFFFFFF, ha);
        g.drawString(font, Ui.ellipsize(font, m.name(), nameMax), textX, y + (h - 8) / 2, nameColor, true);
        int sc = e == null ? Ui.TEXT_FAINT : Ui.scoreColor(Scoring.weighted(e.scoresAsDouble(), LocalStore.weights()));
        g.drawString(font, scoreText, x + w - 4 - scoreW, y + (h - 8) / 2, sc, true);
    }

    private void renderEditor(GuiGraphics g, int mx, int my) {
        ModCatalog.ModInfo m = selectedMod();
        if (m == null) {
            g.drawCenteredString(font, Component.translatable("modcritic.list.empty"), rx + rw / 2, ly + 20, Ui.TEXT_DIM);
            return;
        }
        RatingEntry e = LocalStore.rating(m.id());
        int x = rx + 10;
        // name
        int totalW = showStars ? Ui.STARS_WIDTH + 44 : 40;
        String name = Ui.ellipsize(font, m.name(), (int) ((rw - 24 - totalW) / 1.4f));
        Ui.scaledText(g, font, Component.literal(name), x, ly + 8, 1.4f, m.pinned() ? Ui.GOLD : Ui.TEXT, true);
        // id / version / description
        String sub = m.id() + (m.version().isEmpty() ? "" : "  v" + m.version());
        if (!m.installed()) sub += "  " + Component.translatable("modcritic.list.not_installed").getString();
        if (!m.description().isEmpty()) sub += "  —  " + m.description().replace('\n', ' ');
        g.drawString(font, Ui.ellipsize(font, sub, rw - 24 - totalW), x, ly + 24, Ui.TEXT_FAINT, false);

        // total
        double total = e == null ? 0 : Scoring.weighted(e.scoresAsDouble(), LocalStore.weights());
        int right = rx + rw - 10;
        if (e != null) {
            String t = Scoring.fmt(total);
            int tw = (int) (font.width(t) * 1.6f);
            Ui.scaledText(g, font, Component.literal(t), right - tw, ly + 6, 1.6f, Ui.scoreColor(total), true);
            if (showStars) Ui.stars(g, right - tw - 6 - Ui.STARS_WIDTH, ly + 8, total);
            g.drawString(font, Component.translatable("modcritic.editor.weighted"), right - font.width(Component.translatable("modcritic.editor.weighted")), ly + 24, Ui.TEXT_FAINT, false);
        } else {
            Component nr = Component.translatable("modcritic.editor.not_rated");
            g.drawString(font, nr, right - font.width(nr), ly + 10, Ui.TEXT_DIM, true);
        }
        g.fill(rx + 6, ly + 38, rx + rw - 6, ly + 39, 0x30FFFFFF);

        // criteria labels, values, stars
        for (Criterion c : Criterion.values()) {
            int i = c.ordinal();
            int y = rowsTop + i * rowH;
            int cy = y + (rowH - 8) / 2;
            g.fill(x, cy + 1, x + 6, cy + 7, c.color);
            g.fill(x, cy + 1, x + 6, cy + 2, Ui.brighten(c.color, 0.5f));
            Component label = Component.translatable(c.nameKey());
            g.drawString(font, Ui.ellipsize(font, label.getString(), labelW - 12), x + 10, cy, e == null ? Ui.TEXT_DIM : Ui.TEXT, true);
            int score = sliders[i].getStep() + 1;
            int vx = sliderX + sliderW + 6;
            String v = String.valueOf(score);
            g.drawString(font, v, vx + (12 - font.width(v)) / 2, cy, e == null ? Ui.TEXT_FAINT : Ui.scoreColor(score), true);
            if (showStars) {
                Ui.stars(g, vx + 18, y + (rowH - 9) / 2, e == null ? 0 : score);
            }
        }
        String cnt = commentBox.getValue().length() + "/" + RatingEntry.MAX_COMMENT;
        if (commentBox.isFocused()) {
            g.drawString(font, cnt, rx + rw - 12 - font.width(cnt), ly + lh - 36, Ui.TEXT_FAINT, false);
        }
    }

    private void renderTooltips(GuiGraphics g, int mx, int my) {
        // criterion description
        for (Criterion c : Criterion.values()) {
            int y = rowsTop + c.ordinal() * rowH;
            if (Ui.inside(mx, my, rx + 8, y, labelW, rowH)) {
                List<Component> lines = new ArrayList<>();
                lines.add(Component.translatable(c.nameKey()).withStyle(s -> s.withColor(c.color & 0xFFFFFF)));
                lines.add(Component.translatable(c.descKey()).withStyle(ChatFormatting.GRAY));
                Ui.tooltip(g, font, lines, mx, my, 200);
                return;
            }
        }
        // mod details
        Item it = itemAt(mx, my);
        if (it != null && it.mod() != null) {
            ModCatalog.ModInfo m = it.mod();
            List<Component> lines = new ArrayList<>();
            lines.add(Component.literal(m.name()).withStyle(m.pinned() ? ChatFormatting.GOLD : ChatFormatting.WHITE));
            lines.add(Component.literal(m.id() + (m.version().isEmpty() ? "" : " • v" + m.version())).withStyle(ChatFormatting.DARK_GRAY));
            if (!m.installed()) lines.add(Component.translatable("modcritic.list.not_installed").withStyle(ChatFormatting.RED));
            if (!m.description().isEmpty()) {
                String d = m.description();
                if (d.length() > 300) d = d.substring(0, 300) + "…";
                lines.add(Component.literal(d).withStyle(ChatFormatting.GRAY));
            }
            RatingEntry e = LocalStore.rating(m.id());
            if (e != null && !e.comment.isBlank()) {
                lines.add(Component.literal("“" + e.comment + "”").withStyle(ChatFormatting.ITALIC, ChatFormatting.AQUA));
            }
            Ui.tooltip(g, font, lines, mx, my, 220);
        }
    }
}
