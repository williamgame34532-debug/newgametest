package com.williamgame.hideandhunt.client;

import com.williamgame.hideandhunt.game.Phase;
import com.williamgame.hideandhunt.game.Side;
import com.williamgame.hideandhunt.network.StatePacket;
import net.minecraft.ChatFormatting;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.network.chat.Component;

/** Top-left info panel: arena, phase, your side, timer, hiders left, hunters. */
public final class HudOverlay {
    private HudOverlay() {}

    public static void render(GuiGraphics g, float partialTick) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null || mc.options.hideGui) return;
        StatePacket s = ClientState.state;
        if (!s.visible()) return;
        Font font = mc.font;
        Phase phase = Phase.byOrdinal(s.phase());
        Side side = Side.byOrdinal(s.side());
        int accent = phase == Phase.LOBBY ? 0xFFFFAA00 : side.argb;
        if (phase != Phase.LOBBY && side == Side.NONE) accent = 0xFFFFAA00;

        int x = 6, y = 6, w = 150;
        int lines = phase == Phase.LOBBY ? 4 : phase == Phase.COUNTDOWN ? 4 : phase == Phase.ENDING ? 3 : 6;
        boolean tauntLine = (phase == Phase.HUNTING && side == Side.HIDER && s.alive() && s.taunts());
        if (tauntLine) lines++;
        int h = 8 + lines * 11;
        UiDraw.panel(g, x, y, w, h, accent, 1.0F);

        // header: arena name + phase
        Component phaseName = phase.displayName();
        g.drawString(font, Component.literal(s.arena()).withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD), x + 5, y + 5, 0xFFFFFFFF, true);
        g.drawString(font, phaseName, x + w - 5 - font.width(phaseName), y + 5, 0xFFBBBBCC, false);
        int ly = y + 17;

        Component sideText = side.displayName();
        if (phase.inRound() && side == Side.SPECTATOR) sideText = Component.translatable("hideandhunt.hud.eliminated").withStyle(ChatFormatting.GRAY);
        g.drawString(font, Component.translatable("hideandhunt.hud.side"), x + 5, ly, 0xFFAAAAAA, false);
        UiDraw.badge(g, font, sideText, x + 8 + font.width(Component.translatable("hideandhunt.hud.side")), ly - 2, side.argb);
        ly += 13;

        switch (phase) {
            case LOBBY -> {
                g.drawString(font, Component.translatable("hideandhunt.hud.lobby_counts",
                        Component.literal(String.valueOf(s.lobbyHiders())).withStyle(ChatFormatting.GREEN),
                        Component.literal(String.valueOf(s.lobbyHunters())).withStyle(ChatFormatting.RED),
                        Component.literal(String.valueOf(s.lobbyNone())).withStyle(ChatFormatting.WHITE)), x + 5, ly, 0xFFCCCCCC, false);
                ly += 11;
                String jm = switch (s.joinMode()) {
                    case 1 -> "pads";
                    case 2 -> "random";
                    case 3 -> "admin";
                    default -> "free";
                };
                g.drawString(font, Component.translatable("hideandhunt.hud.join." + jm), x + 5, ly, 0xFF8888AA, false);
            }
            case COUNTDOWN -> {
                g.drawString(font, Component.translatable("hideandhunt.hud.starting_in", s.secondsLeft()), x + 5, ly, 0xFFFFFF55, false);
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
                Component lbl = Component.translatable(phase == Phase.HIDING ? "hideandhunt.hud.hide_left" : "hideandhunt.hud.hunt_left");
                g.drawString(font, lbl, x + w - 5 - font.width(lbl), ly + 3, 0xFF9999AA, false);
                ly += 19;
                UiDraw.bar(g, x + 5, ly - 1, w - 10, 4, s.phaseTotal() <= 0 ? 0 : s.secondsLeft() / (float) s.phaseTotal(), color);
                ly += 6;
                g.drawString(font, Component.translatable("hideandhunt.hud.hiders_left",
                        Component.literal(s.hidersAlive() + "/" + s.hidersTotal()).withStyle(ChatFormatting.GREEN)), x + 5, ly, 0xFFCCCCCC, false);
                Component hun = Component.translatable("hideandhunt.hud.hunters", Component.literal(String.valueOf(s.hunters())).withStyle(ChatFormatting.RED));
                g.drawString(font, hun, x + w - 5 - font.width(hun), ly, 0xFFCCCCCC, false);
                ly += 11;
                // little hider pips
                int pips = Math.min(s.hidersTotal(), 20);
                for (int i = 0; i < pips; i++) {
                    int px = x + 5 + i * 7;
                    int c = i < s.hidersAlive() ? 0xFF55FF7F : 0xFF553333;
                    g.fill(px, ly, px + 5, ly + 5, c);
                }
                ly += 8;
                if (tauntLine) {
                    Component t = s.tauntCooldown() > 0
                            ? Component.translatable("hideandhunt.hud.taunt_cd", s.tauntCooldown()).withStyle(ChatFormatting.DARK_GRAY)
                            : Component.translatable("hideandhunt.hud.taunt_ready", ClientModEvents.TAUNT.getTranslatedKeyMessage()).withStyle(ChatFormatting.LIGHT_PURPLE);
                    g.drawString(font, t, x + 5, ly, 0xFFFFFFFF, false);
                }
            }
            case ENDING -> g.drawString(font, Component.translatable("hideandhunt.hud.round_over", s.secondsLeft()), x + 5, ly, 0xFFFFDD44, false);
        }
    }
}
