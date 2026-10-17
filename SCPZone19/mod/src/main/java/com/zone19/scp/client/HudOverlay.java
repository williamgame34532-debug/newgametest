package com.zone19.scp.client;

import com.mojang.blaze3d.systems.RenderSystem;
import com.zone19.scp.Zone19Mod;
import com.zone19.scp.client.screen.ScpStyle;
import com.zone19.scp.item.GunItem;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.FormattedCharSequence;
import net.minecraft.util.Mth;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.client.gui.overlay.ForgeGui;

import java.util.List;

/** Objective panel, SCP:CB blink meter, radio subtitles, chapter title cards and ammo counter. */
public final class HudOverlay {
    private static final ResourceLocation BLINK_ICON = Zone19Mod.id("textures/gui/blink_icon.png");

    public static void render(ForgeGui gui, GuiGraphics g, float partialTick, int w, int h) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null || mc.options.hideGui) return;
        Font font = mc.font;
        boolean zone = ClientState.inZone();

        if (zone && ClientState.blinking) g.fill(0, 0, w, h, 0xFF000000);
        if (zone) {
            objective(g, font, mc);
            blinkMeter(g, h);
        }
        ammo(g, font, mc, w, h);
        dialogue(g, font, w, h, partialTick);
        title(g, font, w, h, partialTick);
    }

    private static void objective(GuiGraphics g, Font font, Minecraft mc) {
        if (ClientState.chapter <= 0) return;
        int x = 6, y = 6, w = 200;
        Component head = ClientState.finished
                ? Component.translatable("ending.scpzone19.title")
                : Component.translatable("gui.scpzone19.hud_chapter", ClientState.chapter,
                Component.translatable("chapter.scpzone19." + ClientState.chapter + ".title"));
        Component body;
        if (ClientState.finished) {
            body = Component.translatable("gui.scpzone19.hud_done");
        } else {
            body = Component.translatable(ClientState.objective);
            if (ClientState.required > 1) {
                body = Component.translatable("gui.scpzone19.objective_progress", body, ClientState.progress, ClientState.required);
            }
        }
        List<FormattedCharSequence> lines = font.split(body, w - 12);
        String dist = null;
        if (ClientState.waypoint != null && !ClientState.finished) {
            double dx = ClientState.waypoint.getX() + 0.5 - mc.player.getX();
            double dz = ClientState.waypoint.getZ() + 0.5 - mc.player.getZ();
            dist = Component.translatable("gui.scpzone19.hud_distance", (int) Math.sqrt(dx * dx + dz * dz)).getString();
        }
        int hgt = 16 + lines.size() * 10 + (dist != null ? 10 : 0);
        g.fill(x, y, x + w, y + hgt, 0x88000000);
        g.fill(x, y, x + 2, y + hgt, ScpStyle.RED);
        g.drawString(font, head, x + 6, y + 4, ScpStyle.RED, false);
        int ly = y + 15;
        for (FormattedCharSequence l : lines) {
            g.drawString(font, l, x + 6, ly, ScpStyle.TEXT, false);
            ly += 10;
        }
        if (dist != null) g.drawString(font, dist, x + 6, ly, ScpStyle.DIM, false);
    }

    private static void blinkMeter(GuiGraphics g, int h) {
        if (ClientState.blinkMeter < 0) return;
        int x = 6, y = h - 22;
        RenderSystem.enableBlend();
        g.blit(BLINK_ICON, x, y, 14, 14, 0, 0, 30, 30, 30, 30);
        RenderSystem.disableBlend();
        int segs = 20;
        int filled = Mth.ceil(segs * (float) ClientState.blinkMeter / ClientState.blinkMax);
        g.fill(x + 17, y + 1, x + 19 + segs * 4, y + 13, 0x88000000);
        for (int i = 0; i < segs; i++) {
            int color = i >= filled ? 0xFF2A2A2A : filled <= 4 ? 0xFFC42822 : 0xFFE6E6E6;
            g.fill(x + 19 + i * 4, y + 3, x + 22 + i * 4, y + 11, color);
        }
    }

    private static void ammo(GuiGraphics g, Font font, Minecraft mc, int w, int h) {
        ItemStack held = mc.player.getMainHandItem();
        if (!(held.getItem() instanceof GunItem gun)) return;
        int mag = GunItem.getAmmo(held);
        int reserve = GunItem.countReserve(mc.player, gun.ammoItem());
        String text = mag + " / " + reserve;
        int tw = font.width(text);
        int x = w - tw - 14, y = h - 22;
        g.fill(x - 6, y - 3, w - 6, y + 11, 0x88000000);
        g.fill(w - 8, y - 3, w - 6, y + 11, ScpStyle.RED);
        g.drawString(font, text, x, y, mag == 0 ? ScpStyle.RED : ScpStyle.TEXT, false);
    }

    private static int speakerColor(String speaker) {
        return switch (speaker) {
            case "cassie" -> ScpStyle.AMBER;
            case "harris" -> 0xFF6FA8DC;
            case "lin" -> ScpStyle.GREEN;
            case "vance" -> 0xFFE2E2E2;
            case "mtf" -> ScpStyle.RED;
            default -> ScpStyle.DIM;
        };
    }

    private static void dialogue(GuiGraphics g, Font font, int w, int h, float partialTick) {
        ClientState.Dialogue d = ClientState.dialogue;
        if (d == null) return;
        float t = ClientState.dialogueTicks - partialTick;
        float alpha = Mth.clamp(Math.min(t, d.total() - t) / 8.0F, 0.0F, 1.0F);
        if (alpha <= 0.05F) return;
        int a = (int) (alpha * 255) << 24;
        int bw = Math.min(340, w - 40);
        List<FormattedCharSequence> lines = font.split(Component.translatable(d.key()), bw - 16);
        int bh = 18 + lines.size() * 10;
        int x = (w - bw) / 2, y = h - 72 - bh;
        g.fill(x, y, x + bw, y + bh, (int) (alpha * 0xAA) << 24);
        g.fill(x, y, x + 2, y + bh, (speakerColor(d.speaker()) & 0xFFFFFF) | a);
        g.drawString(font, Component.translatable("speaker.scpzone19." + d.speaker()), x + 8, y + 4,
                (speakerColor(d.speaker()) & 0xFFFFFF) | a, false);
        int ly = y + 15;
        for (FormattedCharSequence l : lines) {
            g.drawString(font, l, x + 8, ly, 0xE6E6E6 | a, false);
            ly += 10;
        }
    }

    private static void title(GuiGraphics g, Font font, int w, int h, float partialTick) {
        if (ClientState.titleTicks <= 0 || ClientState.titleKey == null) return;
        float t = ClientState.titleTicks - partialTick;
        float alpha = Mth.clamp(Math.min(t, ClientState.titleTotal - t) / 15.0F, 0.0F, 1.0F);
        if (alpha <= 0.05F) return;
        int a = (int) (alpha * 255) << 24;
        Component title = Component.translatable(ClientState.titleKey);
        Component sub = Component.translatable(ClientState.subtitleKey);
        g.fill(0, h / 3 - 24, w, h / 3 + 42, (int) (alpha * 0x99) << 24);
        g.pose().pushPose();
        g.pose().translate(w / 2.0F, h / 3.0F - 12, 0);
        g.pose().scale(2.5F, 2.5F, 1.0F);
        g.drawString(font, title, -font.width(title) / 2, 0, 0xEEEEEE | a, true);
        g.pose().popPose();
        g.fill(w / 2 - 80, h / 3 + 16, w / 2 + 80, h / 3 + 17, (ScpStyle.RED & 0xFFFFFF) | a);
        g.drawString(font, sub, (w - font.width(sub)) / 2, h / 3 + 24, 0xC42822 | a, false);
    }

    private HudOverlay() {
    }
}
