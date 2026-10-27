package com.williamgame.echoesofsleep.client.model;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.entity.HollowVillager;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.*;
import net.minecraft.util.Mth;

/**
 * Hollow Villager: a villager with the eyes scraped out and a jaw that never closes; limps on one leg,
 * stops and stares back when watched, its mouth hanging open.
 * Geometry: UVs packed by tools/ (see generate_textures.py, which reads the boxes below to paint the texture).
 */
public class HollowVillagerModel extends NightmareModel<HollowVillager> {
    public static final ModelLayerLocation LAYER = new ModelLayerLocation(EchoesOfSleep.id("hollow_villager"), "main");

    private final ModelPart head;
    private final ModelPart nose;
    private final ModelPart jaw;
    private final ModelPart neck;
    private final ModelPart body;
    private final ModelPart robe;
    private final ModelPart rightArm;
    private final ModelPart rightHand;
    private final ModelPart rightLeg;
    private final ModelPart leftArm;
    private final ModelPart leftHand;
    private final ModelPart leftLeg;

    public HollowVillagerModel(ModelPart root) {
        super(root);
        this.head = root.getChild("head");
        this.nose = root.getChild("head").getChild("nose");
        this.jaw = root.getChild("head").getChild("jaw");
        this.neck = root.getChild("neck");
        this.body = root.getChild("body");
        this.robe = root.getChild("body").getChild("robe");
        this.rightArm = root.getChild("right_arm");
        this.rightHand = root.getChild("right_arm").getChild("right_hand");
        this.rightLeg = root.getChild("right_leg");
        this.leftArm = root.getChild("left_arm");
        this.leftHand = root.getChild("left_arm").getChild("left_hand");
        this.leftLeg = root.getChild("left_leg");
    }

