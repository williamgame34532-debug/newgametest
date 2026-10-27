package com.williamgame.echoesofsleep.client.renderer;

import com.mojang.blaze3d.vertex.PoseStack;
import com.williamgame.echoesofsleep.client.model.DreamerModel;
import com.williamgame.echoesofsleep.entity.TheDreamer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;

/** The Dreamer is drawn 1.5x larger than its model so it towers over everything else in the dream. */
public class DreamerRenderer extends NightmareRenderer<TheDreamer, DreamerModel> {
    public static final float SCALE = 1.5F;

    public DreamerRenderer(EntityRendererProvider.Context ctx) {
        super(ctx, new DreamerModel(ctx.bakeLayer(DreamerModel.LAYER)), 1.8F, "the_dreamer");
    }

    @Override
    protected void scale(TheDreamer entity, PoseStack poseStack, float partialTick) {
        poseStack.scale(SCALE, SCALE, SCALE);
    }
}
