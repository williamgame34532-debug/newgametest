package com.williamgame.blockmemory.client;

import com.williamgame.blockmemory.BlockMemory;
import com.williamgame.blockmemory.codex.CodexManager;
import com.williamgame.blockmemory.codex.Fragments;
import com.williamgame.blockmemory.network.CodexClaimPacket;
import com.williamgame.blockmemory.network.ModNetwork;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.network.chat.Style;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.util.FormattedCharSequence;
import net.minecraft.util.Mth;
import net.minecraft.world.item.ItemStack;
import org.lwjgl.glfw.GLFW;

import java.util.ArrayList;
import java.util.List;

/** The Codex of the Forgotten: a two-page book with chapter bookmarks. */
public class CodexScreen extends Screen {
    private static final ResourceLocation TEX = BlockMemory.id("textures/gui/codex.png");
    private static final ResourceLocation ALT_FONT = ResourceLocation.withDefaultNamespace("alt");
    private static final int TEX_W = 512, TEX_H = 256;
    private static final int BW = 352, BH = 216;

    private static final int INK = 0x3A2614;
    private static final int FADED = 0x8A7458;
    private static final int RED_INK = 0x7A2E1A;
    private static final int GOLD = 0xA87E22;
    private static final int[] TAB_COLORS = {0x8E3B2E, 0x2E5E8E, 0x4E7A3A, 0x6A3E8E};

    private static final int ROW_Y = 74;
    private static final int ROW_H = 15;

    private int left, top;
    private int chapter;
    private int selected;
    private int scroll;
    private int ticks;
    private int switchTick = -100;
    private List<FormattedCharSequence> bodyLines = new ArrayList<>();

    public CodexScreen() {
        super(Component.translatable("blockmemory.codex.title"));
        // open on the first unfinished chapter
        for (int c = 0; c < Fragments.CHAPTERS; c++) {
            if (!Fragments.chapterComplete(ClientHooks.fragments, c) || (ClientHooks.claimed & (1 << c)) == 0) {
                chapter = c;
                break;
            }
        }
        if (!ClientHooks.unseen.isEmpty()) {
            int first = ClientHooks.unseen.iterator().next();
            chapter = Fragments.chapterOf(first);
            selected = first % Fragments.PER_CHAPTER;
        } else {
            selectFirstKnown();
        }
    }

    private void selectFirstKnown() {
        selected = 0;
        for (int i = 0; i < Fragments.PER_CHAPTER; i++) {
            if (known(chapter * Fragments.PER_CHAPTER + i)) {
                selected = i;
                return;
            }
        }
    }

    private static boolean known(int index) {
        return (ClientHooks.fragments & (1 << index)) != 0;
    }

    private int selectedIndex() {
        return chapter * Fragments.PER_CHAPTER + selected;
    }

    @Override
    protected void init() {
        left = (width - BW) / 2;
        top = (height - BH) / 2;
        rebuildBody();
    }

    public void onSync() {
        rebuildBody();
    }

    private void rebuildBody() {
        int idx = selectedIndex();
        ClientHooks.unseen.remove(idx);
        Component text = known(idx) ? Fragments.text(idx) : obscured(idx, 260);
        bodyLines = font.split(text, 140);
        scroll = 0;
    }

    private static MutableComponent obscured(int seed, int length) {
        StringBuilder sb = new StringBuilder();
        long x = seed * 2654435761L + 12345;
        for (int i = 0; i < length; i++) {
            x = x * 6364136223846793005L + 1442695040888963407L;
            int r = (int) ((x >>> 33) % 9);
            sb.append(r == 0 ? ' ' : (char) ('a' + (int) ((x >>> 40) % 26)));
        }
        return Component.literal(sb.toString()).withStyle(Style.EMPTY.withFont(ALT_FONT));
    }

    private void switchTo(int newChapter, int newSelected) {
        boolean changed = newChapter != chapter || newSelected != selected;
        chapter = Mth.clamp(newChapter, 0, Fragments.CHAPTERS - 1);
        selected = Mth.clamp(newSelected, 0, Fragments.PER_CHAPTER - 1);
        if (changed) {
            switchTick = ticks;
            minecraft.getSoundManager().play(SimpleSoundInstance.forUI(SoundEvents.BOOK_PAGE_TURN, 1.0F));
            rebuildBody();
        }
    }

