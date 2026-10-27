package com.williamgame.echoesofsleep.client;

import com.mojang.blaze3d.systems.RenderSystem;
import com.williamgame.echoesofsleep.EchoesOfSleep;
import net.minecraft.client.DeltaTracker;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;

/** HUD layer: vignette, film grain, frame-skip flicker, wake-up flash and HUD numbers that lie. */
public final class DistortionOverlay {
    private static final ResourceLocation VIGNETTE = EchoesOfSleep.id("textures/misc/dream_vignette.png");
    private static final ResourceLocation GRAIN = EchoesOfSleep.id("textures/misc/dream_grain.png");
    private static final float[][] VIGNETTE_TINT = {{0, 0, 0}, {0.25F, 0.25F, 0.3F}, {0.35F, 0.08F, 0.45F}, {0.55F, 0.0F, 0.05F}};

    private DistortionOverlay() {
    }

    public static void render(GuiGraphics g, DeltaTracker delta) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null || mc.options.hideGui) return;
        int w = g.guiWidth();
        int h = g.guiHeight();
        float k = Math.min(1.5F, ClientDistortion.intensity());
        int lvl = Mth.clamp(ClientDistortion.level, 0, 3);
        float t = ClientDistortion.clientTicks + delta.getGameTimeDeltaPartialTick(true);

        RenderSystem.disableDepthTest();
        RenderSystem.depthMask(false);
        RenderSystem.enableBlend();
        RenderSystem.defaultBlendFunc();

        if (k > 0.0F && lvl > 0) {
            // pulsing coloured vignette
            float pulse = 0.85F + 0.15F * Mth.sin(t * 0.08F);
            float[] c = VIGNETTE_TINT[lvl];
            g.setColor(c[0], c[1], c[2], Math.min(1.0F, k * (0.45F + 0.18F * lvl) * pulse));
            g.blit(VIGNETTE, 0, 0, 0.0F, 0.0F, w, h, w, h);
            // film grain, jumping every frame
            g.setColor(1.0F, 1.0F, 1.0F, Math.min(0.5F, k * 0.07F * lvl));
            int gu = (int) ((ClientDistortion.clientTicks * 37L) % 128L), gv = (int) ((ClientDistortion.clientTicks * 53L) % 128L);
            g.blit(GRAIN, 0, 0, gu, gv, w, h, 128, 128);
            g.setColor(1.0F, 1.0F, 1.0F, 1.0F);
        }

        // frame-skip glitch: one or two black frames chosen per client tick, torn bands that change per tick
        if (ClientDistortion.glitchTicks > 0) {
            boolean soft = ClientDistortion.reduceFlashing();
            if (ClientDistortion.blackFrameNow()) {
                g.fill(0, 0, w, h, 0xB0000000);
            } else {
                RandomSource bandRandom = RandomSource.create(ClientDistortion.clientTicks * 31L + 7L);
                int bands = 3 + bandRandom.nextInt(5);
                for (int i = 0; i < bands; i++) {
                    int y = bandRandom.nextInt(h);
                    int bh = 1 + bandRandom.nextInt(Math.max(1, h / 30));
                    int off = bandRandom.nextInt(40) - 20;
                    int color = switch (bandRandom.nextInt(3)) {
                        case 0 -> 0x55FF0030;
                        case 1 -> 0x5500FFD0;
                        default -> 0x66000000;
                    };
                    if (soft) color = (color & 0x00FFFFFF) | 0x22000000;
                    g.fill(Math.max(0, off), y, Math.min(w, w + off), y + bh, color);
                }
            }
        }

        // the HUD lies: the experience level shows numbers that are not yours
        if (ClientDistortion.wrongNumberTicks > 0 && mc.gameMode != null && mc.gameMode.hasExperience()) {
            String fake = switch ((int) (t / 6) % 5) {
                case 0 -> "0";
                case 1 -> "-1";
                case 2 -> String.valueOf(3 + (int) (t % 7));
                case 3 -> "13";
                default -> "666";
            };
            int x = (w - mc.font.width(fake)) / 2 + ((ClientDistortion.clientTicks % 5 == 0) ? 1 : 0);
            int y = h - 31 - 4;
            g.fill(x - 3, y - 2, x + mc.font.width(fake) + 3, y + 10, 0xFF000000);
            g.drawString(mc.font, fake, x + 1, y, 0x000000, false);
            g.drawString(mc.font, fake, x - 1, y, 0x000000, false);
            g.drawString(mc.font, fake, x, y + 1, 0x000000, false);
            g.drawString(mc.font, fake, x, y - 1, 0x000000, false);
            g.drawString(mc.font, fake, x, y, 0xB0203A, false);
        }

        // wake-up / pulse flash
        if (ClientDistortion.flashTicks > 0 && ClientDistortion.flashMax > 0) {
            float a = (float) ClientDistortion.flashTicks / ClientDistortion.flashMax;
            float maxAlpha = ClientDistortion.reduceFlashing() ? 0.3F : 1.0F;
            int alpha = (int) (Math.min(maxAlpha, a * a * 1.2F * maxAlpha) * 255.0F);
            g.fill(0, 0, w, h, (alpha << 24) | (ClientDistortion.flashColor & 0xFFFFFF));
        }

        RenderSystem.depthMask(true);
        RenderSystem.enableDepthTest();
    }
}
