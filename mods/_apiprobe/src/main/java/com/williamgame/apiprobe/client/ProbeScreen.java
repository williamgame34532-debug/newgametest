package com.williamgame.apiprobe.client;

import com.williamgame.apiprobe.ProbeActionPacket;
import com.williamgame.apiprobe.ProbeNetwork;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.AbstractSliderButton;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.network.chat.Component;

public class ProbeScreen extends Screen {
    private EditBox box;

    public ProbeScreen() {
        super(Component.literal("Probe"));
    }

    @Override
    protected void init() {
        addRenderableWidget(Button.builder(Component.literal("Go"), b -> ProbeNetwork.sendToServer(new ProbeActionPacket(1)))
                .bounds(width / 2 - 50, height / 2, 100, 20).build());
        box = addRenderableWidget(new EditBox(font, width / 2 - 50, height / 2 + 30, 100, 20, Component.literal("box")));
        addRenderableWidget(new AbstractSliderButton(width / 2 - 50, height / 2 + 60, 100, 20, Component.literal("5"), 0.5) {
            @Override
            protected void updateMessage() {
                setMessage(Component.literal(String.valueOf((int) (value * 10))));
            }

            @Override
            protected void applyValue() {
            }
        });
    }

    @Override
    public void render(GuiGraphics g, int mouseX, int mouseY, float partialTick) {
        super.render(g, mouseX, mouseY, partialTick);
        g.fill(10, 10, 110, 20, 0xAA6633AA);
        g.drawCenteredString(font, title, width / 2, 20, 0xFFFFFF);
    }

    @Override
    public boolean isPauseScreen() {
        return false;
    }
}