    @Override
    public void tick() {
        ticks++;
    }

    private static int ink(int rgb, float alpha) {
        int a = Mth.clamp((int) (alpha * 255), 6, 255);
        return (a << 24) | rgb;
    }

    // ------------------------------------------------------------------ rendering

    @Override
    public void render(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        super.render(g, mouseX, mouseY, partialTick);
        float time = ticks + partialTick;
        float fade = Mth.clamp((time - switchTick) / 6F, 0F, 1F);

        renderTabs(g, mouseX, mouseY, time);
        g.blit(TEX, left, top, 0F, 0F, BW, BH, TEX_W, TEX_H);
        renderLeftPage(g, mouseX, mouseY, time, fade);
        renderRightPage(g, mouseX, mouseY, time, fade);
    }

    private void renderTabs(GuiGraphics g, int mouseX, int mouseY, float time) {
        for (int c = 0; c < Fragments.CHAPTERS; c++) {
            int x = left + BW - 6;
            int y = top + 18 + c * 44;
            boolean active = c == chapter;
            boolean hover = mouseX >= x && mouseX < x + 28 && mouseY >= y && mouseY < y + 36;
            int ext = active ? 26 : hover ? 22 : 18;
            int col = TAB_COLORS[c];
            g.fill(x, y, x + ext, y + 36, 0xFF000000 | darken(col, 0.55F));
            g.fill(x, y + 1, x + ext - 1, y + 35, 0xFF000000 | col);
            g.fillGradient(x, y + 1, x + ext - 1, y + 18, 0x30FFFFFF, 0x00FFFFFF);
            // notch of the ribbon
            g.fill(x + ext - 4, y + 16, x + ext, y + 20, 0xFF000000 | darken(col, 0.4F));
            String roman = Fragments.roman(c);
            g.drawString(font, roman, x + ext - 7 - font.width(roman), y + 6, 0xFFF4E6C8, false);
            int count = Fragments.countInChapter(ClientHooks.fragments, c);
            String cnt = count + "/" + Fragments.PER_CHAPTER;
            g.pose().pushPose();
            g.pose().translate(x + ext - 6 - font.width(cnt) * 0.6F, y + 22, 0);
            g.pose().scale(0.6F, 0.6F, 1F);
            g.drawString(font, cnt, 0, 0, Fragments.chapterComplete(ClientHooks.fragments, c) ? 0xFFF2D27A : 0xFFE0D2B6, false);
            g.pose().popPose();
            if (hover && !active) {
                g.renderTooltip(font, Fragments.chapterTitle(c), mouseX, mouseY);
            }
        }
    }

    private static int darken(int rgb, float f) {
        int r = (int) (((rgb >> 16) & 255) * f), gg = (int) (((rgb >> 8) & 255) * f), b = (int) ((rgb & 255) * f);
        return (r << 16) | (gg << 8) | b;
    }

