package com.zone19.scp.client.screen;

import com.mojang.blaze3d.systems.RenderSystem;
import com.zone19.scp.config.Zone19Config;
import com.zone19.scp.network.Net;
import com.zone19.scp.network.SkinSelectPacket;
import com.zone19.scp.world.GuardSkin;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.resources.DefaultPlayerSkin;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.FormattedCharSequence;
import org.jetbrains.annotations.Nullable;

import java.util.ArrayList;
import java.util.List;

/** Personnel file: pick the uniform you wear in the facility (synced to everyone on a server). */
public class SkinSelectScreen extends Screen {
    @Nullable
    private final Screen parent;
    private GuardSkin chosen;
    private final List<ScpButton> entries = new ArrayList<>();

    public SkinSelectScreen(@Nullable Screen parent) {
        super(Component.translatable("gui.scpzone19.personnel"));
        this.parent = parent;
        GuardSkin saved = GuardSkin.byId(Zone19Config.CLIENT.selectedSkin.get());
        this.chosen = saved != null ? saved : GuardSkin.GUARD_STANDARD;
    }

    @Override
    protected void init() {
        entries.clear();
        int x = width / 2 - 200, y = 50;
        for (GuardSkin skin : GuardSkin.values()) {
            ScpButton b = new ScpButton(x, y, 150, 18, Component.translatable(skin.nameKey()), btn -> pick(skin));
            b.selected(skin == chosen);
            entries.add(addRenderableWidget(b));
            y += 21;
        }
        addRenderableWidget(new ScpButton(width / 2 + 60, height - 40, 140, 20, Component.translatable("gui.scpzone19.assign"), b -> apply()));
        addRenderableWidget(new ScpButton(width / 2 - 200, height - 40, 100, 20, Component.translatable("gui.back"), b -> onClose()));
    }

    private void pick(GuardSkin skin) {
        chosen = skin;
        for (int i = 0; i < entries.size(); i++) entries.get(i).selected(GuardSkin.values()[i] == skin);
    }

    private void apply() {
        Zone19Config.CLIENT.selectedSkin.set(chosen.id());
        Zone19Config.CLIENT.selectedSkin.save();
        if (minecraft.getConnection() != null && minecraft.player != null) {
            Net.toServer(new SkinSelectPacket(chosen.id()));
        }
        onClose();
    }

    @Override
    public void render(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        if (minecraft.level == null) ScpStyle.background(g, width, height);
        else renderBackground(g);
        ScpStyle.header(g, font, width / 2 - 200, 26, 400, title);

        int px = width / 2 - 34, py = 46, pw = 234, ph = height - 100;
        ScpStyle.panel(g, px, py, pw, ph);
        ResourceLocation tex = chosen == GuardSkin.DEFAULT
                ? DefaultPlayerSkin.getDefaultSkin(minecraft.getUser().getProfileId())
                : chosen.texture();
        int scale = Math.max(2, Math.min(5, (ph - 70) / 32));
        drawDoll(g, tex, px + 14, py + 12, scale, false);
        drawDoll(g, tex, px + 30 + 16 * scale, py + 12, scale, true);

        int ty = py + 20 + 32 * scale;
        g.drawString(font, Component.translatable(chosen.nameKey()), px + 10, ty, ScpStyle.RED, false);
        ty += 12;
        for (FormattedCharSequence line : font.split(Component.translatable(chosen.descKey()), pw - 20)) {
            g.drawString(font, line, px + 10, ty, 0xFFB8BBBF, false);
            ty += 10;
        }
        ScpStyle.scanlines(g, width, height);
        super.render(g, mouseX, mouseY, partialTick);
    }

    /** Front or back view of a 64x64 skin, painted part by part (base layer + overlay). */
    static void drawDoll(GuiGraphics g, ResourceLocation tex, int x, int y, int s, boolean back) {
        RenderSystem.enableBlend();
        int[][] front = {
                // dx, dy, w, h, u, v  (base then overlay)
                {4, 0, 8, 8, 8, 8}, {4, 8, 8, 12, 20, 20}, {0, 8, 4, 12, 44, 20}, {12, 8, 4, 12, 36, 52},
                {4, 20, 4, 12, 4, 20}, {8, 20, 4, 12, 20, 52},
                {4, 0, 8, 8, 40, 8}, {4, 8, 8, 12, 20, 36}, {0, 8, 4, 12, 44, 36}, {12, 8, 4, 12, 52, 52},
                {4, 20, 4, 12, 4, 36}, {8, 20, 4, 12, 4, 52}};
        int[][] rear = {
                {4, 0, 8, 8, 24, 8}, {4, 8, 8, 12, 32, 20}, {12, 8, 4, 12, 52, 20}, {0, 8, 4, 12, 44, 52},
                {8, 20, 4, 12, 12, 20}, {4, 20, 4, 12, 28, 52},
                {4, 0, 8, 8, 56, 8}, {4, 8, 8, 12, 32, 36}, {12, 8, 4, 12, 52, 36}, {0, 8, 4, 12, 60, 52},
                {8, 20, 4, 12, 12, 36}, {4, 20, 4, 12, 12, 52}};
        for (int[] p : back ? rear : front) {
            g.blit(tex, x + p[0] * s, y + p[1] * s, p[2] * s, p[3] * s, p[4], p[5], p[2], p[3], 64, 64);
        }
        RenderSystem.disableBlend();
    }

    @Override
    public void onClose() {
        minecraft.setScreen(parent);
    }
}
