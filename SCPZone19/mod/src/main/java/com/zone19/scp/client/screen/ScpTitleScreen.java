package com.zone19.scp.client.screen;

import com.mojang.blaze3d.systems.RenderSystem;
import com.zone19.scp.Zone19Mod;
import com.zone19.scp.client.ClientEvents;
import com.zone19.scp.config.Zone19Config;
import net.minecraft.Util;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.OptionsScreen;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.gui.screens.TitleScreen;
import net.minecraft.client.gui.screens.multiplayer.JoinMultiplayerScreen;
import net.minecraft.client.gui.screens.worldselection.SelectWorldScreen;
import net.minecraft.client.renderer.CubeMap;
import net.minecraft.client.renderer.PanoramaRenderer;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraftforge.client.gui.ModListScreen;

import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

/**
 * Replacement title screen: the security terminal of Site-19. A rendered corridor turns slowly
 * behind the menu, lights flicker, SCP-173 lurks in the dark and the update feed sits on the right.
 */
public class ScpTitleScreen extends Screen {
    private static final CubeMap CUBE = new CubeMap(Zone19Mod.id("textures/gui/panorama/panorama"));
    private static final ResourceLocation SCP173 = Zone19Mod.id("textures/gui/scp173_back.png");
    private static final DateTimeFormatter CLOCK = DateTimeFormatter.ofPattern("HH:mm:ss");
    private static boolean popupShown;

    private final PanoramaRenderer panorama = new PanoramaRenderer(CUBE);
    private final RandomSource random = RandomSource.create();
    private UpdatesPanel updates;
    private float flicker = 1.0F;
    private int flickerTicks;
    private float lurk;
    private int ticks;

    public ScpTitleScreen() {
        super(Component.translatable("gui.scpzone19.title"));
    }

    @Override
    protected void init() {
        int left = 26;
        int bw = 176, bh = 20, gap = 4;
        int y = Math.max(100, height / 2 - 62);
        addRenderableWidget(new ScpButton(left, y, bw, bh, Component.translatable("menu.scpzone19.campaign"),
                b -> minecraft.setScreen(new SelectWorldScreen(this))));
        y += bh + gap;
        addRenderableWidget(new ScpButton(left, y, bw, bh, Component.translatable("menu.scpzone19.multiplayer"),
                b -> minecraft.setScreen(new JoinMultiplayerScreen(this))));
        y += bh + gap;
        addRenderableWidget(new ScpButton(left, y, bw, bh, Component.translatable("menu.scpzone19.personnel"),
                b -> minecraft.setScreen(new SkinSelectScreen(this))));
        y += bh + gap;
        addRenderableWidget(new ScpButton(left, y, bw, bh, Component.translatable("menu.scpzone19.archive"),
                b -> minecraft.setScreen(new ArchiveScreen(this))));
        y += bh + gap;
        addRenderableWidget(new ScpButton(left, y, bw, bh, Component.translatable("menu.scpzone19.options"),
                b -> minecraft.setScreen(new OptionsScreen(this, minecraft.options))));
        y += bh + gap;
        addRenderableWidget(new ScpButton(left, y, bw / 2 - 2, bh, Component.translatable("menu.scpzone19.mods"),
                b -> minecraft.setScreen(new ModListScreen(this))));
        addRenderableWidget(new ScpButton(left + bw / 2 + 2, y, bw / 2 - 2, bh, Component.translatable("menu.scpzone19.updates"),
                b -> minecraft.setScreen(new UpdatesScreen(this))));
        y += bh + gap + 6;
        addRenderableWidget(new ScpButton(left, y, bw, bh, Component.translatable("menu.scpzone19.quit"),
                b -> minecraft.stop()));
        addRenderableWidget(new ScpButton(width - 112, height - 34, 104, 16, Component.translatable("menu.scpzone19.classic"), b -> {
            ClientEvents.classicTitle = true;
            minecraft.setScreen(new TitleScreen());
        }));

        int pw = Math.min(230, width - bw - 80);
        if (updates == null) updates = new UpdatesPanel(font, 0, 0, 0, 0);
        updates.setBounds(width - pw - 12, 14, pw, height - 56);
    }

