package com.williamgame.echoesofsleep.client.renderer;

import com.mojang.blaze3d.vertex.PoseStack;
import com.williamgame.echoesofsleep.client.model.DeepMotherModel;
import com.williamgame.echoesofsleep.entity.DeepMother;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.util.Mth;

/** The Deep Mother rises out of (and sinks back into) the floor: the whole body is offset downwards. */
public class DeepMotherRenderer extends NightmareRenderer<DeepMother, DeepMotherModel> {
    private static final float DEPTH = 5.6F;

    public DeepMotherRenderer(EntityRendererProvider.Context ctx) {
        super(ctx, new DeepMotherModel(ctx.bakeLayer(DeepMotherModel.LAYER)), 2.0F, "deep_mother");
    }

    public static float sinkDepth(DeepMother e, float partial) {
        float t = e.tickCount - e.clientStateStart + partial;
        return switch (e.getMotherState()) {
            case DeepMother.EMERGING -> {
                float p = Mth.clamp(t / DeepMother.EMERGE_TICKS, 0.0F, 1.0F);
                yield (1.0F - p) * (1.0F - p) * DEPTH;
            }
            case DeepMother.SINKING -> {
                float p = Mth.clamp(t / DeepMother.SINK_TICKS, 0.0F, 1.0F);
                yield p * p * DEPTH;
            }
            case DeepMother.SUBMERGED -> DEPTH;
            default -> 0.0F;
        };
    }

    @Override
    protected void setupRotations(DeepMother entity, PoseStack poseStack, float bob, float yBodyRot, float partialTick, float scale) {
        super.setupRotations(entity, poseStack, bob, yBodyRot, partialTick, scale);
        float depth = sinkDepth(entity, partialTick);
        if (depth > 0.0F) {
            // shudder while breaking through the stone
            float shake = (entity.getRandom().nextFloat() - 0.5F) * 0.08F;
            poseStack.translate(shake, -depth, shake);
        }
    }

    @Override
    protected float getShadowRadius(DeepMother entity) {
        return entity.getMotherState() == DeepMother.ACTIVE ? 2.0F : 1.2F;
    }
}
