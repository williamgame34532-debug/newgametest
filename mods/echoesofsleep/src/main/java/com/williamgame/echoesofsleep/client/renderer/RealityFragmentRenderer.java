package com.williamgame.echoesofsleep.client.renderer;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import com.williamgame.echoesofsleep.entity.RealityFragment;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.client.renderer.texture.TextureAtlas;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.state.BlockState;

/** A torn-out block hanging in the air, slowly tumbling, sometimes stuttering like a skipped frame. */
public class RealityFragmentRenderer extends EntityRenderer<RealityFragment> {
    private final BlockRenderDispatcher blocks;

    public RealityFragmentRenderer(EntityRendererProvider.Context ctx) {
        super(ctx);
        this.blocks = ctx.getBlockRenderDispatcher();
        this.shadowRadius = 0.4F;
    }

    @Override
    public void render(RealityFragment entity, float yaw, float partialTicks, PoseStack poseStack, MultiBufferSource buffer, int light) {
        BlockState state = entity.getBlockState();
        if (state.getRenderShape() != RenderShape.MODEL) return;
        float age = entity.tickCount + partialTicks;
        // stop-motion stutter: time advances in uneven steps
        float stepped = (entity.tickCount % 17 < 3) ? Mth.floor(age / 4.0F) * 4.0F : age;
        float spin = Math.min(1.0F, age / RealityFragment.RISE) * (1.0F - Math.max(0.0F, (age - RealityFragment.HOVER_END) / (RealityFragment.FALL_END - RealityFragment.HOVER_END)));
        poseStack.pushPose();
        poseStack.translate(0.0F, 0.5F, 0.0F);
        poseStack.mulPose(Axis.YP.rotationDegrees(stepped * 3.0F * spin));
        poseStack.mulPose(Axis.XP.rotationDegrees(Mth.sin(stepped * 0.07F) * 25.0F * spin));
        poseStack.mulPose(Axis.ZP.rotationDegrees(Mth.cos(stepped * 0.05F) * 20.0F * spin));
        poseStack.translate(-0.5F, -0.5F, -0.5F);
        blocks.renderSingleBlock(state, poseStack, buffer, light, OverlayTexture.NO_OVERLAY);
        poseStack.popPose();
        super.render(entity, yaw, partialTicks, poseStack, buffer, light);
    }

    @Override
    @SuppressWarnings("deprecation")
    public ResourceLocation getTextureLocation(RealityFragment entity) {
        return TextureAtlas.LOCATION_BLOCKS;
    }
}
