package com.williamgame.echoesofsleep.client.renderer;

import com.mojang.blaze3d.vertex.PoseStack;
import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.client.model.DoppelgangerModel;
import com.williamgame.echoesofsleep.entity.EchoDoppelganger;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.LivingEntityRenderer;
import net.minecraft.client.renderer.entity.RenderLayerParent;
import net.minecraft.client.renderer.entity.layers.RenderLayer;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.ResourceLocation;

/** Paints over the borrowed face: a smeared, empty skin with two pin-prick lights where the eyes were. */
public class DoppelgangerMaskLayer extends RenderLayer<EchoDoppelganger, DoppelgangerModel> {
    private static final ResourceLocation MASK = EchoesOfSleep.id("textures/entity/echo_doppelganger_face.png");
    private static final ResourceLocation MASK_EYES = EchoesOfSleep.id("textures/entity/echo_doppelganger_face_eyes.png");

    public DoppelgangerMaskLayer(RenderLayerParent<EchoDoppelganger, DoppelgangerModel> parent) {
        super(parent);
    }

    @Override
    public void render(PoseStack poseStack, MultiBufferSource buffer, int light, EchoDoppelganger entity,
                       float limbSwing, float limbSwingAmount, float partialTick, float ageInTicks, float netHeadYaw, float headPitch) {
        if (entity.isInvisible()) return;
        DoppelgangerModel model = getParentModel();
        model.renderMask(poseStack, buffer.getBuffer(RenderType.entityTranslucent(MASK)), light,
                LivingEntityRenderer.getOverlayCoords(entity, 0.0F), 0xFFFFFFFF);
        // the eye-lights flicker out now and then
        if ((entity.tickCount / 3 + entity.getId()) % 23 != 0) {
            model.renderMask(poseStack, buffer.getBuffer(RenderType.eyes(MASK_EYES)), 15728640, OverlayTexture.NO_OVERLAY, 0xFFFFFFFF);
        }
    }
}