    private void renderLeftPage(GuiGraphics g, int mouseX, int mouseY, float time, float fade) {
        int x0 = left + 24, w = 140, cx = x0 + w / 2;
        int y = top + 16;
        Component chap = Component.translatable("blockmemory.codex.chapter", Fragments.roman(chapter));
        g.drawCenteredString(font, chap.getVisualOrderText(), cx, y, ink(RED_INK, fade));
        // centered without shadow
        drawCenteredNoShadow(g, chap, cx, y, ink(RED_INK, fade));
        y += 12;
        g.pose().pushPose();
        Component title = Fragments.chapterTitle(chapter);
        float s = Math.min(1.3F, (float) w / Math.max(1, font.width(title)));
        g.pose().translate(cx, y, 0);
        g.pose().scale(s, s, 1F);
        g.drawString(font, title, -font.width(title) / 2, 0, ink(INK, fade), false);
        g.pose().popPose();
        y += 14;
        for (FormattedCharSequence line : font.split(Fragments.chapterSubtitle(chapter).copy().withStyle(st -> st.withItalic(true)), w)) {
            drawCenteredNoShadow(g, line, cx, y, ink(FADED, fade));
            y += 9;
        }
        // ornament
        int oy = top + ROW_Y - 6;
        g.fill(x0 + 10, oy, x0 + w - 10, oy + 1, ink(FADED, 0.6F * fade));
        g.fill(cx - 2, oy - 2, cx + 2, oy + 3, ink(RED_INK, fade));

        // fragment rows
        for (int i = 0; i < Fragments.PER_CHAPTER; i++) {
            int idx = chapter * Fragments.PER_CHAPTER + i;
            int ry = top + ROW_Y + i * ROW_H;
            boolean isKnown = known(idx);
            boolean hover = mouseX >= x0 && mouseX < x0 + w && mouseY >= ry - 2 && mouseY < ry + ROW_H - 2;
            if (i == selected) {
                g.fill(x0 - 2, ry - 3, x0 + w + 2, ry + ROW_H - 3, ink(0xC9A55A, 0.28F * fade));
                g.fill(x0 - 2, ry - 3, x0 - 1, ry + ROW_H - 3, ink(RED_INK, fade));
            } else if (hover) {
                g.fill(x0 - 2, ry - 3, x0 + w + 2, ry + ROW_H - 3, ink(0xC9A55A, 0.14F * fade));
            }
            // rune icon from the texture atlas
            int u = 360 + (idx % 12) * 12, v = 32 + (idx / 12) * 12;
            if (isKnown) {
                g.blit(TEX, x0, ry, (float) u, (float) v, 10, 10, TEX_W, TEX_H);
            } else {
                g.fill(x0 + 3, ry + 3, x0 + 7, ry + 7, ink(FADED, 0.5F * fade));
            }
            String label = Fragments.label(idx);
            g.drawString(font, label, x0 + 14, ry + 1, ink(isKnown ? RED_INK : FADED, fade), false);
            int tx = x0 + 14 + 26;
            if (isKnown) {
                Component t = Fragments.title(idx);
                List<FormattedCharSequence> l = font.split(t, w - 40);
                if (!l.isEmpty()) g.drawString(font, l.get(0), tx, ry + 1, ink(INK, fade), false);
            } else {
                g.drawString(font, obscured(idx, 10), tx, ry + 1, ink(FADED, 0.55F * fade), false);
            }
            if (ClientHooks.unseen.contains(idx)) {
                float p = 0.5F + 0.5F * Mth.sin(time * 0.3F);
                g.fill(x0 + w - 4, ry + 2, x0 + w, ry + 6, ink(0xD4A020, 0.5F + 0.5F * p));
            }
        }

        // progress
        int py = top + ROW_Y + Fragments.PER_CHAPTER * ROW_H + 4;
        int count = Fragments.countInChapter(ClientHooks.fragments, chapter);
        g.fill(x0, py, x0 + 100, py + 3, ink(FADED, 0.35F));
        g.fill(x0, py, x0 + 100 * count / Fragments.PER_CHAPTER, py + 3, ink(count == Fragments.PER_CHAPTER ? GOLD : RED_INK, 0.9F));
        g.drawString(font, count + " / " + Fragments.PER_CHAPTER, x0 + 104, py - 3, ink(FADED, fade), false);

        // reward with wax seal
        int ry = py + 9;
        g.drawString(font, Component.translatable("blockmemory.codex.reward"), x0, ry, ink(FADED, fade), false);
        List<FormattedCharSequence> reward = font.split(Fragments.chapterReward(chapter), 104);
        for (int i = 0; i < Math.min(2, reward.size()); i++) {
            g.drawString(font, reward.get(i), x0, ry + 10 + i * 9, ink(INK, fade), false);
        }
        int sx = x0 + w - 28, sy = ry - 2;
        boolean complete = Fragments.chapterComplete(ClientHooks.fragments, chapter);
        boolean claimedCh = (ClientHooks.claimed & (1 << chapter)) != 0;
        int su = claimedCh ? 416 : complete ? 388 : 360;
        if (complete && !claimedCh) {
            float p = 0.5F + 0.5F * Mth.sin(time * 0.25F);
            g.fill(sx - 2, sy - 2, sx + 30, sy + 30, ink(0xE0B040, 0.12F + 0.18F * p));
        }
        g.blit(TEX, sx, sy, (float) su, 0F, 28, 28, TEX_W, TEX_H);
        if (mouseX >= sx && mouseX < sx + 28 && mouseY >= sy && mouseY < sy + 28) {
            List<Component> tip = new ArrayList<>();
            tip.add(Fragments.chapterReward(chapter));
            tip.add(Component.translatable(claimedCh ? "blockmemory.codex.seal.claimed"
                    : complete ? "blockmemory.codex.seal.ready" : "blockmemory.codex.seal.locked"));
            List<FormattedCharSequence> seq = new ArrayList<>();
            for (Component c : tip) seq.add(c.getVisualOrderText());
            g.renderTooltip(font, seq, mouseX, mouseY);
            if (!claimedCh) {
                List<ItemStack> items = CodexManager.rewards(chapter);
                for (int i = 0; i < items.size(); i++) g.renderItem(items.get(i), mouseX + 12 + i * 18, mouseY - 22);
            }
        }
    }

