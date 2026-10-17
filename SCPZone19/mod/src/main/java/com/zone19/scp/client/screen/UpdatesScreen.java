package com.zone19.scp.client.screen;

import com.zone19.scp.Zone19Mod;
import com.zone19.scp.config.Zone19Config;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.network.chat.Component;
import org.jetbrains.annotations.Nullable;

/** "What's new" window, shown once per version and from the menu. */
public class UpdatesScreen extends Screen {
    @Nullable
    private final Screen parent;
    private UpdatesPanel panel;

    public UpdatesScreen(@Nullable Screen parent) {
        super(Component.translatable("gui.scpzone19.updates"));
        this.parent = parent;
    }

    @Override
    protected void init() {
        int pw = Math.min(360, width - 40), ph = Math.min(300, height - 60);
        int px = (width - pw) / 2, py = (height - ph) / 2 - 10;
        panel = new UpdatesPanel(font, px, py, pw, ph);
        addRenderableWidget(new ScpButton(width / 2 - 60, py + ph + 6, 120, 20, Component.translatable("gui.scpzone19.ack"),
                b -> onClose()));
    }

    @Override
    public void render(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        if (parent != null) parent.render(g, -1, -1, partialTick);
        g.fill(0, 0, width, height, 0xB0000000);
        panel.render(g);
        super.render(g, mouseX, mouseY, partialTick);
    }

    @Override
    public boolean mouseScrolled(double mouseX, double mouseY, double delta) {
        panel.scroll(delta);
        return true;
    }

    @Override
    public void onClose() {
        Zone19Config.CLIENT.lastSeenUpdate.set(Zone19Mod.VERSION);
        Zone19Config.CLIENT.lastSeenUpdate.save();
        minecraft.setScreen(parent);
    }
}
