package com.williamgame.echoesofsleep.client;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.FogRenderer;
import net.minecraft.util.Mth;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.ClientPlayerNetworkEvent;
import net.minecraftforge.client.event.ViewportEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

/** Fog, sky tint, camera sway and FOV breathing while the world is dreaming. */
@Mod.EventBusSubscriber(modid = EchoesOfSleep.MODID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
public final class ClientForgeEvents {
    // fog colours per level: ashen grey, bruise purple, blood red
    private static final float[][] TINT = {{0, 0, 0}, {0.42F, 0.42F, 0.47F}, {0.30F, 0.10F, 0.36F}, {0.40F, 0.02F, 0.04F}};
    private static final float[] FOG_FAR = {1.0F, 0.72F, 0.45F, 0.26F};

    private ClientForgeEvents() {
    }

    @SubscribeEvent
    public static void onClientTick(TickEvent.ClientTickEvent.Post event) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.level == null || mc.player == null) return;
        if (mc.isPaused()) return;
        ClientDistortion.tick(mc);
    }

    @SubscribeEvent
    public static void onLogout(ClientPlayerNetworkEvent.LoggingOut event) {
        ClientDistortion.reset();
    }

    private static int lvl() {
        return Mth.clamp(ClientDistortion.level, 0, 3);
    }

    @SubscribeEvent
    public static void fogColor(ViewportEvent.ComputeFogColor event) {
        float k = ClientDistortion.intensity();
        if (k <= 0.0F) return;
        int l = lvl();
        float mix = Math.min(0.85F, k * (0.35F + 0.15F * l));
        // the colour breathes slowly
        mix *= 0.85F + 0.15F * Mth.sin(ClientDistortion.clientTicks * 0.03F);
        event.setRed(Mth.lerp(mix, event.getRed(), TINT[l][0]));
        event.setGreen(Mth.lerp(mix, event.getGreen(), TINT[l][1]));
        event.setBlue(Mth.lerp(mix, event.getBlue(), TINT[l][2]));
    }

    @SubscribeEvent
    public static void fog(ViewportEvent.RenderFog event) {
        float k = Math.min(1.0F, ClientDistortion.intensity());
        if (k <= 0.0F || event.getMode() != FogRenderer.FogMode.FOG_TERRAIN) return;
        int l = lvl();
        float target = FOG_FAR[l];
        if (ClientDistortion.glitchTicks > 0) target *= 0.5F;
        float scale = Mth.lerp(k, 1.0F, target);
        float far = event.getFarPlaneDistance() * scale;
        event.setFarPlaneDistance(far);
        event.setNearPlaneDistance(Math.min(event.getNearPlaneDistance(), far * 0.08F));
        event.setCanceled(true);
    }

    @SubscribeEvent
    public static void camera(ViewportEvent.ComputeCameraAngles event) {
        float k = ClientDistortion.intensity();
        float shake = ClientDistortion.shake;
        if (k <= 0.0F && shake <= 0.01F) return;
        float t = ClientDistortion.clientTicks + (float) event.getPartialTick();
        int l = lvl();
        float sway = Mth.sin(t * 0.025F) * 0.9F * l * k + Mth.sin(t * 0.061F) * 0.35F * l * k;
        float jitter = shake > 0.01F ? (float) (Math.random() - 0.5) * shake * 3.0F : 0.0F;
        event.setRoll(event.getRoll() + sway + jitter);
        if (shake > 0.01F) {
            event.setPitch(event.getPitch() + (float) (Math.random() - 0.5) * shake * 1.5F);
            event.setYaw(event.getYaw() + (float) (Math.random() - 0.5) * shake * 1.5F);
        }
    }

    @SubscribeEvent
    public static void fov(ViewportEvent.ComputeFov event) {
        float k = ClientDistortion.intensity();
        if (k <= 0.0F) return;
        float t = ClientDistortion.clientTicks + (float) event.getPartialTick();
        double breathe = 1.0 + Mth.sin(t * 0.05F) * 0.018 * lvl() * k;
        event.setFOV(event.getFOV() * breathe);
    }
}