    @Override
    public void tick() {
        ticks++;
        if (!popupShown && ticks == 2) {
            popupShown = true;
            if (Zone19Config.CLIENT.showUpdatesPopup.get() && !Zone19Mod.VERSION.equals(Zone19Config.CLIENT.lastSeenUpdate.get())) {
                minecraft.setScreen(new UpdatesScreen(this));
            }
        }
        if (flickerTicks > 0) {
            flickerTicks--;
            flicker = random.nextFloat() < 0.5F ? 0.35F : 1.0F;
        } else {
            flicker = 1.0F;
            if (random.nextInt(140) == 0) flickerTicks = 4 + random.nextInt(8);
        }
    }

    @Override
    public void render(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        panorama.render(partialTick, 1.0F);
        g.fillGradient(0, 0, width, height, 0x99000000, 0xDD000000);
        if (flicker < 1.0F) g.fill(0, 0, width, height, 0x88000000);

        // SCP-173 standing in the dark, only visible when the lights stutter
        lurk = Mth.lerp(0.08F, lurk, flicker < 1.0F ? 0.55F : 0.12F);
        int sh = (int) (height * 0.78F), sw = sh * 312 / 441;
        RenderSystem.enableBlend();
        g.setColor(1.0F, 1.0F, 1.0F, lurk);
        g.blit(SCP173, width / 2 - sw / 4, height - sh, sw, sh, 0, 0, 312, 441, 312, 441);
        g.setColor(1.0F, 1.0F, 1.0F, 1.0F);

        // left column
        g.fillGradient(0, 0, 230, height, 0xE0060708, 0xC0060708);
        g.fill(229, 0, 230, height, ScpStyle.RED_DIM);
        g.blit(ScpStyle.LOGO, 14, 18, 256, 64, 0, 0, 512, 128, 512, 128);
        RenderSystem.disableBlend();

        long ms = Util.getMillis();
        boolean pulse = (ms / 600) % 2 == 0;
        g.drawString(font, Component.translatable("gui.scpzone19.status"), 26, Math.max(100, height / 2 - 62) - 16,
                pulse ? ScpStyle.AMBER : 0xFF8C6B1C, false);

        updates.render(g);

        // bottom ticker
        int by = height - 14;
        g.fill(0, by, width, height, 0xE0050505);
        g.fill(0, by, width, by + 1, ScpStyle.RED_DIM);
        String clock = LocalTime.now().format(CLOCK);
        Component left = Component.translatable("gui.scpzone19.footer", Zone19Mod.VERSION, clock);
        g.drawString(font, left, 6, by + 3, ScpStyle.DIM, false);
        int tickerX = 12 + font.width(left) + 12;
        Component ticker = Component.translatable("gui.scpzone19.ticker");
        int tw = font.width(ticker);
        int span = width - tickerX - 8;
        if (span > 40) {
            int offset = (int) (ms / 30 % (tw + span));
            g.enableScissor(tickerX, by, width - 8, height);
            g.drawString(font, ticker, tickerX + span - offset, by + 3, 0xFFB03A32, false);
            g.disableScissor();
        }
        ScpStyle.scanlines(g, width, height);
        super.render(g, mouseX, mouseY, partialTick);
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double delta) {
        if (updates != null && updates.isMouseOver(mouseX, mouseY)) {
            updates.scroll(delta);
            return true;
        }
        return super.mouseScrolled(mouseX, mouseY, delta);
    }

    @Override
    public boolean shouldCloseOnEsc() {
        return false;
    }

    @Override
    public boolean isPauseScreen() {
        return false;
    }
}
