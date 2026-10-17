package com.zone19.scp.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.zone19.scp.Zone19Mod;
import com.zone19.scp.entity.Scp106Entity;
import net.minecraft.client.model.HumanoidModel;
import net.minecraft.client.model.geom.ModelLayers;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.HumanoidMobRenderer;
import net.minecraft.resources.ResourceLocation;

public class Scp106Renderer extends HumanoidMobRenderer<Scp106Entity, HumanoidModel<Scp106Entity>> {
    private static final ResourceLocation TEXTURE = Zone19Mod.id("textures/entity/scp106.png");

    public Scp106Renderer(EntityRendererProvider.Context ctx) {
        super(ctx, new HumanoidModel<>(ctx.bakeLayer(ModelLayers.ZOMBIE)), 0.5F);
    }

    @Override
    public ResourceLocation getTextureLocation(Scp106Entity entity) {
        return TEXTURE;
    }

    @Override
    protected void scale(Scp106Entity entity, PoseStack pose, float partialTick) {
        pose.scale(1.0F, 1.04F, 1.0F);
    }
}