    @SuppressWarnings("unused")
    public static LayerDefinition createLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition root = mesh.getRoot();
        PartDefinition head = root.addOrReplaceChild("head", CubeListBuilder.create()
                .texOffs(28, 0).addBox(-4.0F, -10.0F, -4.0F, 8.0F, 8.0F, 8.0F), PartPose.offset(0.0F, 0.0F, 0.0F));
        PartDefinition nose = head.addOrReplaceChild("nose", CubeListBuilder.create()
                .texOffs(56, 40).addBox(-1.0F, -1.0F, -2.0F, 2.0F, 4.0F, 2.0F), PartPose.offset(0.0F, -4.0F, -4.0F));
        PartDefinition jaw = head.addOrReplaceChild("jaw", CubeListBuilder.create()
                .texOffs(0, 47).addBox(-4.0F, 0.0F, -7.5F, 8.0F, 3.0F, 8.0F), PartPose.offsetAndRotation(0.0F, -2.0F, 3.5F, 0.55F, 0.0F, 0.0F));
        PartDefinition neck = root.addOrReplaceChild("neck", CubeListBuilder.create()
                .texOffs(8, 34).addBox(-2.0F, -2.5F, -2.0F, 4.0F, 3.0F, 4.0F), PartPose.offset(0.0F, 0.0F, 0.0F));
        PartDefinition body = root.addOrReplaceChild("body", CubeListBuilder.create()
                .texOffs(0, 0).addBox(-4.0F, 0.0F, -3.0F, 8.0F, 12.0F, 6.0F), PartPose.offset(0.0F, 0.0F, 0.0F));
        PartDefinition robe = body.addOrReplaceChild("robe", CubeListBuilder.create()
                .texOffs(24, 32).addBox(-4.5F, 0.0F, -3.5F, 9.0F, 8.0F, 7.0F), PartPose.offset(0.0F, 11.0F, 0.0F));
        PartDefinition rightArm = root.addOrReplaceChild("right_arm", CubeListBuilder.create()
                .texOffs(0, 18).addBox(-1.5F, -1.0F, -1.5F, 3.0F, 13.0F, 3.0F), PartPose.offsetAndRotation(-5.5F, 1.5F, 0.0F, -0.1F, 0.0F, 0.17F));
        PartDefinition rightHand = rightArm.addOrReplaceChild("right_hand", CubeListBuilder.create()
                .texOffs(56, 32).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 6.0F, 2.0F), PartPose.offset(0.0F, 11.5F, 0.0F));
        PartDefinition rightLeg = root.addOrReplaceChild("right_leg", CubeListBuilder.create()
                .texOffs(28, 16).addBox(-2.0F, 0.0F, -2.0F, 4.0F, 12.0F, 4.0F), PartPose.offset(-2.09F, 12.0F, 0.0F));
        PartDefinition leftArm = root.addOrReplaceChild("left_arm", CubeListBuilder.create()
                .texOffs(12, 18).addBox(-1.5F, -1.0F, -1.5F, 3.0F, 13.0F, 3.0F), PartPose.offsetAndRotation(5.5F, 1.5F, 0.0F, -0.1F, 0.0F, -0.17F));
        PartDefinition leftHand = leftArm.addOrReplaceChild("left_hand", CubeListBuilder.create()
                .texOffs(0, 34).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 6.0F, 2.0F), PartPose.offset(0.0F, 11.5F, 0.0F));
        PartDefinition leftLeg = root.addOrReplaceChild("left_leg", CubeListBuilder.create()
                .texOffs(44, 16).addBox(-2.0F, 0.0F, -2.0F, 4.0F, 12.0F, 4.0F), PartPose.offset(2.09F, 12.0F, 0.0F));
        return LayerDefinition.create(mesh, 64, 64);
    }

    @Override
    public void setupAnim(HollowVillager entity, float limbSwing, float limbSwingAmount, float age, float netHeadYaw, float headPitch) {
        resetAll();
        int seed = entity.getId();
        boolean staring = entity.isStaring();

        head.yRot += netHeadYaw * Mth.DEG_TO_RAD;
        head.xRot += headPitch * Mth.DEG_TO_RAD;

        // the mouth keeps forming words that never come out
        jaw.xRot += 0.15F + (Mth.sin(age * 0.35F + seed) * 0.5F + 0.5F) * 0.25F * (stepNoise(age, 6.0F, seed) > -0.2F ? 1.0F : 0.2F);

        // a limping walk: the right leg drags behind, stiff
        float w = limbSwing * 0.6662F;
        rightLeg.xRot += Mth.cos(w) * 0.6F * limbSwingAmount;
        leftLeg.xRot += Mth.cos(w + Mth.PI) * 1.2F * limbSwingAmount;
        body.zRot += Mth.sin(w) * 0.06F * limbSwingAmount;
        head.zRot += Mth.sin(w) * 0.08F * limbSwingAmount;

        // arms hang dead; the hands twitch
        rightArm.xRot += Mth.cos(w + Mth.PI) * 0.25F * limbSwingAmount + Mth.sin(age * 0.05F) * 0.03F;
        leftArm.xRot += Mth.cos(w) * 0.25F * limbSwingAmount - Mth.sin(age * 0.05F) * 0.03F;
        rightHand.xRot += twitch(age, 4.0F, seed + 1, 0.8F) * 0.4F;
        leftHand.xRot += twitch(age, 4.0F, seed + 2, 0.8F) * 0.4F;

        // staring: the empty face slowly turns sideways and the mouth hangs wide open
        if (staring) {
            float s = Mth.sin(age * 0.02F) * 0.5F + 0.5F;
            head.zRot += 0.35F + s * 0.35F + stepNoise(age, 3.0F, seed + 9) * 0.03F;
            jaw.xRot = 0.95F + stepNoise(age, 2.0F, seed + 5) * 0.05F;
            rightArm.xRot = -0.15F;
            leftArm.xRot = -0.15F;
        } else {
            head.zRot += smooth(age * 0.03F, seed + 4) * 0.15F;
        }

        if (attackTime > 0.0F) {
            float a = Mth.sin(attackTime * Mth.PI);
            rightArm.xRot -= a * 1.8F;
            leftArm.xRot -= a * 1.6F;
            jaw.xRot += a * 0.5F;
        }

        if (entity.isStunned()) {
            head.xRot += 0.6F;
            jaw.xRot = 0.7F;
        }
    }
}
