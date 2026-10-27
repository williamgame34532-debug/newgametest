package com.williamgame.hideandhunt.client;

import com.williamgame.hideandhunt.game.GameSettings;
import com.williamgame.hideandhunt.game.Phase;
import com.williamgame.hideandhunt.game.Side;
import com.williamgame.hideandhunt.network.HHNetwork;
import com.williamgame.hideandhunt.network.TabletActionPacket;
import net.minecraft.ChatFormatting;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractSliderButton;
import net.minecraft.client.gui.components.AbstractWidget;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.components.Tooltip;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.Tag;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.util.Mth;

import java.util.ArrayList;
import java.util.List;

/**
 * Game Master Tablet: tabbed editor for the arena. Every change is sent to the server as a
 * {@link TabletActionPacket}; the server checks operator permission, applies it and sends fresh data back.
 * Rows shrink to fit small GUI scales; destructive buttons need a second click; changed settings are marked
 * with a yellow dot and a right-click resets them to the default.
 */
public class TabletScreen extends Screen {
    private enum UiTab { ARENA, PLAYERS, TEAMS, TIMERS, RULES }

    private static UiTab lastTab = UiTab.ARENA;
    private static final int CONFIRM_TICKS = 60;

    private CompoundTag data;
    private GameSettings settings;
    private UiTab tab = lastTab;
    private int rosterPage;
    private int ticks;

    private int px, py, pw, ph, cy, colW, rowH, widgetH;
    private int activeTabX, activeTabW;
    private EditBox nameBox;
    private final List<SettingSlider> sliders = new ArrayList<>();
    private final List<RosterRow> rosterRows = new ArrayList<>();
    private final List<SettingWidget> settingWidgets = new ArrayList<>();

    private String confirmId;
    private int confirmTick;
    private Button confirmButton;
    private Component confirmLabel;

    private record RosterRow(String name, int side, boolean inArena, int y) {}

    private record SettingWidget(AbstractWidget widget, GameSettings.Def def) {}

    public TabletScreen(CompoundTag data) {
        super(Component.translatable("hideandhunt.gui.title"));
        setData(data);
    }

    private void setData(CompoundTag d) {
        this.data = d;
        this.settings = GameSettings.fromTag(d.getCompound("settings"));
    }

    /** Fresh data from the server. */
    public void updateData(CompoundTag d) {
        setData(d);
        for (SettingSlider s : sliders) if (s.pending) return; // don't yank a slider the user is still moving
        String typed = nameBox != null && nameBox.isFocused() ? nameBox.getValue() : null;
        rebuildWidgets();
        if (typed != null && nameBox != null) {
            nameBox.setValue(typed);
            nameBox.setFocused(true);
            setFocused(nameBox);
        }
    }

    private static void send(String action, String key, String value) {
        HHNetwork.sendToServer(new TabletActionPacket(action, key, value));
    }

    private static MutableComponent tr(String key, Object... args) {
        return Component.translatable("hideandhunt.gui." + key, args);
    }

    // ================================================================== layout

    private int rowsFor(UiTab t) {
        return switch (t) {
            case ARENA -> 8;
            case PLAYERS -> 7;
            case TEAMS -> (GameSettings.defs(GameSettings.Tab.TEAMS).size() + 1) / 2 + 2;
            case TIMERS -> (GameSettings.defs(GameSettings.Tab.TIMERS).size() + 1) / 2;
            case RULES -> (GameSettings.defs(GameSettings.Tab.RULES).size() + 1) / 2;
        };
    }

