package com.zone19.scp.client.render;

import com.zone19.scp.client.ClientState;
import com.zone19.scp.world.GuardSkin;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.player.PlayerRenderer;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.HumanoidArm;
import net.minecraftforge.client.event.RenderArmEvent;
import net.minecraftforge.client.event.RenderPlayerEvent;
import org.jetbrains.annotations.Nullable;

/**
 * Draws players who picked a personnel skin with that texture. The vanilla render call is
 * cancelled and replaced with our own PlayerRenderer, so it works for every player on a server.
 */
public final class GuardSkinRenderer {
    @Nullable
    private static PlayerRenderer renderer;
    private static boolean rendering;

    private static final class Skinned extends PlayerRenderer {
        Skinned(EntityRendererProvider.Context ctx) {
            super(ctx, false);
        }

        @Override
        public ResourceLocation getTextureLocation(AbstractClientPlayer player) {
            GuardSkin skin = ClientState.SKINS.get(player.getUUID());
            return skin != null ? skin.texture() : super.getTextureLocation(player);
        }
    }

    public static void init(EntityRendererProvider.Context ctx) {
        renderer = new Skinned(ctx);
    }

    public static void onRenderPlayer(RenderPlayerEvent.Pre event) {
        if (rendering || renderer == null) return;
        if (!(event.getEntity() instanceof AbstractClientPlayer player)) return;
        if (!ClientState.SKINS.containsKey(player.getUUID())) return;
        event.setCanceled(true);
        rendering = true;
        try {
            float yaw = Mth.lerp(event.getPartialTick(), player.yRotO, player.getYRot());
            renderer.render(player, yaw, event.getPartialTick(), event.getPoseStack(), event.getMultiBufferSource(), event.getPackedLight());
        } finally {
            rendering = false;
        }
    }

    /**
     * Forge fires RenderArmEvent from inside PlayerRenderer.renderRightHand/renderLeftHand, so our own
     * renderer re-enters this handler; the flag lets that inner call through to draw the arm.
     */
    public static void onRenderArm(RenderArmEvent event) {
        if (rendering || renderer == null || !ClientState.SKINS.containsKey(event.getPlayer().getUUID())) return;
        event.setCanceled(true);
        rendering = true;
        try {
            if (event.getArm() == HumanoidArm.RIGHT) {
                renderer.renderRightHand(event.getPoseStack(), event.getMultiBufferSource(), event.getPackedLight(), event.getPlayer());
            } else {
                renderer.renderLeftHand(event.getPoseStack(), event.getMultiBufferSource(), event.getPackedLight(), event.getPlayer());
            }
        } finally {
            rendering = false;
        }
    }

    private GuardSkinRenderer() {
    }
}
