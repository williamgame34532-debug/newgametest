package com.williamgame.echoesofsleep.client.model;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.entity.Sleepless;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.*;
import net.minecraft.util.Mth;

/**
 * The Sleepless: 4 blocks of skin stretched over bone. Rib bars that rise when it breathes, a long neck,
 * an unhinging jaw and arms long enough to touch its ankles, each with four two-jointed fingers.
 * Its animation clock only runs while nobody is watching it.
 * Geometry: UVs packed by tools/ (see generate_textures.py, which reads the boxes below to paint the texture).
 */
public class SleeplessModel extends NightmareModel<Sleepless> {
    public static final ModelLayerLocation LAYER = new ModelLayerLocation(EchoesOfSleep.id("sleepless"), "main");

    private final ModelPart hips;
    private final ModelPart rightThigh;
    private final ModelPart rightShin;
    private final ModelPart rightFoot;
    private final ModelPart leftThigh;
    private final ModelPart leftShin;
    private final ModelPart leftFoot;
    private final ModelPart torso;
    private final ModelPart ribs;
    private final ModelPart spine;
    private final ModelPart shoulders;
    private final ModelPart neck;
    private final ModelPart head;
    private final ModelPart jaw;
    private final ModelPart rightArm;
    private final ModelPart rightForearm;
    private final ModelPart rightHand;
    private final ModelPart rightFinger0;
    private final ModelPart rightFinger0Tip;
    private final ModelPart rightFinger1;
    private final ModelPart rightFinger1Tip;
    private final ModelPart rightFinger2;
    private final ModelPart rightFinger2Tip;
    private final ModelPart rightFinger3;
    private final ModelPart rightFinger3Tip;
    private final ModelPart leftArm;
    private final ModelPart leftForearm;
    private final ModelPart leftHand;
    private final ModelPart leftFinger0;
    private final ModelPart leftFinger0Tip;
    private final ModelPart leftFinger1;
    private final ModelPart leftFinger1Tip;
    private final ModelPart leftFinger2;
    private final ModelPart leftFinger2Tip;
    private final ModelPart leftFinger3;
    private final ModelPart leftFinger3Tip;

    public SleeplessModel(ModelPart root) {
        super(root);
        this.hips = root.getChild("hips");
        this.rightThigh = root.getChild("right_thigh");
        this.rightShin = root.getChild("right_thigh").getChild("right_shin");
        this.rightFoot = root.getChild("right_thigh").getChild("right_shin").getChild("right_foot");
        this.leftThigh = root.getChild("left_thigh");
        this.leftShin = root.getChild("left_thigh").getChild("left_shin");
        this.leftFoot = root.getChild("left_thigh").getChild("left_shin").getChild("left_foot");
        this.torso = root.getChild("hips").getChild("torso");
        this.ribs = root.getChild("hips").getChild("torso").getChild("ribs");
        this.spine = root.getChild("hips").getChild("torso").getChild("spine");
        this.shoulders = root.getChild("hips").getChild("torso").getChild("shoulders");
        this.neck = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("neck");
        this.head = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("neck").getChild("head");
        this.jaw = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("neck").getChild("head").getChild("jaw");
        this.rightArm = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("right_arm");
        this.rightForearm = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm");
        this.rightHand = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand");
        this.rightFinger0 = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_0");
        this.rightFinger0Tip = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_0").getChild("right_finger_0_tip");
        this.rightFinger1 = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_1");
        this.rightFinger1Tip = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_1").getChild("right_finger_1_tip");
        this.rightFinger2 = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_2");
        this.rightFinger2Tip = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_2").getChild("right_finger_2_tip");
        this.rightFinger3 = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_3");
        this.rightFinger3Tip = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_3").getChild("right_finger_3_tip");
        this.leftArm = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("left_arm");
        this.leftForearm = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("left_arm").getChild("left_forearm");
        this.leftHand = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand");
        this.leftFinger0 = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_0");
        this.leftFinger0Tip = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_0").getChild("left_finger_0_tip");
        this.leftFinger1 = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_1");
        this.leftFinger1Tip = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_1").getChild("left_finger_1_tip");
        this.leftFinger2 = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_2");
        this.leftFinger2Tip = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_2").getChild("left_finger_2_tip");
        this.leftFinger3 = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_3");
        this.leftFinger3Tip = root.getChild("hips").getChild("torso").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_3").getChild("left_finger_3_tip");
    }