    @Override
    protected void init() {
        sliders.clear();
        rosterRows.clear();
        settingWidgets.clear();
        nameBox = null;
        confirmId = null;
        confirmButton = null;
        pw = Math.min(380, width - 16);
        ph = Math.min(252, height - 16);
        px = (width - pw) / 2;
        py = (height - ph) / 2;
        cy = py + 46;
        colW = (pw - 24) / 2;
        int avail = (py + ph - 30) - cy;
        rowH = Mth.clamp(avail / Math.max(1, rowsFor(tab)), 16, 22);
        widgetH = rowH - 2;

        // tabs: the current one stays clickable-looking and gets a gold underline (drawn in renderBackground)
        UiTab[] tabs = UiTab.values();
        int tw = (pw - 16) / tabs.length;
        for (int i = 0; i < tabs.length; i++) {
            UiTab t = tabs[i];
            MutableComponent label = tr("tab." + t.name().toLowerCase(java.util.Locale.ROOT));
            if (t == tab) label = label.withStyle(ChatFormatting.YELLOW, ChatFormatting.BOLD);
            Button b = Button.builder(label, btn -> {
                if (tab == t) return;
                tab = t;
                lastTab = t;
                rosterPage = 0;
                rebuildWidgets();
            }).bounds(px + 8 + i * tw, py + 22, tw - 2, 18).build();
            if (t == tab) {
                activeTabX = px + 8 + i * tw;
                activeTabW = tw - 2;
            }
            addRenderableWidget(b);
        }

        switch (tab) {
            case ARENA -> initArena();
            case PLAYERS -> initPlayers();
            case TEAMS -> {
                int row = settingWidgets(GameSettings.Tab.TEAMS, 0);
                kitButtons(row);
            }
            case TIMERS -> settingWidgets(GameSettings.Tab.TIMERS, 0);
            case RULES -> settingWidgets(GameSettings.Tab.RULES, 0);
        }

        // bottom game controls
        int bw = (pw - 16) / 4;
        int by = py + ph - 24;
        Phase phase = Phase.byOrdinal(data.getInt("phase"));
        Button start = Button.builder(tr("start").withStyle(ChatFormatting.GREEN), b -> send("game", "start", ""))
                .bounds(px + 8, by, bw - 2, 18).build();
        start.active = phase == Phase.LOBBY;
        addRenderableWidget(start);
        Button stop = Button.builder(tr("stop").withStyle(ChatFormatting.RED), b -> send("game", "stop", ""))
                .bounds(px + 8 + bw, by, bw - 2, 18).build();
        stop.active = phase != Phase.LOBBY;
        addRenderableWidget(stop);
        Button rnd = Button.builder(tr("randomize").withStyle(ChatFormatting.GOLD), b -> send("game", "randomize", ""))
                .bounds(px + 8 + bw * 2, by, bw - 2, 18).tooltip(Tooltip.create(tr("randomize.desc"))).build();
        rnd.active = phase == Phase.LOBBY;
        addRenderableWidget(rnd);
        addRenderableWidget(Button.builder(tr("close"), b -> onClose()).bounds(px + 8 + bw * 3, by, bw - 2, 18).build());
    }

    private int colX(int col) {
        return px + 8 + col * (colW + 8);
    }

    private int rowY(int row) {
        return cy + row * rowH;
    }

    private Button action(int col, int row, Component label, Component tooltip, Runnable r) {
        Button.Builder b = Button.builder(label, btn -> r.run()).bounds(colX(col), rowY(row), colW, widgetH);
        if (tooltip != null) b.tooltip(Tooltip.create(tooltip));
        return addRenderableWidget(b.build());
    }

    /** A destructive action: the first click turns the button into "Sure?", the second one (within 3 s) runs it. */
    private Button confirmAction(int col, int row, Component label, Component tooltip, String id, Runnable r) {
        Button.Builder b = Button.builder(label, btn -> {
            if (id.equals(confirmId) && ticks - confirmTick < CONFIRM_TICKS) {
                resetConfirm();
                r.run();
            } else {
                resetConfirm();
                confirmId = id;
                confirmTick = ticks;
                confirmButton = btn;
                confirmLabel = label;
                btn.setMessage(tr("confirm").withStyle(ChatFormatting.RED, ChatFormatting.BOLD));
            }
        }).bounds(colX(col), rowY(row), colW, widgetH);
        b.tooltip(Tooltip.create(tooltip != null ? tooltip.copy().append("\n").append(tr("confirm.desc").withStyle(ChatFormatting.GRAY))
                : tr("confirm.desc")));
        return addRenderableWidget(b.build());
    }

