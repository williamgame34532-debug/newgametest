package com.zone19.scp.client.render;

import com.zone19.scp.Zone19Mod;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.ZombieRenderer;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.entity.monster.Zombie;

public class Scp0492Renderer extends ZombieRenderer {
    private static final ResourceLocation TEXTURE = Zone19Mod.id("textures/entity/scp049_2.png");

    public Scp0492Renderer(EntityRendererProvider.Context ctx) {
        super(ctx);
    }

    @Override
    public ResourceLocation getTextureLocation(Zombie entity) {
        return TEXTURE;
    }
}
