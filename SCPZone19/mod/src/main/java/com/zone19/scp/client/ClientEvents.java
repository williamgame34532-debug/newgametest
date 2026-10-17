package com.zone19.scp.client;

import com.zone19.scp.Zone19Mod;
import com.zone19.scp.client.render.GuardSkinRenderer;
import com.zone19.scp.client.screen.ScpButton;
import com.zone19.scp.client.screen.ScpTitleScreen;
import com.zone19.scp.client.screen.TerminalScreen;
import com.zone19.scp.config.Zone19Config;
import com.zone19.scp.network.BlinkNowPacket;
import com.zone19.scp.network.Net;
import com.zone19.scp.network.SkinSelectPacket;
import com.zone19.scp.registry.ModSounds;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.screens.PauseScreen;
import net.minecraft.client.gui.screens.TitleScreen;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.network.chat.Component;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.ClientPlayerNetworkEvent;
import net.minecraftforge.client.event.RenderArmEvent;
import net.minecraftforge.client.event.RenderPlayerEvent;
import net.minecraftforge.client.event.ScreenEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = Zone19Mod.MODID, value = Dist.CLIENT)
public final class ClientEvents {
    /** Set by the "classic menu" button: keep the vanilla title screen for this session. */
    public static boolean classicTitle;
    private static int ambientCooldown = 400;

    @SubscribeEvent
    public static void onScreenOpening(ScreenEvent.Opening event) {
        if (classicTitle || !(event.getNewScreen() instanceof TitleScreen)) return;
        if (Zone19Config.CLIENT_SPEC.isLoaded() && !Zone19Config.CLIENT.customTitleScreen.get()) return;
        event.setNewScreen(new ScpTitleScreen());
    }

    @SubscribeEvent
    public static void onScreenInit(ScreenEvent.Init.Post event) {
        if (event.getScreen() instanceof PauseScreen pause && Minecraft.getInstance().player != null) {
            event.addListener(new ScpButton(6, 6, 130, 18, Component.translatable("gui.scpzone19.terminal"),
                    b -> Minecraft.getInstance().setScreen(new TerminalScreen(pause))));
        }
    }

    @SubscribeEvent
    public static void onRenderPlayer(RenderPlayerEvent.Pre event) {
        GuardSkinRenderer.onRenderPlayer(event);
    }

    @SubscribeEvent
    public static void onRenderArm(RenderArmEvent event) {
        GuardSkinRenderer.onRenderArm(event);
    }

    @SubscribeEvent
    public static void onClientTick(TickEvent.ClientTickEvent event) {
        if (event.phase != TickEvent.Phase.END) return;
        Minecraft mc = Minecraft.getInstance();
        if (mc.player == null) return;
        ClientState.tick();
        while (Keys.TERMINAL.consumeClick()) {
            if (mc.screen == null) mc.setScreen(new TerminalScreen(null));
        }
        while (Keys.BLINK.consumeClick()) {
            if (ClientState.inZone()) Net.toServer(new BlinkNowPacket());
        }
        if (ClientState.inZone() && Zone19Config.CLIENT.ambientSounds.get() && !mc.isPaused() && --ambientCooldown <= 0) {
            ambientCooldown = 500 + mc.player.getRandom().nextInt(900);
            mc.getSoundManager().play(SimpleSoundInstance.forAmbientAddition(ModSounds.AMBIENT.get()));
        }
    }

    @SubscribeEvent
    public static void onLogin(ClientPlayerNetworkEvent.LoggingIn event) {
        Net.toServer(new SkinSelectPacket(Zone19Config.CLIENT.selectedSkin.get()));
    }

    @SubscribeEvent
    public static void onLogout(ClientPlayerNetworkEvent.LoggingOut event) {
        ClientState.reset();
        ClientPacketHandler.stopMusic();
    }

    private ClientEvents() {
    }
}