    private void resetConfirm() {
        if (confirmButton != null && confirmLabel != null) confirmButton.setMessage(confirmLabel);
        confirmId = null;
        confirmButton = null;
        confirmLabel = null;
    }

    private void initArena() {
        nameBox = new EditBox(font, colX(0), rowY(0) + 1, colW, widgetH - 2, tr("name"));
        nameBox.setMaxLength(32);
        nameBox.setValue(data.getString("name"));
        nameBox.setHint(tr("name").withStyle(ChatFormatting.DARK_GRAY));
        addRenderableWidget(nameBox);
        action(1, 0, tr("rename"), null, () -> send("name", "", nameBox.getValue()));
        int row = settingWidgets(GameSettings.Tab.ARENA, 1);

        int hs = data.getInt("hiderSpawns"), ks = data.getInt("hunterSpawns");
        String lobby = data.getString("lobby"), spect = data.getString("spectator");
        action(0, row, tr("set_lobby").withStyle(lobby.isEmpty() ? ChatFormatting.YELLOW : ChatFormatting.WHITE),
                tr("current", lobby.isEmpty() ? tr("not_set") : Component.literal(lobby)), () -> send("spawn", "lobby", ""));
        action(1, row++, tr("set_spectator"),
                tr("current", spect.isEmpty() ? tr("not_set") : Component.literal(spect)), () -> send("spawn", "spectator", ""));
        action(0, row, tr("add_hider", hs).withStyle(hs == 0 ? ChatFormatting.YELLOW : ChatFormatting.GREEN), tr("add_spawn.desc"),
                () -> send("spawn", "hider_add", ""));
        action(1, row++, tr("add_hunter", ks).withStyle(ks == 0 ? ChatFormatting.YELLOW : ChatFormatting.RED), tr("add_spawn.desc"),
                () -> send("spawn", "hunter_add", ""));
        confirmAction(0, row, tr("clear_hiders"), null, "clear_hiders", () -> send("spawn", "hider_clear", ""));
        confirmAction(1, row++, tr("clear_hunters"), null, "clear_hunters", () -> send("spawn", "hunter_clear", ""));
        String a = data.getString("cornerA"), b = data.getString("cornerB");
        action(0, row, tr("bounds1"), tr("current", a.isEmpty() ? tr("not_set") : Component.literal(a)).append("\n").append(tr("bounds.desc")),
                () -> send("bounds", "pos1", ""));
        action(1, row++, tr("bounds2"), tr("current", b.isEmpty() ? tr("not_set") : Component.literal(b)).append("\n").append(tr("bounds.desc")),
                () -> send("bounds", "pos2", ""));
        confirmAction(0, row, tr("bounds_clear"), null, "bounds_clear", () -> send("bounds", "clear", ""));
        action(1, row++, tr("tp_lobby"), null, () -> send("game", "tp_lobby", ""));
        action(0, row, tr("show").withStyle(ChatFormatting.AQUA), tr("show.desc"), () -> send("game", "show", ""));
        Button test = action(1, row, tr("test").withStyle(ChatFormatting.AQUA), tr("test.desc"), () -> send("game", "test", ""));
        test.active = Phase.byOrdinal(data.getInt("phase")) == Phase.LOBBY;
    }

    private void kitButtons(int row) {
        int hk = data.getInt("hiderKit"), kk = data.getInt("hunterKit");
        action(0, row, tr("kit_hider_set", hk), tr("kit_set.desc"), () -> send("kit", "hiders", "set"));
        action(1, row++, tr("kit_hunter_set", kk), tr("kit_set.desc"), () -> send("kit", "hunters", "set"));
        confirmAction(0, row, tr("kit_hider_clear"), null, "kit_hider_clear", () -> send("kit", "hiders", "clear"));
        confirmAction(1, row, tr("kit_hunter_clear"), null, "kit_hunter_clear", () -> send("kit", "hunters", "clear"));
    }

    private int rosterPerPage() {
        return Math.max(1, ((py + ph - 30) - (cy + rowH + 4)) / 20);
    }

