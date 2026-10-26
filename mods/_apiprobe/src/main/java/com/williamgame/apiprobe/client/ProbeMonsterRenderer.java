package com.williamgame.apiprobe.client;

import com.williamgame.apiprobe.ApiProbe;
import com.williamgame.apiprobe.ProbeMonster;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.MobRenderer;
import net.minecraft.client.renderer.entity.layers.EyesLayer;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.resources.ResourceLocation;

public class ProbeMonsterRenderer extends MobRenderer<ProbeMonster, ProbeMonsterModel> {
    private static final ResourceLocation TEXTURE = ApiProbe.id("textures/entity/probe_monster.png");
    private static final RenderType EYES = RenderType.eyes(ApiProbe.id("textures/entity/probe_monster_eyes.png"));

    public ProbeMonsterRenderer(EntityRendererProvider.Context ctx) {
        super(ctx, new ProbeMonsterModel(ctx.bakeLayer(ProbeMonsterModel.LAYER)), 0.5F);
        addLayer(new EyesLayer<>(this) {
            @Override
            public RenderType renderType() {
                return EYES;
            }
        });
    }

    @Override
    public ResourceLocation getTextureLocation(ProbeMonster entity) {
        return TEXTURE;
    }
}
