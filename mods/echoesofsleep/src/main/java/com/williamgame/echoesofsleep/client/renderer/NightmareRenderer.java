package com.williamgame.echoesofsleep.client.renderer;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import net.minecraft.client.model.EntityModel;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.MobRenderer;
import net.minecraft.client.renderer.entity.layers.EyesLayer;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.entity.Mob;

/** Renders a nightmare with its texture plus an emissive (full-bright) eyes layer. */
public class NightmareRenderer<T extends Mob, M extends EntityModel<T>> extends MobRenderer<T, M> {
    private final ResourceLocation texture;

    public NightmareRenderer(EntityRendererProvider.Context ctx, M model, float shadow, String name) {
        super(ctx, model, shadow);
        this.texture = EchoesOfSleep.id("textures/entity/" + name + ".png");
        final RenderType eyes = RenderType.eyes(EchoesOfSleep.id("textures/entity/" + name + "_eyes.png"));
        addLayer(new EyesLayer<T, M>(this) {
            @Override
            public RenderType renderType() {
                return eyes;
            }
        });
    }

    @Override
    public ResourceLocation getTextureLocation(T entity) {
        return texture;
    }
}
