package com.williamgame.hideandhunt.client;

import com.williamgame.hideandhunt.ModRegistry;
import com.williamgame.hideandhunt.game.Side;
import com.williamgame.hideandhunt.network.RandomizerPacket;
import net.minecraft.ChatFormatting;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.network.chat.Component;
import net.minecraft.util.Mth;

/**
 * Slot-machine animation shown to everyone in the arena when the Randomizer Button is pressed.
 * A big reel spins for your own side and slows down; then everybody's result is revealed one by one.
 */
public final class RandomizerOverlay {
    private RandomizerOverlay() {}

    private static final int ITEM_H = 22;
    private static final int FADE = 25;

    private static RandomizerPacket active;
    private static long start;
    private static int mySide = -1;
    private static int reelItems;
    private static int lastReelIndex = -1;
    private static int revealedCount;
    private static boolean landed;

    public static void begin(RandomizerPacket m) {
        active = m;
        start = ClientState.ticks;
        lastReelIndex = -1;
        revealedCount = 0;
        landed = false;
        mySide = -1;
        Minecraft mc = Minecraft.getInstance();
        if (mc.player != null) {
            String me = mc.player.getGameProfile().getName();
            for (int i = 0; i < m.names().size(); i++) {
                if (m.names().get(i).equals(me)) mySide = m.sides().get(i);
            }
        }
        if (mySide == Side.SPECTATOR.ordinal()) mySide = -1;
        // reel alternates HIDER/HUNTER; land on the right one
        int base = 36;
        int finalIndexParity = mySide == Side.HUNTER.ordinal() ? 1 : 0;
        reelItems = base + ((base % 2) == finalIndexParity ? 0 : 1);
    }

    public static void stop() {
        active = null;
    }

    private static int spinEnd() {
        return (int) (active.durationTicks() * 0.6F);
    }

    private static int revealAt(int i) {
        int n = Math.max(1, active.names().size());
        int window = active.durationTicks() - spinEnd() - 5;
        return spinEnd() + 5 + (int) (window * (i / (float) n));
    }

    private static float easeOut(float t) {
        t = Mth.clamp(t, 0F, 1F);
        return 1F - (float) Math.pow(1F - t, 3);
    }

    /** Reel offset in items, fractional. */
    private static float reelPos(float t) {
        return easeOut(t / spinEnd()) * reelItems;
    }

    public static void tick() {
        if (active == null) return;
        long t = ClientState.ticks - start;
        if (t > active.durationTicks() + FADE) {
            active = null;
            return;
        }
        Minecraft mc = Minecraft.getInstance();
        int idx = (int) reelPos(t);
        if (idx != lastReelIndex && t <= spinEnd()) {
            lastReelIndex = idx;
            float pitch = 0.8F + 0.5F * (1F - t / (float) spinEnd()); // woodblock, capped at 1.3
            mc.getSoundManager().play(SimpleSoundInstance.forUI(ModRegistry.SND_RANDOM_TICK.get(), pitch, 0.5F));
        }
        if (!landed && t >= spinEnd()) {
            landed = true;
            mc.getSoundManager().play(SimpleSoundInstance.forUI(ModRegistry.SND_RANDOM_REVEAL.get(), 1.0F, 0.9F));
        }
        while (revealedCount < active.names().size() && t >= revealAt(revealedCount)) {
            revealedCount++;
            mc.getSoundManager().play(SimpleSoundInstance.forUI(ModRegistry.SND_RANDOM_POP.get(), 0.9F + 0.03F * Math.min(10, revealedCount), 0.45F));
        }
    }

    private static Component label(int sideOrdinal) {
        Side s = Side.byOrdinal(sideOrdinal);
        return s.displayName().withStyle(ChatFormatting.BOLD);
    }

    public static void render(GuiGraphics g, float partialTick) {
        if (active == null) return;
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null) return;
        Font font = mc.font;
        float t = (ClientState.ticks - start) + partialTick;
        float alpha = 1F;
        if (t < 6) alpha = t / 6F;
        if (t > active.durationTicks()) alpha = 1F - Mth.clamp((t - active.durationTicks()) / FADE, 0F, 1F);
        if (alpha <= 0.01F) return;

        int sw = g.guiWidth(), sh = g.guiHeight();
        g.fillGradient(0, 0, sw, sh, UiDraw.withAlpha(0xA0000000, alpha), UiDraw.withAlpha(0x70100820, alpha));

        int n = active.names().size();
        int cols = n > 8 ? 2 : 1;
        int rows = (n + cols - 1) / cols;
        int listH = Math.min(rows, 10) * 12;
        int pw = cols == 2 ? 300 : 200;
        int ph = 110 + listH;
        int px = sw / 2 - pw / 2;
        int py = Math.max(8, sh / 2 - ph / 2);
        UiDraw.panel(g, px, py, pw, ph, 0xFFFFC21A, alpha);

        // flashing title with question marks
        float flash = 0.5F + 0.5F * Mth.sin(t * 0.5F);
        int titleColor = UiDraw.withAlpha(lerpColor(0xFFFFD54A, 0xFFFFFFFF, flash), alpha);
        UiDraw.scaledCentered(g, font, Component.translatable("hideandhunt.randomizer.title"), sw / 2, py + 7, 1.6F, titleColor);

