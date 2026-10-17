package com.zone19.scp.client.render;

import com.zone19.scp.Zone19Mod;
import net.minecraft.client.model.HierarchicalModel;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.CubeListBuilder;
import net.minecraft.client.model.geom.builders.LayerDefinition;
import net.minecraft.client.model.geom.builders.MeshDefinition;
import net.minecraft.client.model.geom.builders.PartDefinition;
import net.minecraft.world.entity.Entity;

/** Rebar-and-concrete statue. It never animates: it only ever moves when nobody is watching. */
public class Scp173Model<T extends Entity> extends HierarchicalModel<T> {
    public static final ModelLayerLocation LAYER = new ModelLayerLocation(Zone19Mod.id("scp173"), "main");
    private final ModelPart root;

    public Scp173Model(ModelPart root) {
        this.root = root;
    }

    public static LayerDefinition createBodyLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition root = mesh.getRoot();
        PartDefinition body = root.addOrReplaceChild("body", CubeListBuilder.create()
                .texOffs(0, 16).addBox(-4.0F, -12.0F, -3.0F, 8, 12, 6), PartPose.offset(0.0F, 16.0F, 0.0F));
        body.addOrReplaceChild("head", CubeListBuilder.create()
                .texOffs(0, 0).addBox(-4.0F, -8.0F, -4.0F, 8, 8, 8)
                .texOffs(48, 0).addBox(-1.0F, -4.0F, -5.5F, 2, 3, 2), PartPose.offsetAndRotation(0.0F, -12.0F, 0.0F, 0.08F, 0.0F, 0.0F));
        body.addOrReplaceChild("right_arm", CubeListBuilder.create()
                .texOffs(32, 16).addBox(-1.5F, 0.0F, -1.5F, 3, 10, 3), PartPose.offsetAndRotation(-5.5F, -11.0F, 0.0F, 0.0F, 0.0F, 0.12F));
        body.addOrReplaceChild("left_arm", CubeListBuilder.create()
                .texOffs(32, 16).mirror().addBox(-1.5F, 0.0F, -1.5F, 3, 10, 3), PartPose.offsetAndRotation(5.5F, -11.0F, 0.0F, 0.0F, 0.0F, -0.12F));
        root.addOrReplaceChild("right_leg", CubeListBuilder.create()
                .texOffs(32, 32).addBox(-1.5F, 0.0F, -1.5F, 3, 8, 3), PartPose.offset(-2.0F, 16.0F, 0.0F));
        root.addOrReplaceChild("left_leg", CubeListBuilder.create()
                .texOffs(32, 32).mirror().addBox(-1.5F, 0.0F, -1.5F, 3, 8, 3), PartPose.offset(2.0F, 16.0F, 0.0F));
        return LayerDefinition.create(mesh, 64, 64);
    }

    @Override
    public ModelPart root() {
        return root;
    }

    @Override
    public void setupAnim(T entity, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
    }
}
