package com.zone19.scp.client.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.zone19.scp.Zone19Mod;
import com.zone19.scp.entity.Scp173Entity;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.MobRenderer;
import net.minecraft.resources.ResourceLocation;

public class Scp173Renderer extends MobRenderer<Scp173Entity, Scp173Model<Scp173Entity>> {
    private static final ResourceLocation TEXTURE = Zone19Mod.id("textures/entity/scp173.png");

    public Scp173Renderer(EntityRendererProvider.Context ctx) {
        super(ctx, new Scp173Model<>(ctx.bakeLayer(Scp173Model.LAYER)), 0.6F);
    }

    @Override
    public ResourceLocation getTextureLocation(Scp173Entity entity) {
        return TEXTURE;
    }

    @Override
    protected void scale(Scp173Entity entity, PoseStack pose, float partialTick) {
        pose.scale(1.35F, 1.35F, 1.35F);
    }
}