    private void initPlayers() {
        Phase phase = Phase.byOrdinal(data.getInt("phase"));
        confirmAction(0, 0, tr("reset_teams"), tr("reset_teams.desc"), "reset_teams", () -> send("game", "reset_teams", ""));
        ListTag roster = data.getList("roster", Tag.TAG_COMPOUND);
        int per = rosterPerPage();
        int pages = Math.max(1, (roster.size() + per - 1) / per);
        rosterPage = Mth.clamp(rosterPage, 0, pages - 1);
        Button prev = Button.builder(Component.literal("<"), b -> {
            rosterPage--;
            rebuildWidgets();
        }).bounds(colX(1), rowY(0), 20, widgetH).build();
        prev.active = rosterPage > 0;
        addRenderableWidget(prev);
        Button next = Button.builder(Component.literal(">"), b -> {
            rosterPage++;
            rebuildWidgets();
        }).bounds(colX(1) + colW - 20, rowY(0), 20, widgetH).build();
        next.active = rosterPage < pages - 1;
        addRenderableWidget(next);

        Side[] choices = {Side.HIDER, Side.HUNTER, Side.NONE, Side.SPECTATOR};
        int bw = 34;
        int y = cy + rowH + 4;
        for (int i = rosterPage * per; i < Math.min(roster.size(), (rosterPage + 1) * per); i++) {
            CompoundTag r = roster.getCompound(i);
            String id = r.hasUUID("id") ? r.getUUID("id").toString() : "";
            int side = r.getInt("side");
            rosterRows.add(new RosterRow(r.getString("name"), side, r.getBoolean("inArena"), y));
            for (int k = 0; k < choices.length; k++) {
                Side c = choices[k];
                Button b = Button.builder(tr("side_btn." + c.id).withStyle(c.color), btn -> send("team", id, c.id))
                        .bounds(px + pw - 8 - (choices.length - k) * (bw + 2), y, bw, 18)
                        .tooltip(Tooltip.create(tr("side_btn.desc", c.displayName()))).build();
                b.active = phase == Phase.LOBBY && side != c.ordinal();
                addRenderableWidget(b);
            }
            y += 20;
        }
    }

    private Tooltip settingTooltip(GameSettings.Def d, Component extra) {
        MutableComponent t = Component.translatable(d.descKey()).copy();
        if (extra != null) t.append("\n\n").append(extra);
        t.append("\n").append(tr("rmb_reset", defaultText(d)).withStyle(ChatFormatting.DARK_GRAY));
        return Tooltip.create(t);
    }

    private Component defaultText(GameSettings.Def d) {
        return switch (d.kind()) {
            case BOOL -> d.def() != 0 ? tr("on") : tr("off");
            case CHOICE -> Component.translatable(d.choiceLangKey(d.def()));
            default -> SettingSlider.format(d, d.def());
        };
    }

    /** Adds widgets for every setting of a tab in two columns starting at {@code row}; returns the next free row. */
    private int settingWidgets(GameSettings.Tab t, int row) {
        List<GameSettings.Def> defs = GameSettings.defs(t);
        int i = 0;
        for (GameSettings.Def d : defs) {
            int col = i % 2, r = row + i / 2;
            int x = colX(col), y = rowY(r);
            AbstractWidget w;
            switch (d.kind()) {
                case INT -> {
                    SettingSlider s = new SettingSlider(x, y, colW, widgetH, d, settings.getInt(d.key()));
                    s.setTooltip(settingTooltip(d, null));
                    sliders.add(s);
                    w = s;
                }
                case BOOL -> {
                    boolean on = settings.getBool(d.key());
                    Component label = Component.translatable(d.langKey()).append(": ")
                            .append(on ? tr("on").withStyle(ChatFormatting.GREEN) : tr("off").withStyle(ChatFormatting.RED));
                    w = Button.builder(label, b -> send("set", d.key(), "toggle")).bounds(x, y, colW, widgetH).tooltip(settingTooltip(d, null)).build();
                }
                default -> {
                    int cur = settings.getInt(d.key());
                    Component label = Component.translatable(d.langKey()).append(": ")
                            .append(Component.translatable(d.choiceLangKey(cur)).withStyle(ChatFormatting.AQUA));
                    Component extra = Component.translatable(d.choiceLangKey(cur) + ".desc").withStyle(ChatFormatting.GRAY);
                    w = Button.builder(label, b -> send("set", d.key(), "next")).bounds(x, y, colW, widgetH).tooltip(settingTooltip(d, extra)).build();
                }
            }
            addRenderableWidget(w);
            settingWidgets.add(new SettingWidget(w, d));
            i++;
        }
        return row + (i + 1) / 2;
    }

