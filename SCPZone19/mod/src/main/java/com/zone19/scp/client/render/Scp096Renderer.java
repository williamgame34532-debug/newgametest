package com.zone19.scp.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.zone19.scp.Zone19Mod;
import com.zone19.scp.entity.Scp096Entity;
import net.minecraft.client.model.geom.ModelLayers;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.HumanoidMobRenderer;
import net.minecraft.resources.ResourceLocation;

public class Scp096Renderer extends HumanoidMobRenderer<Scp096Entity, Scp096Model> {
    private static final ResourceLocation TEXTURE = Zone19Mod.id("textures/entity/scp096.png");

    public Scp096Renderer(EntityRendererProvider.Context ctx) {
        super(ctx, new Scp096Model(ctx.bakeLayer(ModelLayers.ZOMBIE)), 0.5F);
    }

    @Override
    public ResourceLocation getTextureLocation(Scp096Entity entity) {
        return TEXTURE;
    }

    @Override
    protected void scale(Scp096Entity entity, PoseStack pose, float partialTick) {
        pose.scale(0.82F, 1.3F, 0.82F);
    }
}
