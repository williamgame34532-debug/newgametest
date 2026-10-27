package com.williamgame.echoesofsleep.client.renderer;

import com.mojang.blaze3d.vertex.PoseStack;
import com.williamgame.echoesofsleep.client.model.MotherHandModel;
import com.williamgame.echoesofsleep.entity.MotherHand;
import net.minecraft.client.renderer.entity.EntityRendererProvider;

/** A hand pushing up through the floor: offset downwards until it has fully emerged. */
public class MotherHandRenderer extends NightmareRenderer<MotherHand, MotherHandModel> {
    private static final float DEPTH = 3.4F;

    public MotherHandRenderer(EntityRendererProvider.Context ctx) {
        super(ctx, new MotherHandModel(ctx.bakeLayer(MotherHandModel.LAYER)), 0.9F, "mother_hand");
    }

    @Override
    protected void setupRotations(MotherHand entity, PoseStack poseStack, float bob, float yBodyRot, float partialTick, float scale) {
        super.setupRotations(entity, poseStack, bob, yBodyRot, partialTick, scale);
        float p = MotherHandModel.emergeProgress(entity, partialTick);
        poseStack.translate(0.0F, -(1.0F - p) * DEPTH, 0.0F);
    }

    @Override
    protected float getFlipDegrees(MotherHand entity) {
        return 0.0F;
    }
}