        // ---- reel
        int rw = 150, rh = ITEM_H * 2 + 4;
        int rx = sw / 2 - rw / 2, ry = py + 26;
        g.fill(rx - 2, ry - 2, rx + rw + 2, ry + rh + 2, UiDraw.withAlpha(0xFFB8860B, alpha));
        g.fill(rx, ry, rx + rw, ry + rh, UiDraw.withAlpha(0xFF0A0A12, alpha));
        float pos = Math.min(reelPos(t), reelItems);
        int centerY = ry + rh / 2;
        g.enableScissor(rx, ry, rx + rw, ry + rh);
        int firstIdx = (int) Math.floor(pos) - 2;
        for (int i = firstIdx; i <= firstIdx + 5; i++) {
            float yy = centerY + (i - pos) * ITEM_H - 4;
            int side = mySide < 0 ? -1 : (Math.floorMod(i, 2) == 0 ? Side.HIDER.ordinal() : Side.HUNTER.ordinal());
            Component c = side < 0 ? Component.literal("? ? ?").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD) : label(side);
            int color = side < 0 ? 0xFFFFD54A : Side.byOrdinal(side).argb;
            float dist = Math.abs(yy + 4 - centerY) / (float) ITEM_H;
            float a = alpha * Mth.clamp(1.2F - dist * 0.7F, 0.15F, 1F);
            UiDraw.scaledCentered(g, font, c, sw / 2, (int) yy, 1.5F, UiDraw.withAlpha(color, a));
        }
        g.disableScissor();
        // glass shine + centre markers
        g.fillGradient(rx, ry, rx + rw, ry + 10, UiDraw.withAlpha(0x60000000, alpha), 0x00000000);
        g.fillGradient(rx, ry + rh - 10, rx + rw, ry + rh, 0x00000000, UiDraw.withAlpha(0x60000000, alpha));
        int mk = UiDraw.withAlpha(0xFFFFC21A, alpha);
        g.fill(rx - 6, centerY - 3, rx - 2, centerY + 3, mk);
        g.fill(rx + rw + 2, centerY - 3, rx + rw + 6, centerY + 3, mk);

        // ---- verdict line
        int vy = ry + rh + 6;
        if (t >= spinEnd() && mySide >= 0) {
            Component v = Component.translatable("hideandhunt.randomizer.you", label(mySide));
            float pop = 1F + 0.25F * Math.max(0F, 1F - (t - spinEnd()) / 8F);
            UiDraw.scaledCentered(g, font, v, sw / 2, vy, pop, UiDraw.withAlpha(0xFFFFFFFF, alpha));
        } else if (mySide < 0) {
            UiDraw.scaledCentered(g, font, Component.translatable("hideandhunt.randomizer.watching"), sw / 2, vy, 1F, UiDraw.withAlpha(0xFFAAAAAA, alpha));
        } else {
            UiDraw.scaledCentered(g, font, Component.translatable("hideandhunt.randomizer.spinning"), sw / 2, vy, 1F, UiDraw.withAlpha(0xFFAAAAAA, alpha));
        }

        // ---- everybody's result
        int ly = vy + 16;
        g.fill(px + 8, ly - 4, px + pw - 8, ly - 3, UiDraw.withAlpha(0xFF3A3A50, alpha));
        int colW = (pw - 16) / cols;
        int shown = Math.min(n, rows > 10 ? cols * 10 : n);
        for (int i = 0; i < shown; i++) {
            int col = i / Math.min(rows, 10);
            int row = i % Math.min(rows, 10);
            int x = px + 8 + col * colW;
            int y = ly + row * 12;
            String name = active.names().get(i);
            boolean isMe = mc.player.getGameProfile().getName().equals(name);
            if (isMe) g.fill(x, y - 2, x + colW - 2, y + 10, UiDraw.withAlpha(0x50FFD54A, alpha));
            Component res;
            int color;
            if (i < revealedCount) {
                Side s = Side.byOrdinal(active.sides().get(i));
                res = s.displayName();
                color = s.argb;
            } else {
                boolean flip = ((int) (t * 0.7F) + i) % 2 == 0;
                res = Component.literal(flip ? "███" : "? ? ?");
                color = flip ? 0xFF555566 : 0xFFFFD54A;
            }
            int resW = font.width(res);
            String shownName = font.plainSubstrByWidth(name, colW - resW - 14);
            if (shownName.length() < name.length() && shownName.length() > 1) shownName = shownName.substring(0, shownName.length() - 1) + "…";
            g.drawString(font, shownName, x + 2, y, UiDraw.withAlpha(isMe ? 0xFFFFE680 : 0xFFE0E0E0, alpha), false);
            g.drawString(font, res, x + colW - 6 - resW, y, UiDraw.withAlpha(color, alpha), false);
        }
        if (revealedCount >= n) {
            int hid = 0, hun = 0;
            for (int sd : active.sides()) {
                if (sd == Side.HIDER.ordinal()) hid++;
                else if (sd == Side.HUNTER.ordinal()) hun++;
            }
            Component sum = Component.translatable("hideandhunt.randomizer.summary",
                    Component.literal(String.valueOf(hid)).withStyle(ChatFormatting.GREEN),
                    Component.literal(String.valueOf(hun)).withStyle(ChatFormatting.RED));
            g.drawCenteredString(font, sum, sw / 2, py + ph - 12, UiDraw.withAlpha(0xFFDDDDDD, alpha));
        }
        if (shown < n) {
            g.drawString(font, "+" + (n - shown), px + pw - 24, py + ph - 10, UiDraw.withAlpha(0xFF888888, alpha), false);
        }
    }

    private static int lerpColor(int a, int b, float f) {
        int ar = (a >> 16) & 0xFF, ag = (a >> 8) & 0xFF, ab = a & 0xFF;
        int br = (b >> 16) & 0xFF, bg = (b >> 8) & 0xFF, bb = b & 0xFF;
        int r = (int) (ar + (br - ar) * f), gg = (int) (ag + (bg - ag) * f), bl = (int) (ab + (bb - ab) * f);
        return 0xFF000000 | (r << 16) | (gg << 8) | bl;
    }
}