    private void drawCenteredNoShadow(GuiGraphics g, Component c, int cx, int y, int color) {
        g.drawString(font, c, cx - font.width(c) / 2, y, color, false);
    }

    private void drawCenteredNoShadow(GuiGraphics g, FormattedCharSequence c, int cx, int y, int color) {
        g.drawString(font, c, cx - font.width(c) / 2, y, color, false);
    }

    private void renderRightPage(GuiGraphics g, int mouseX, int mouseY, float time, float fade) {
        int x0 = left + 188, w = 140, cx = x0 + w / 2;
        int idx = selectedIndex();
        boolean isKnown = known(idx);
        int y = top + 16;
        drawCenteredNoShadow(g, Component.translatable("blockmemory.codex.fragment", Fragments.label(idx)), cx, y, ink(RED_INK, fade));
        y += 11;
        Component title = isKnown ? Fragments.title(idx) : Component.literal("? ? ?");
        for (FormattedCharSequence line : font.split(title, w)) {
            drawCenteredNoShadow(g, line, cx, y, ink(INK, fade));
            y += 10;
        }
        g.fill(cx - 30, y + 1, cx + 30, y + 2, ink(FADED, 0.6F * fade));
        y += 7;

        int bottom = top + BH - 26;
        int visible = Math.max(1, (bottom - y) / 9);
        int maxScroll = Math.max(0, bodyLines.size() - visible);
        scroll = Mth.clamp(scroll, 0, maxScroll);
        for (int i = 0; i < visible && i + scroll < bodyLines.size(); i++) {
            // ink appears line by line after a page turn
            float lineFade = Mth.clamp((time - switchTick - i * 0.8F) / 5F, 0F, 1F);
            g.drawString(font, bodyLines.get(i + scroll), x0, y + i * 9, ink(isKnown ? INK : FADED, (isKnown ? 1F : 0.45F) * lineFade), false);
        }
        if (maxScroll > 0) {
            int barTop = y, barH = visible * 9;
            int knob = Math.max(8, barH * visible / bodyLines.size());
            int ky = barTop + (barH - knob) * scroll / maxScroll;
            g.fill(x0 + w + 4, barTop, x0 + w + 5, barTop + barH, ink(FADED, 0.3F));
            g.fill(x0 + w + 3, ky, x0 + w + 6, ky + knob, ink(RED_INK, 0.8F));
        }
        if (!isKnown) {
            List<FormattedCharSequence> hint = font.split(Component.translatable("blockmemory.codex.buried").withStyle(st -> st.withItalic(true)), w);
            int hy = bottom - hint.size() * 9 - 2;
            g.fill(x0, hy - 4, x0 + w, bottom, ink(0xEFE2C4, 0.85F));
            for (int i = 0; i < hint.size(); i++) drawCenteredNoShadow(g, hint.get(i), cx, hy + i * 9, ink(RED_INK, fade));
        }
        // footer: page number and total memories
        int total = Integer.bitCount(ClientHooks.fragments);
        drawCenteredNoShadow(g, Component.literal("— " + (idx + 1) + " —"), cx, top + BH - 18, ink(FADED, 0.8F));
        Component mem = Component.translatable("blockmemory.codex.total", total, Fragments.TOTAL);
        g.drawString(font, mem, left + 24, top + BH - 18, ink(FADED, 0.8F), false);
    }

