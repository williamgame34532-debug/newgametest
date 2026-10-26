package com.williamgame.apiprobe.client;

import com.williamgame.apiprobe.ApiProbe;
import com.williamgame.apiprobe.ProbeMonster;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import net.minecraft.client.model.EntityModel;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.*;
import net.minecraft.util.Mth;

public class ProbeMonsterModel extends EntityModel<ProbeMonster> {
    public static final ModelLayerLocation LAYER = new ModelLayerLocation(ApiProbe.id("probe_monster"), "main");
    private final ModelPart root;
    private final ModelPart head;
    private final ModelPart leftArm;

    public ProbeMonsterModel(ModelPart root) {
        this.root = root;
        this.head = root.getChild("head");
        this.leftArm = root.getChild("left_arm");
    }

    public static LayerDefinition createLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition parts = mesh.getRoot();
        parts.addOrReplaceChild("head", CubeListBuilder.create().texOffs(0, 0).addBox(-4, -8, -4, 8, 8, 8, new CubeDeformation(0.25F)),
                PartPose.offset(0, 0, 0));
        parts.addOrReplaceChild("left_arm", CubeListBuilder.create().texOffs(32, 0).addBox(-1, 0, -1, 2, 24, 2),
                PartPose.offsetAndRotation(5, 2, 0, 0, 0, -0.1F));
        return LayerDefinition.create(mesh, 64, 64);
    }

    @Override
    public void setupAnim(ProbeMonster entity, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
        head.yRot = netHeadYaw * Mth.DEG_TO_RAD;
        head.xRot = headPitch * Mth.DEG_TO_RAD;
        leftArm.xRot = Mth.cos(limbSwing * 0.6662F) * 1.4F * limbSwingAmount;
    }

    @Override
    public void renderToBuffer(PoseStack poseStack, VertexConsumer buffer, int packedLight, int packedOverlay, int color) {
        root.render(poseStack, buffer, packedLight, packedOverlay, color);
    }
}