    private boolean isDefault(GameSettings.Def d) {
        for (SettingSlider s : sliders) if (s.def == d) return s.intValue == d.def();
        return settings.getInt(d.key()) == d.def();
    }

    private static String rawDefault(GameSettings.Def d) {
        return switch (d.kind()) {
            case BOOL -> d.def() != 0 ? "true" : "false";
            case CHOICE -> d.choices().get(d.def());
            default -> String.valueOf(d.def());
        };
    }

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (button == 1) {
            for (SettingWidget sw : settingWidgets) {
                if (sw.widget().visible && sw.widget().isMouseOver(mouseX, mouseY) && !isDefault(sw.def())) {
                    for (SettingSlider s : sliders) if (s.def == sw.def()) s.pending = false;
                    send("set", sw.def().key(), rawDefault(sw.def()));
                    if (minecraft != null) minecraft.getSoundManager().play(SimpleSoundInstance.forUI(SoundEvents.UI_BUTTON_CLICK, 0.8F));
                    return true;
                }
            }
        }
        return super.mouseClicked(mouseX, mouseY, button);
    }

    // ================================================================== ticking / rendering

    @Override
    public void tick() {
        ticks++;
        for (SettingSlider s : sliders) {
            if (s.pending && ticks - s.lastChange >= 6) {
                s.pending = false;
                send("set", s.def.key(), String.valueOf(s.intValue));
            }
        }
        if (confirmId != null && ticks - confirmTick >= CONFIRM_TICKS) resetConfirm();
    }

    @Override
    public void removed() {
        for (SettingSlider s : sliders) {
            if (s.pending) {
                s.pending = false;
                send("set", s.def.key(), String.valueOf(s.intValue));
            }
        }
        super.removed();
    }

    @Override
    public boolean isPauseScreen() {
        return false;
    }

    @Override
    public void render(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        super.render(g, mouseX, mouseY, partialTick);
        // yellow dot on settings that differ from the default
        for (SettingWidget sw : settingWidgets) {
            if (isDefault(sw.def())) continue;
            int x = sw.widget().getX() + 2, y = sw.widget().getY() + 2;
            g.fill(x, y, x + 3, y + 3, 0xFFFFD54A);
        }
    }

    @Override
    public void renderBackground(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        super.renderBackground(g, mouseX, mouseY, partialTick);
        UiDraw.panel(g, px, py, pw, ph, 0xFFFFAA00, 1F);
        // header: title left; arena name, phase and info right (trimmed to the space that is left)
        Component titleC = Component.literal("✦ ").append(title).withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD);
        int titleW = font.width(titleC);
        g.drawString(font, titleC, px + 8, py + 7, 0xFFFFFFFF, true);
        Phase phase = Phase.byOrdinal(data.getInt("phase"));
        Component phaseC = Component.literal("  •  ").withStyle(ChatFormatting.DARK_GRAY)
                .append(phase.displayName().withStyle(phase == Phase.LOBBY ? ChatFormatting.GRAY : ChatFormatting.YELLOW));
        int rightMax = pw - 24 - titleW;
        String name = font.plainSubstrByWidth(data.getString("name"), Math.max(10, rightMax - font.width(phaseC)));
        if (name.length() < data.getString("name").length() && name.length() > 1) name = name.substring(0, name.length() - 1) + "…";
        Component right = Component.literal(name).withStyle(ChatFormatting.WHITE).append(phaseC);
        g.drawString(font, right, px + pw - 8 - font.width(right), py + 4, 0xFFFFFFFF, false);
        Component info = tr("info", data.getString("dim"), data.getInt("rounds"));
        g.pose().pushPose();
        g.pose().translate(px + pw - 8 - font.width(info) * 0.75F, py + 14, 0);
        g.pose().scale(0.75F, 0.75F, 1F);
        g.drawString(font, info, 0, 0, 0xFF777788, false);
        g.pose().popPose();
        // active tab underline
        g.fill(activeTabX, py + 40, activeTabX + activeTabW, py + 42, 0xFFFFC21A);
        // content frame
        g.fill(px + 6, cy - 3, px + pw - 6, py + ph - 28, 0x40000000);
        g.fill(px + 6, py + ph - 29, px + pw - 6, py + ph - 28, 0xFF3A3A50);

        if (tab == UiTab.PLAYERS) {
            ListTag roster = data.getList("roster", Tag.TAG_COMPOUND);
            int pages = Math.max(1, (roster.size() + rosterPerPage() - 1) / rosterPerPage());
            g.drawCenteredString(font, tr("page", rosterPage + 1, pages), colX(1) + colW / 2, rowY(0) + (widgetH - 8) / 2, 0xFFAAAAAA);
            if (rosterRows.isEmpty()) {
                g.drawCenteredString(font, tr("roster_empty"), px + pw / 2, cy + 40, 0xFF888888);
            }
            int nameMax = pw - 16 - 4 * 36 - 14;
            for (RosterRow r : rosterRows) {
                Side s = Side.byOrdinal(r.side());
                g.fill(px + 8, r.y() - 1, px + 11, r.y() + 17, s.argb);
                g.drawString(font, font.plainSubstrByWidth(r.name(), nameMax), px + 15, r.y() + 1, 0xFFFFFFFF, false);
                Component sub = s.displayName().copy().append(r.inArena() ? Component.empty()
                        : Component.literal(" ").append(tr("other_dim")).withStyle(ChatFormatting.DARK_GRAY));
                g.pose().pushPose();
                g.pose().translate(px + 15, r.y() + 10, 0);
                g.pose().scale(0.75F, 0.75F, 1F);
                g.drawString(font, sub, 0, 0, 0xFFAAAAAA, false);
                g.pose().popPose();
            }
        }
    }

    // ================================================================== slider

    private final class SettingSlider extends AbstractSliderButton {
        final GameSettings.Def def;
        int intValue;
        boolean pending;
        int lastChange;

        SettingSlider(int x, int y, int w, int h, GameSettings.Def def, int current) {
            super(x, y, w, h, Component.empty(), 0.0);
            this.def = def;
            this.intValue = current;
            this.value = (current - def.min()) / (double) Math.max(1, def.max() - def.min());
            updateMessage();
        }

        private int step() {
            int range = def.max() - def.min();
            return range > 1200 ? 15 : range > 300 ? 5 : 1;
        }

        @Override
        protected void updateMessage() {
            setMessage(Component.translatable(def.langKey()).append(": ").append(format(def, intValue).withStyle(ChatFormatting.YELLOW)));
        }

        static MutableComponent format(GameSettings.Def def, int v) {
            boolean zeroOff = def.min() == 0 && !def.key().equals(GameSettings.TAUNT_POINTS);
            if (v == 0 && zeroOff) return Component.translatable(def.key().startsWith("max_") ? "hideandhunt.gui.unlimited" : "hideandhunt.gui.off");
            if ("s".equals(def.unit())) {
                return v >= 60 ? Component.literal(UiDraw.clock(v)) : Component.translatable("hideandhunt.gui.seconds", v);
            }
            if (def.key().equals(GameSettings.HUNTER_RATIO)) return Component.translatable("hideandhunt.gui.ratio", v);
            if (def.key().equals(GameSettings.HUNTER_SPEED)) return Component.translatable("hideandhunt.gui.speed_level", v);
            return Component.literal(String.valueOf(v));
        }

        @Override
        protected void applyValue() {
            int raw = def.min() + (int) Math.round(value * (def.max() - def.min()));
            int st = step();
            int v = def.min() + Math.round((raw - def.min()) / (float) st) * st;
            v = Mth.clamp(v, def.min(), def.max());
            if (v != intValue) {
                intValue = v;
                pending = true;
                lastChange = ticks;
            }
        }
    }
}