    // ------------------------------------------------------------------ input

    @Override
    public boolean mouseClicked(double mouseX, double mouseY, int button) {
        if (button == 0) {
            for (int c = 0; c < Fragments.CHAPTERS; c++) {
                int x = left + BW - 6;
                int y = top + 18 + c * 44;
                if (mouseX >= x && mouseX < x + 28 && mouseY >= y && mouseY < y + 36) {
                    if (c != chapter) {
                        chapter = c;
                        int keep = selected;
                        selectFirstKnown();
                        int sel = selected;
                        selected = keep;
                        chapter = -1; // force change detection
                        switchTo(c, sel);
                    }
                    return true;
                }
            }
            int x0 = left + 24, w = 140;
            for (int i = 0; i < Fragments.PER_CHAPTER; i++) {
                int ry = top + ROW_Y + i * ROW_H;
                if (mouseX >= x0 && mouseX < x0 + w && mouseY >= ry - 2 && mouseY < ry + ROW_H - 2) {
                    switchTo(chapter, i);
                    return true;
                }
            }
            int py = top + ROW_Y + Fragments.PER_CHAPTER * ROW_H + 4;
            int sx = x0 + w - 28, sy = py + 9 - 2;
            if (mouseX >= sx && mouseX < sx + 28 && mouseY >= sy && mouseY < sy + 28) {
                boolean complete = Fragments.chapterComplete(ClientHooks.fragments, chapter);
                boolean claimedCh = (ClientHooks.claimed & (1 << chapter)) != 0;
                if (complete && !claimedCh) {
                    ModNetwork.sendToServer(new CodexClaimPacket(chapter));
                    minecraft.getSoundManager().play(SimpleSoundInstance.forUI(SoundEvents.UI_TOAST_CHALLENGE_COMPLETE, 1.0F));
                } else {
                    minecraft.getSoundManager().play(SimpleSoundInstance.forUI(SoundEvents.CHISELED_BOOKSHELF_PICKUP, 1.0F));
                }
                return true;
            }
        }
        return super.mouseClicked(mouseX, mouseY, button);
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double scrollX, double scrollY) {
        if (mouseX >= left + BW / 2) {
            scroll -= (int) Math.signum(scrollY) * 2;
            return true;
        }
        if (scrollY != 0) {
            switchTo(chapter, selected - (int) Math.signum(scrollY));
            return true;
        }
        return super.mouseScrolled(mouseX, mouseY, scrollX, scrollY);
    }

    @Override
    public boolean keyPressed(int key, int scan, int modifiers) {
        switch (key) {
            case GLFW.GLFW_KEY_LEFT -> {
                if (chapter > 0) {
                    int c = chapter - 1;
                    switchTo(c, 0);
                }
                return true;
            }
            case GLFW.GLFW_KEY_RIGHT -> {
                if (chapter < Fragments.CHAPTERS - 1) switchTo(chapter + 1, 0);
                return true;
            }
            case GLFW.GLFW_KEY_UP -> {
                switchTo(chapter, selected - 1);
                return true;
            }
            case GLFW.GLFW_KEY_DOWN -> {
                switchTo(chapter, selected + 1);
                return true;
            }
            default -> {
                if (ClientModEvents.OPEN_CODEX.matches(key, scan)) {
                    onClose();
                    return true;
                }
                return super.keyPressed(key, scan, modifiers);
            }
        }
    }

    @Override
    public boolean isPauseScreen() {
        return false;
    }
}
