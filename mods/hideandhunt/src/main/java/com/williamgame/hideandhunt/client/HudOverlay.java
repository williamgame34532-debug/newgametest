package com.williamgame.hideandhunt.client;

import com.williamgame.hideandhunt.game.Phase;
import com.williamgame.hideandhunt.game.Side;
import com.williamgame.hideandhunt.network.StatePacket;
import net.minecraft.ChatFormatting;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.network.chat.Component;

/**
 * Top-left info panel: arena, phase, your side, timer, hiders left, hunters.
 * The width follows the (translated) text; on narrow screens the panel moves below the boss bars.
 */
public final class HudOverlay {
    private HudOverlay() {}

    private static final int MIN_W = 150;
    private static final int MAX_W = 240;

    public static void render(GuiGraphics g, float partialTick) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null || mc.options.hideGui) return;
        if (mc.getDebugOverlay().showDebugScreen()) return; // F3 text uses the same corner
        StatePacket s = ClientState.state;
        if (!s.visible()) return;
        Font font = mc.font;
        Phase phase = Phase.byOrdinal(s.phase());
        Side side = Side.byOrdinal(s.side());
        int accent = phase == Phase.LOBBY ? 0xFFFFAA00 : side.argb;
        if (phase != Phase.LOBBY && side == Side.NONE) accent = 0xFFFFAA00;

        // ---------- texts (built first so the panel can be sized to fit them)
        Component phaseName = phase.displayName();
        Component sideLabel = Component.translatable("hideandhunt.hud.side");
        Component sideText = side.displayName();
        if (phase.inRound() && side == Side.SPECTATOR) sideText = Component.translatable("hideandhunt.hud.eliminated").withStyle(ChatFormatting.GRAY);
        boolean tauntLine = phase == Phase.HUNTING && side == Side.HIDER && s.alive() && s.taunts();

        Component line1 = null, line2 = null, hidersTxt = null, huntersTxt = null, timeLbl = null, tauntTxt = null;
        switch (phase) {
            case LOBBY -> {
                line1 = Component.translatable("hideandhunt.hud.lobby_counts",
                        Component.literal(String.valueOf(s.lobbyHiders())).withStyle(ChatFormatting.GREEN),
                        Component.literal(String.valueOf(s.lobbyHunters())).withStyle(ChatFormatting.RED),
                        Component.literal(String.valueOf(s.lobbyNone())).withStyle(ChatFormatting.WHITE));
                String jm = switch (s.joinMode()) {
                    case 1 -> "pads";
                    case 2 -> "random";
                    case 3 -> "admin";
                    default -> "free";
                };
                line2 = Component.translatable("hideandhunt.hud.join." + jm);
            }
            case COUNTDOWN -> line1 = Component.translatable("hideandhunt.hud.starting_in", s.secondsLeft());
            case HIDING, HUNTING -> {
                timeLbl = Component.translatable(phase == Phase.HIDING ? "hideandhunt.hud.hide_left" : "hideandhunt.hud.hunt_left");
                hidersTxt = Component.translatable("hideandhunt.hud.hiders_left",
                        Component.literal(s.hidersAlive() + "/" + s.hidersTotal()).withStyle(ChatFormatting.GREEN));
                huntersTxt = Component.translatable("hideandhunt.hud.hunters", Component.literal(String.valueOf(s.hunters())).withStyle(ChatFormatting.RED));
                if (tauntLine) {
                    tauntTxt = s.tauntCooldown() > 0
                            ? Component.translatable("hideandhunt.hud.taunt_cd", s.tauntCooldown()).withStyle(ChatFormatting.DARK_GRAY)
                            : Component.translatable("hideandhunt.hud.taunt_ready", ClientModEvents.TAUNT.getTranslatedKeyMessage()).withStyle(ChatFormatting.LIGHT_PURPLE);
                }
            }
            case ENDING -> line1 = Component.translatable("hideandhunt.hud.round_over", s.secondsLeft());
        }

        int widest = font.width(sideLabel) + font.width(sideText) + 14;
        if (line1 != null) widest = Math.max(widest, font.width(line1));
        if (line2 != null) widest = Math.max(widest, font.width(line2));
        if (hidersTxt != null) widest = Math.max(widest, font.width(hidersTxt) + font.width(huntersTxt) + 12);
        if (timeLbl != null) widest = Math.max(widest, font.width("00:00") * 2 + font.width(timeLbl) + 8);
        if (tauntTxt != null) widest = Math.max(widest, font.width(tauntTxt));
        int w = Math.max(MIN_W, Math.min(MAX_W, widest + 10));

        // arena name gets whatever space the phase name leaves
        int nameMax = w - 14 - font.width(phaseName);
        String arena = font.plainSubstrByWidth(s.arena(), Math.max(20, nameMax));
        if (arena.length() < s.arena().length() && arena.length() > 1) arena = arena.substring(0, arena.length() - 1) + "…";

        int lines = switch (phase) {
            case LOBBY, COUNTDOWN -> 4;
            case ENDING -> 3;
            default -> 6;
        };
        if (tauntLine) lines++;
        int h = 8 + lines * 11;

        // ---------- position: avoid the centred boss bars (182 px wide) on narrow screens
        int x = 6, y = 6;
        if (g.guiWidth() < w * 2 + 196 && ClientState.bossBottom > 0) {
            y = ClientState.bossBottom + 4;
        }
        UiDraw.panel(g, x, y, w, h, accent, 1.0F);

        g.drawString(font, Component.literal(arena).withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD), x + 5, y + 5, 0xFFFFFFFF, true);
        g.drawString(font, phaseName, x + w - 5 - font.width(phaseName), y + 5, 0xFFBBBBCC, false);
        int ly = y + 17;

        g.drawString(font, sideLabel, x + 5, ly, 0xFFAAAAAA, false);
        UiDraw.badge(g, font, sideText, x + 8 + font.width(sideLabel), ly - 2, side.argb);
        ly += 13;

        switch (phase) {
            case LOBBY -> {
                g.drawString(font, line1, x + 5, ly, 0xFFCCCCCC, false);
                ly += 11;
                g.drawString(font, line2, x + 5, ly, 0xFF8888AA, false);
            }
            case COUNTDOWN -> {
                g.drawString(font, line1, x + 5, ly, 0xFFFFFF55, false);
                ly += 11;
                UiDraw.bar(g, x + 5, ly + 1, w - 10, 5, s.phaseTotal() <= 0 ? 0 : 1F - s.secondsLeft() / (float) s.phaseTotal(), 0xFFFFAA00);
            }
            case HIDING, HUNTING -> {
                int color = phase == Phase.HIDING ? 0xFF55FF7F : (s.secondsLeft() <= 30 ? 0xFFFFDD44 : 0xFFFF5555);
                String time = UiDraw.clock(s.secondsLeft());
                g.pose().pushPose();
                g.pose().translate(x + 5, ly - 1, 0);
                g.pose().scale(2F, 2F, 1F);
                g.drawString(font, time, 0, 0, color, true);
                g.pose().popPose();
                g.drawString(font, timeLbl, x + w - 5 - font.width(timeLbl), ly + 3, 0xFF9999AA, false);
                ly += 19;
                UiDraw.bar(g, x + 5, ly - 1, w - 10, 4, s.phaseTotal() <= 0 ? 0 : s.secondsLeft() / (float) s.phaseTotal(), color);
                ly += 6;
                g.drawString(font, hidersTxt, x + 5, ly, 0xFFCCCCCC, false);
                g.drawString(font, huntersTxt, x + w - 5 - font.width(huntersTxt), ly, 0xFFCCCCCC, false);
                ly += 11;
                int pips = Math.min(s.hidersTotal(), (w - 10) / 7);
                for (int i = 0; i < pips; i++) {
                    int px = x + 5 + i * 7;
                    g.fill(px, ly, px + 5, ly + 5, i < s.hidersAlive() ? 0xFF55FF7F : 0xFF553333);
                }
                ly += 8;
                if (tauntTxt != null) g.drawString(font, tauntTxt, x + 5, ly, 0xFFFFFFFF, false);
            }
            case ENDING -> g.drawString(font, line1, x + 5, ly, 0xFFFFDD44, false);
        }
    }
}
