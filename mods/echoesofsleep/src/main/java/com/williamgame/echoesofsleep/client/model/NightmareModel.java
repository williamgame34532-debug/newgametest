package com.williamgame.echoesofsleep.client.model;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import net.minecraft.client.model.EntityModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Entity;

/**
 * Base for the hand-built nightmare models: resets every part to its baked pose each frame and offers
 * deterministic noise helpers for stop-motion jitter, twitches and slow drifting motions.
 */
public abstract class NightmareModel<T extends Entity> extends EntityModel<T> {
    protected final ModelPart root;

    protected NightmareModel(ModelPart root) {
        super(RenderType::entityCutoutNoCull);
        this.root = root;
    }

    public ModelPart root() {
        return root;
    }

    protected void resetAll() {
        // PartPose in 1.21.1 carries no scale, so scales are reset by hand
        root.getAllParts().forEach(p -> {
            p.resetPose();
            p.xScale = 1.0F;
            p.yScale = 1.0F;
            p.zScale = 1.0F;
        });
    }

    @Override
    public void renderToBuffer(PoseStack poseStack, VertexConsumer buffer, int packedLight, int packedOverlay, int color) {
        root.render(poseStack, buffer, packedLight, packedOverlay, color);
    }

    /** Integer hash to [-1, 1]. */
    protected static float hash(int n) {
        n = (n << 13) ^ n;
        return 1.0F - ((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) / 1073741824.0F;
    }

    /** A random value that only changes every {@code step} ticks: stop-motion jitter. */
    protected static float stepNoise(float age, float step, int seed) {
        return hash(Mth.floor(age / step) * 7919 + seed * 104729);
    }

    /** Smooth value noise in [-1, 1]. */
    protected static float smooth(float t, int seed) {
        int i = Mth.floor(t);
        float f = t - i;
        f = f * f * (3.0F - 2.0F * f);
        return Mth.lerp(f, hash(i * 7919 + seed * 104729), hash((i + 1) * 7919 + seed * 104729));
    }

    /** Twitch: mostly 0, occasionally a sharp spike for a few ticks. */
    protected static float twitch(float age, float step, int seed, float threshold) {
        float n = stepNoise(age, step, seed);
        return Math.abs(n) > threshold ? Math.signum(n) * (Math.abs(n) - threshold) / (1.0F - threshold) : 0.0F;
    }

    protected static float clamp01(float v) {
        return Mth.clamp(v, 0.0F, 1.0F);
    }
}