    @SuppressWarnings("unused")
    public static LayerDefinition createLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition root = mesh.getRoot();
        PartDefinition hips = root.addOrReplaceChild("hips", CubeListBuilder.create()
                .texOffs(32, 20).addBox(-3.0F, -2.0F, -1.5F, 6.0F, 3.0F, 3.0F), PartPose.offset(0.0F, -14.0F, 0.0F));
        PartDefinition rightThigh = root.addOrReplaceChild("right_thigh", CubeListBuilder.create()
                .texOffs(32, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 18.0F, 2.0F), PartPose.offsetAndRotation(-2.0F, -13.0F, 0.0F, -0.08F, 0.0F, 0.0F));
        PartDefinition rightShin = rightThigh.addOrReplaceChild("right_shin", CubeListBuilder.create()
                .texOffs(40, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 18.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 17.5F, 0.0F, 0.12F, 0.0F, 0.0F));
        PartDefinition rightFoot = rightShin.addOrReplaceChild("right_foot", CubeListBuilder.create()
                .texOffs(108, 8).addBox(-1.0F, 0.0F, -5.0F, 2.0F, 1.0F, 6.0F), PartPose.offsetAndRotation(0.0F, 17.5F, 0.0F, -0.04F, 0.0F, 0.0F));
        PartDefinition leftThigh = root.addOrReplaceChild("left_thigh", CubeListBuilder.create()
                .texOffs(48, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 18.0F, 2.0F), PartPose.offsetAndRotation(2.0F, -13.0F, 0.0F, -0.08F, 0.0F, 0.0F));
        PartDefinition leftShin = leftThigh.addOrReplaceChild("left_shin", CubeListBuilder.create()
                .texOffs(56, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 18.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 17.5F, 0.0F, 0.12F, 0.0F, 0.0F));
        PartDefinition leftFoot = leftShin.addOrReplaceChild("left_foot", CubeListBuilder.create()
                .texOffs(80, 14).addBox(-1.0F, 0.0F, -5.0F, 2.0F, 1.0F, 6.0F), PartPose.offsetAndRotation(0.0F, 17.5F, 0.0F, -0.04F, 0.0F, 0.0F));
        PartDefinition torso = hips.addOrReplaceChild("torso", CubeListBuilder.create()
                .texOffs(64, 0).addBox(-2.5F, -16.0F, -1.5F, 5.0F, 16.0F, 3.0F), PartPose.offsetAndRotation(0.0F, -1.0F, 0.0F, 0.18F, 0.0F, 0.0F));
        PartDefinition ribs = torso.addOrReplaceChild("ribs", CubeListBuilder.create()
                .texOffs(108, 22).addBox(-3.5F, 0.0F, -0.8F, 7.0F, 1.0F, 1.0F)
                .texOffs(90, 23).addBox(-3.5F, 2.0F, -0.8F, 7.0F, 1.0F, 1.0F)
                .texOffs(106, 24).addBox(-3.5F, 4.0F, -0.8F, 7.0F, 1.0F, 1.0F)
                .texOffs(50, 25).addBox(-3.5F, 6.0F, -0.8F, 7.0F, 1.0F, 1.0F)
                .texOffs(66, 25).addBox(-3.5F, 8.0F, -0.8F, 7.0F, 1.0F, 1.0F), PartPose.offset(0.0F, -12.0F, -1.5F));
        PartDefinition spine = torso.addOrReplaceChild("spine", CubeListBuilder.create()
                .texOffs(60, 20).addBox(-0.5F, -7.0F, -0.5F, 1.0F, 1.0F, 1.0F)
                .texOffs(26, 21).addBox(-0.5F, -5.0F, -0.5F, 1.0F, 1.0F, 1.0F)
                .texOffs(90, 21).addBox(-0.5F, -3.0F, -0.5F, 1.0F, 1.0F, 1.0F)
                .texOffs(94, 21).addBox(-0.5F, -1.0F, -0.5F, 1.0F, 1.0F, 1.0F)
                .texOffs(124, 21).addBox(-0.5F, 1.0F, -0.5F, 1.0F, 1.0F, 1.0F)
                .texOffs(60, 22).addBox(-0.5F, 3.0F, -0.5F, 1.0F, 1.0F, 1.0F)
                .texOffs(26, 23).addBox(-0.5F, 5.0F, -0.5F, 1.0F, 1.0F, 1.0F), PartPose.offset(0.0F, -8.0F, 1.5F));
        PartDefinition shoulders = torso.addOrReplaceChild("shoulders", CubeListBuilder.create()
                .texOffs(0, 22).addBox(-5.0F, -1.0F, -1.5F, 10.0F, 2.0F, 3.0F), PartPose.offsetAndRotation(0.0F, -15.5F, 0.0F, 0.2F, 0.0F, 0.0F));
        PartDefinition neck = shoulders.addOrReplaceChild("neck", CubeListBuilder.create()
                .texOffs(100, 0).addBox(-1.0F, -8.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(0.0F, -1.0F, -0.5F, 0.5F, 0.0F, 0.0F));
        PartDefinition head = neck.addOrReplaceChild("head", CubeListBuilder.create()
                .texOffs(80, 0).addBox(-2.5F, -9.0F, -3.0F, 5.0F, 9.0F, 5.0F), PartPose.offsetAndRotation(0.0F, -7.5F, 0.0F, -0.3F, 0.0F, 0.4F));
        PartDefinition jaw = head.addOrReplaceChild("jaw", CubeListBuilder.create()
                .texOffs(108, 0).addBox(-2.0F, 0.0F, -4.0F, 4.0F, 4.0F, 4.0F), PartPose.offsetAndRotation(0.0F, -0.5F, 1.5F, 0.35F, 0.0F, 0.0F));
        PartDefinition rightArm = shoulders.addOrReplaceChild("right_arm", CubeListBuilder.create()
                .texOffs(0, 0).addBox(-1.0F, -0.5F, -1.0F, 2.0F, 20.0F, 2.0F), PartPose.offsetAndRotation(-5.5F, 0.0F, 0.0F, -0.1F, 0.0F, 0.08F));
        PartDefinition rightForearm = rightArm.addOrReplaceChild("right_forearm", CubeListBuilder.create()
                .texOffs(16, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 19.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 19.5F, 0.0F, -0.15F, 0.0F, 0.0F));
        PartDefinition rightHand = rightForearm.addOrReplaceChild("right_hand", CubeListBuilder.create()
                .texOffs(50, 20).addBox(-1.5F, 0.0F, -1.0F, 3.0F, 2.0F, 2.0F), PartPose.offset(0.0F, 18.5F, 0.0F));
        PartDefinition rightFinger0 = rightHand.addOrReplaceChild("right_finger_0", CubeListBuilder.create()
                .texOffs(124, 0).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(-1.2F, 1.5F, -0.2F, 0.0F, 0.0F, -0.12F));
        PartDefinition rightFinger0Tip = rightFinger0.addOrReplaceChild("right_finger_0_tip", CubeListBuilder.create()
                .texOffs(116, 15).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 5.6F, 0.0F, -0.2F, 0.0F, 0.0F));
        PartDefinition rightFinger1 = rightHand.addOrReplaceChild("right_finger_1", CubeListBuilder.create()
                .texOffs(124, 7).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(-0.4F, 1.5F, 0.2F, 0.0F, 0.0F, -0.04F));
        PartDefinition rightFinger1Tip = rightFinger1.addOrReplaceChild("right_finger_1_tip", CubeListBuilder.create()
                .texOffs(120, 15).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 5.6F, 0.0F, -0.2F, 0.0F, 0.0F));
        PartDefinition rightFinger2 = rightHand.addOrReplaceChild("right_finger_2", CubeListBuilder.create()
                .texOffs(100, 10).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.4F, 1.5F, 0.2F, 0.0F, 0.0F, 0.04F));
        PartDefinition rightFinger2Tip = rightFinger2.addOrReplaceChild("right_finger_2_tip", CubeListBuilder.create()
                .texOffs(100, 17).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 5.6F, 0.0F, -0.2F, 0.0F, 0.0F));
        PartDefinition rightFinger3 = rightHand.addOrReplaceChild("right_finger_3", CubeListBuilder.create()
                .texOffs(104, 10).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(1.2F, 1.5F, -0.2F, 0.0F, 0.0F, 0.12F));
        PartDefinition rightFinger3Tip = rightFinger3.addOrReplaceChild("right_finger_3_tip", CubeListBuilder.create()
                .texOffs(104, 17).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 5.6F, 0.0F, -0.2F, 0.0F, 0.0F));
        PartDefinition leftArm = shoulders.addOrReplaceChild("left_arm", CubeListBuilder.create()
                .texOffs(8, 0).addBox(-1.0F, -0.5F, -1.0F, 2.0F, 20.0F, 2.0F), PartPose.offsetAndRotation(5.5F, 0.0F, 0.0F, -0.1F, 0.0F, -0.08F));
        PartDefinition leftForearm = leftArm.addOrReplaceChild("left_forearm", CubeListBuilder.create()
                .texOffs(24, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 19.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 19.5F, 0.0F, -0.15F, 0.0F, 0.0F));
        PartDefinition leftHand = leftForearm.addOrReplaceChild("left_hand", CubeListBuilder.create()
                .texOffs(80, 21).addBox(-1.5F, 0.0F, -1.0F, 3.0F, 2.0F, 2.0F), PartPose.offset(0.0F, 18.5F, 0.0F));
        PartDefinition leftFinger0 = leftHand.addOrReplaceChild("left_finger_0", CubeListBuilder.create()
                .texOffs(96, 14).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(-1.2F, 1.5F, -0.2F, 0.0F, 0.0F, -0.12F));
        PartDefinition leftFinger0Tip = leftFinger0.addOrReplaceChild("left_finger_0_tip", CubeListBuilder.create()
                .texOffs(64, 19).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 5.6F, 0.0F, -0.2F, 0.0F, 0.0F));
        PartDefinition leftFinger1 = leftHand.addOrReplaceChild("left_finger_1", CubeListBuilder.create()
                .texOffs(124, 14).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(-0.4F, 1.5F, 0.2F, 0.0F, 0.0F, -0.04F));
        PartDefinition leftFinger1Tip = leftFinger1.addOrReplaceChild("left_finger_1_tip", CubeListBuilder.create()
                .texOffs(68, 19).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 5.6F, 0.0F, -0.2F, 0.0F, 0.0F));
        PartDefinition leftFinger2 = leftHand.addOrReplaceChild("left_finger_2", CubeListBuilder.create()
                .texOffs(108, 15).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.4F, 1.5F, 0.2F, 0.0F, 0.0F, 0.04F));
        PartDefinition leftFinger2Tip = leftFinger2.addOrReplaceChild("left_finger_2_tip", CubeListBuilder.create()
                .texOffs(72, 19).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 5.6F, 0.0F, -0.2F, 0.0F, 0.0F));
        PartDefinition leftFinger3 = leftHand.addOrReplaceChild("left_finger_3", CubeListBuilder.create()
                .texOffs(112, 15).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(1.2F, 1.5F, -0.2F, 0.0F, 0.0F, 0.12F));
        PartDefinition leftFinger3Tip = leftFinger3.addOrReplaceChild("left_finger_3_tip", CubeListBuilder.create()
                .texOffs(76, 19).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 5.6F, 0.0F, -0.2F, 0.0F, 0.0F));
        return LayerDefinition.create(mesh, 128, 128);
    }

    @Override
    public void setupAnim(Sleepless entity, float limbSwing, float limbSwingAmount, float ageInTicks, float netHeadYaw, float headPitch) {
        resetAll();
        int seed = entity.getId();
        boolean watched = entity.isWatched();
        // its own clock: while anyone looks at it, time stops for it completely
        float partial = ageInTicks - entity.tickCount;
        float t = entity.clientAnimTicks + (watched ? 0.0F : partial);
        boolean reaching = entity.isReaching();

        // slow, deep breathing that lifts the ribs out of its chest
        float breath = Mth.sin(t * 0.05F);
        ribs.zScale = 1.0F + breath * 0.35F;
        ribs.xScale = 1.0F + breath * 0.06F;
        torso.xRot += breath * 0.02F;
        shoulders.y += breath * 0.3F;

        // the head hangs at a wrong angle and drifts... then snaps
        head.zRot += smooth(t * 0.02F, seed) * 0.35F + twitch(t, 9.0F, seed + 1, 0.75F) * 0.7F;
        head.yRot += netHeadYaw * Mth.DEG_TO_RAD * 0.6F + twitch(t, 13.0F, seed + 7, 0.85F) * 0.5F;
        head.xRot += headPitch * Mth.DEG_TO_RAD * 0.4F;
        neck.xRot += smooth(t * 0.03F, seed + 3) * 0.12F;
        neck.zRot += smooth(t * 0.025F, seed + 4) * 0.08F;
        jaw.xRot += 0.1F + Math.max(0.0F, smooth(t * 0.07F, seed + 2)) * 0.35F;

        // impossibly long arms, swaying like hanging ropes
        rightArm.zRot += Mth.sin(t * 0.04F) * 0.04F;
        leftArm.zRot -= Mth.sin(t * 0.04F + 1.0F) * 0.04F;
        rightArm.xRot += smooth(t * 0.03F, seed + 5) * 0.08F;
        leftArm.xRot += smooth(t * 0.03F, seed + 6) * 0.08F;
        rightForearm.xRot += smooth(t * 0.05F, seed + 8) * 0.06F;
        leftForearm.xRot += smooth(t * 0.05F, seed + 9) * 0.06F;

        // fingers curl one after another, as if counting down
        ModelPart[] fingers = {rightFinger0, rightFinger1, rightFinger2, rightFinger3, leftFinger0, leftFinger1, leftFinger2, leftFinger3};
        ModelPart[] tips = {rightFinger0Tip, rightFinger1Tip, rightFinger2Tip, rightFinger3Tip, leftFinger0Tip, leftFinger1Tip, leftFinger2Tip, leftFinger3Tip};
        for (int i = 0; i < fingers.length; i++) {
            float c = 0.5F + 0.5F * Mth.sin(t * 0.08F - (i % 4) * 0.7F + (i / 4) * 1.9F);
            fingers[i].xRot -= c * 0.5F;
            tips[i].xRot -= c * 0.7F;
        }

        // when it does walk: long, stiff strides with knees that bend too far
        float w = limbSwing * 0.35F;
        float amt = Math.min(1.0F, limbSwingAmount * 1.4F);
        rightThigh.xRot += Mth.cos(w) * 0.5F * amt;
        leftThigh.xRot += Mth.cos(w + Mth.PI) * 0.5F * amt;
        rightShin.xRot += Math.max(0.0F, -Mth.sin(w)) * 0.8F * amt;
        leftShin.xRot += Math.max(0.0F, -Mth.sin(w + Mth.PI)) * 0.8F * amt;
        hips.y -= Math.abs(Mth.cos(w)) * 1.0F * amt;

        // the strike: both arms thrown forward, fingers splayed, jaw unhinged
        if (reaching) {
            rightArm.xRot = -1.45F;
            leftArm.xRot = -1.3F;
            rightArm.zRot = 0.15F;
            leftArm.zRot = -0.15F;
            rightForearm.xRot = -0.1F;
            leftForearm.xRot = -0.15F;
            for (int i = 0; i < fingers.length; i++) {
                fingers[i].xRot = 0.2F;
                fingers[i].zRot = ((i % 4) - 1.5F) * 0.35F;
                tips[i].xRot = -0.3F;
            }
            jaw.xRot = 1.1F;
            head.xRot -= 0.3F;
            torso.xRot += 0.35F;
        }

        if (entity.isStunned()) {
            head.xRot += 0.8F;
            neck.xRot += 0.3F;
            jaw.xRot = 0.5F;
            torso.xRot += 0.25F;
        }
    }
}
