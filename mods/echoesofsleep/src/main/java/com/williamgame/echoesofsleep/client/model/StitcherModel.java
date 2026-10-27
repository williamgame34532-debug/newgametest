package com.williamgame.echoesofsleep.client.model;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.entity.Stitcher;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.*;
import net.minecraft.util.Mth;

/**
 * Stitcher: a hunched patchwork of a bloated zombie leg, a skeleton leg, a second sewn-on skull,
 * a long dragging arm with three-jointed fingers and two spider legs stitched to the left shoulder.
 * Animated in jerky stop-motion steps with constant twitching.
 * Geometry: UVs packed by tools/ (see generate_textures.py, which reads the boxes below to paint the texture).
 */
public class StitcherModel extends NightmareModel<Stitcher> {
    public static final ModelLayerLocation LAYER = new ModelLayerLocation(EchoesOfSleep.id("stitcher"), "main");

    private final ModelPart pelvis;
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
    private final ModelPart secondHead;
    private final ModelPart secondJaw;
    private final ModelPart rightArm;
    private final ModelPart rightForearm;
    private final ModelPart rightHand;
    private final ModelPart finger0;
    private final ModelPart finger0Tip;
    private final ModelPart finger1;
    private final ModelPart finger1Tip;
    private final ModelPart finger2;
    private final ModelPart finger2Tip;
    private final ModelPart thumb;
    private final ModelPart thumbTip;
    private final ModelPart spider0A;
    private final ModelPart spider0B;
    private final ModelPart spider0C;
    private final ModelPart spider1A;
    private final ModelPart spider1B;
    private final ModelPart spider1C;

    public StitcherModel(ModelPart root) {
        super(root);
        this.pelvis = root.getChild("pelvis");
        this.rightThigh = root.getChild("right_thigh");
        this.rightShin = root.getChild("right_thigh").getChild("right_shin");
        this.rightFoot = root.getChild("right_thigh").getChild("right_shin").getChild("right_foot");
        this.leftThigh = root.getChild("left_thigh");
        this.leftShin = root.getChild("left_thigh").getChild("left_shin");
        this.leftFoot = root.getChild("left_thigh").getChild("left_shin").getChild("left_foot");
        this.torso = root.getChild("pelvis").getChild("torso");
        this.ribs = root.getChild("pelvis").getChild("torso").getChild("ribs");
        this.spine = root.getChild("pelvis").getChild("torso").getChild("spine");
        this.shoulders = root.getChild("pelvis").getChild("torso").getChild("shoulders");
        this.neck = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("neck");
        this.head = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("neck").getChild("head");
        this.jaw = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("neck").getChild("head").getChild("jaw");
        this.secondHead = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("second_head");
        this.secondJaw = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("second_head").getChild("second_jaw");
        this.rightArm = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("right_arm");
        this.rightForearm = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm");
        this.rightHand = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand");
        this.finger0 = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("finger_0");
        this.finger0Tip = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("finger_0").getChild("finger_0_tip");
        this.finger1 = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("finger_1");
        this.finger1Tip = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("finger_1").getChild("finger_1_tip");
        this.finger2 = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("finger_2");
        this.finger2Tip = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("finger_2").getChild("finger_2_tip");
        this.thumb = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("thumb");
        this.thumbTip = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("thumb").getChild("thumb_tip");
        this.spider0A = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("spider_0_a");
        this.spider0B = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("spider_0_a").getChild("spider_0_b");
        this.spider0C = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("spider_0_a").getChild("spider_0_b").getChild("spider_0_c");
        this.spider1A = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("spider_1_a");
        this.spider1B = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("spider_1_a").getChild("spider_1_b");
        this.spider1C = root.getChild("pelvis").getChild("torso").getChild("shoulders").getChild("spider_1_a").getChild("spider_1_b").getChild("spider_1_c");
    }

    @SuppressWarnings("unused")
    public static LayerDefinition createLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition root = mesh.getRoot();
        PartDefinition pelvis = root.addOrReplaceChild("pelvis", CubeListBuilder.create()
                .texOffs(36, 31).addBox(-5.0F, -2.0F, -3.0F, 10.0F, 5.0F, 6.0F), PartPose.offset(0.0F, 4.0F, 0.0F));
        PartDefinition rightThigh = root.addOrReplaceChild("right_thigh", CubeListBuilder.create()
                .texOffs(108, 16).addBox(-2.0F, 0.0F, -2.0F, 4.0F, 9.0F, 4.0F), PartPose.offsetAndRotation(-3.0F, 6.0F, 0.0F, -0.35F, 0.0F, 0.05F));
        PartDefinition rightShin = rightThigh.addOrReplaceChild("right_shin", CubeListBuilder.create()
                .texOffs(24, 21).addBox(-1.5F, 0.0F, -1.5F, 3.0F, 9.0F, 3.0F), PartPose.offsetAndRotation(0.0F, 8.5F, 0.0F, 0.9F, 0.0F, 0.0F));
        PartDefinition rightFoot = rightShin.addOrReplaceChild("right_foot", CubeListBuilder.create()
                .texOffs(68, 40).addBox(-2.0F, 0.0F, -4.0F, 4.0F, 2.0F, 5.0F), PartPose.offsetAndRotation(0.0F, 8.5F, 0.0F, -0.55F, 0.0F, 0.0F));
        PartDefinition leftThigh = root.addOrReplaceChild("left_thigh", CubeListBuilder.create()
                .texOffs(84, 17).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 9.0F, 2.0F), PartPose.offsetAndRotation(3.0F, 6.0F, 0.0F, -0.35F, 0.0F, -0.05F));
        PartDefinition leftShin = leftThigh.addOrReplaceChild("left_shin", CubeListBuilder.create()
                .texOffs(84, 28).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 9.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 8.5F, 0.0F, 0.9F, 0.0F, 0.0F));
        PartDefinition leftFoot = leftShin.addOrReplaceChild("left_foot", CubeListBuilder.create()
                .texOffs(22, 33).addBox(-1.5F, 0.0F, -3.5F, 3.0F, 2.0F, 4.0F), PartPose.offsetAndRotation(0.0F, 8.5F, 0.0F, -0.55F, 0.0F, 0.0F));
        PartDefinition torso = pelvis.addOrReplaceChild("torso", CubeListBuilder.create()
                .texOffs(0, 0).addBox(-6.0F, -13.0F, -4.0F, 12.0F, 13.0F, 8.0F), PartPose.offsetAndRotation(0.0F, -1.5F, 0.0F, 0.35F, 0.0F, 0.0F));
        PartDefinition ribs = torso.addOrReplaceChild("ribs", CubeListBuilder.create()
                .texOffs(108, 29).addBox(-6.0F, -5.0F, -1.0F, 5.0F, 1.0F, 1.0F)
                .texOffs(102, 41).addBox(-6.0F, -3.0F, -1.0F, 5.0F, 1.0F, 1.0F)
                .texOffs(30, 42).addBox(-6.0F, -1.0F, -1.0F, 5.0F, 1.0F, 1.0F)
                .texOffs(42, 42).addBox(-6.0F, 1.0F, -1.0F, 4.0F, 1.0F, 1.0F), PartPose.offset(0.0F, -6.0F, -4.0F));
        PartDefinition spine = torso.addOrReplaceChild("spine", CubeListBuilder.create()
                .texOffs(22, 39).addBox(-1.0F, -12.0F, -0.5F, 2.0F, 2.0F, 2.0F)
                .texOffs(120, 39).addBox(-1.0F, -9.0F, -0.5F, 2.0F, 2.0F, 2.0F)
                .texOffs(86, 41).addBox(-1.0F, -6.0F, -0.5F, 2.0F, 2.0F, 2.0F)
                .texOffs(94, 41).addBox(-1.0F, -3.0F, -0.5F, 2.0F, 2.0F, 2.0F), PartPose.offset(0.0F, 0.0F, 4.0F));
        PartDefinition shoulders = torso.addOrReplaceChild("shoulders", CubeListBuilder.create()
                .texOffs(40, 18).addBox(-7.0F, -5.0F, -4.0F, 14.0F, 5.0F, 8.0F), PartPose.offsetAndRotation(0.0F, -12.0F, 0.0F, 0.25F, 0.0F, 0.0F));
        PartDefinition neck = shoulders.addOrReplaceChild("neck", CubeListBuilder.create()
                .texOffs(68, 31).addBox(-2.0F, -4.0F, -2.0F, 4.0F, 5.0F, 4.0F), PartPose.offsetAndRotation(2.0F, -4.0F, -1.5F, 0.45F, 0.0F, 0.0F));
        PartDefinition head = neck.addOrReplaceChild("head", CubeListBuilder.create()
                .texOffs(92, 0).addBox(-4.0F, -8.0F, -4.5F, 8.0F, 8.0F, 8.0F), PartPose.offsetAndRotation(0.0F, -4.0F, 0.0F, -0.55F, 0.0F, 0.35F));
        PartDefinition jaw = head.addOrReplaceChild("jaw", CubeListBuilder.create()
                .texOffs(92, 32).addBox(-3.5F, 0.0F, -7.5F, 7.0F, 2.0F, 7.0F), PartPose.offsetAndRotation(0.0F, -1.0F, 3.0F, 0.4F, 0.0F, 0.0F));
        PartDefinition secondHead = shoulders.addOrReplaceChild("second_head", CubeListBuilder.create()
                .texOffs(0, 21).addBox(-3.0F, -6.0F, -3.0F, 6.0F, 6.0F, 6.0F), PartPose.offsetAndRotation(-5.0F, -4.0F, 0.0F, 0.2F, 0.0F, -0.6F));
        PartDefinition secondJaw = secondHead.addOrReplaceChild("second_jaw", CubeListBuilder.create()
                .texOffs(0, 41).addBox(-2.5F, 0.0F, -5.5F, 5.0F, 1.0F, 5.0F), PartPose.offsetAndRotation(0.0F, 0.0F, 2.5F, 0.6F, 0.0F, 0.0F));
        PartDefinition rightArm = shoulders.addOrReplaceChild("right_arm", CubeListBuilder.create()
                .texOffs(40, 0).addBox(-2.5F, -1.0F, -2.5F, 5.0F, 13.0F, 5.0F), PartPose.offsetAndRotation(-8.5F, -2.5F, 0.0F, -0.2F, 0.0F, 0.15F));
        PartDefinition rightForearm = rightArm.addOrReplaceChild("right_forearm", CubeListBuilder.create()
                .texOffs(76, 0).addBox(-2.0F, 0.0F, -2.0F, 4.0F, 13.0F, 4.0F), PartPose.offsetAndRotation(0.0F, 11.5F, 0.0F, -0.4F, 0.0F, 0.0F));
        PartDefinition rightHand = rightForearm.addOrReplaceChild("right_hand", CubeListBuilder.create()
                .texOffs(0, 33).addBox(-3.0F, 0.0F, -2.5F, 6.0F, 3.0F, 5.0F), PartPose.offset(0.0F, 12.5F, 0.0F));
        PartDefinition finger0 = rightHand.addOrReplaceChild("finger_0", CubeListBuilder.create()
                .texOffs(124, 16).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(-2.0F, 3.0F, -1.5F, -0.2F, 0.0F, 0.0F));
        PartDefinition finger0Tip = finger0.addOrReplaceChild("finger_0_tip", CubeListBuilder.create()
                .texOffs(124, 28).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 4.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 4.8F, 0.0F, -0.5F, 0.0F, 0.0F));
        PartDefinition finger1 = rightHand.addOrReplaceChild("finger_1", CubeListBuilder.create()
                .texOffs(36, 21).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 3.0F, -1.5F, -0.2F, 0.0F, 0.0F));
        PartDefinition finger1Tip = finger1.addOrReplaceChild("finger_1_tip", CubeListBuilder.create()
                .texOffs(120, 29).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 4.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 4.8F, 0.0F, -0.5F, 0.0F, 0.0F));
        PartDefinition finger2 = rightHand.addOrReplaceChild("finger_2", CubeListBuilder.create()
                .texOffs(124, 22).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(2.0F, 3.0F, -1.5F, -0.2F, 0.0F, 0.0F));
        PartDefinition finger2Tip = finger2.addOrReplaceChild("finger_2_tip", CubeListBuilder.create()
                .texOffs(124, 33).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 4.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 4.8F, 0.0F, -0.5F, 0.0F, 0.0F));
        PartDefinition thumb = rightHand.addOrReplaceChild("thumb", CubeListBuilder.create()
                .texOffs(120, 34).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 4.0F, 1.0F), PartPose.offsetAndRotation(3.0F, 1.5F, -1.0F, -0.3F, 0.0F, -0.6F));
        PartDefinition thumbTip = thumb.addOrReplaceChild("thumb_tip", CubeListBuilder.create()
                .texOffs(36, 27).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 3.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 3.8F, 0.0F, -0.4F, 0.0F, 0.0F));
        PartDefinition spider0A = shoulders.addOrReplaceChild("spider_0_a", CubeListBuilder.create()
                .texOffs(92, 16).addBox(-1.0F, -1.0F, -1.0F, 2.0F, 14.0F, 2.0F), PartPose.offsetAndRotation(7.5F, -2.0F, 0.0F, -0.35F, 0.0F, -0.95F));
        PartDefinition spider0B = spider0A.addOrReplaceChild("spider_0_b", CubeListBuilder.create()
                .texOffs(60, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 16.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 13.0F, 0.0F, 0.0F, 0.0F, 1.6F));
        PartDefinition spider0C = spider0B.addOrReplaceChild("spider_0_c", CubeListBuilder.create()
                .texOffs(124, 0).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 7.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 15.5F, 0.0F, 0.0F, 0.0F, 0.5F));
        PartDefinition spider1A = shoulders.addOrReplaceChild("spider_1_a", CubeListBuilder.create()
                .texOffs(100, 16).addBox(-1.0F, -1.0F, -1.0F, 2.0F, 14.0F, 2.0F), PartPose.offsetAndRotation(7.5F, 0.0F, 0.0F, 0.45F, 0.0F, -0.7F));
        PartDefinition spider1B = spider1A.addOrReplaceChild("spider_1_b", CubeListBuilder.create()
                .texOffs(68, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 16.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 13.0F, 0.0F, 0.0F, 0.0F, 1.6F));
        PartDefinition spider1C = spider1B.addOrReplaceChild("spider_1_c", CubeListBuilder.create()
                .texOffs(124, 8).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 7.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 15.5F, 0.0F, 0.0F, 0.0F, 0.5F));
        return LayerDefinition.create(mesh, 128, 128);
    }

    @Override
    public void setupAnim(Stitcher entity, float limbSwing, float limbSwingAmount, float age, float netHeadYaw, float headPitch) {
        resetAll();
        int seed = entity.getId();
        boolean moving = entity.isMovingBurst();
        boolean grabbing = entity.isGrabbing();
        float pi = Mth.PI;

        // stop-motion: the walk cycle advances in hard steps, like a badly animated puppet
        float walk = Mth.floor(limbSwing * 0.55F * 2.5F) / 2.5F;
        float amt = Math.min(1.0F, limbSwingAmount * 1.6F);

        // breathing through a stitched belly
        float breath = Mth.sin(age * 0.08F);
        torso.xScale = 1.0F + breath * 0.03F;
        torso.zScale = 1.0F + breath * 0.05F;
        ribs.zScale = 1.0F + Math.max(0.0F, breath) * 0.6F;

        // legs: one bloated, one bone; neither moves the way legs should
        rightThigh.xRot += Mth.cos(walk) * 0.7F * amt;
        rightShin.xRot += Math.max(0.0F, -Mth.sin(walk)) * 0.7F * amt;
        rightFoot.xRot -= Math.max(0.0F, Mth.sin(walk)) * 0.4F * amt;
        leftThigh.xRot += Mth.cos(walk + pi) * 0.8F * amt;
        leftShin.xRot += Math.max(0.0F, -Mth.sin(walk + pi)) * 0.9F * amt;
        leftFoot.xRot -= Math.max(0.0F, Mth.sin(walk + pi)) * 0.4F * amt;
        pelvis.y -= Math.abs(Mth.sin(walk)) * 1.5F * amt;
        pelvis.zRot += Mth.sin(walk) * 0.06F * amt;
        torso.zRot += Mth.sin(walk) * 0.14F * amt;
        torso.xRot += 0.12F * amt;

        // the main head follows you, on a broken neck that keeps snapping sideways
        head.yRot += netHeadYaw * Mth.DEG_TO_RAD * 0.7F;
        head.xRot += headPitch * Mth.DEG_TO_RAD * 0.5F;
        float snap = twitch(age, moving ? 3.0F : 7.0F, seed, 0.72F);
        head.zRot += snap * 0.55F;
        head.yRot += snap * 0.3F;
        neck.zRot += smooth(age * 0.04F, seed + 1) * 0.12F;
        jaw.xRot += 0.12F + Math.max(0.0F, Mth.sin(age * 0.11F + seed)) * 0.35F + Math.max(0.0F, twitch(age, 2.0F, seed + 3, 0.8F)) * 0.5F;

        // the second, smaller skull sewn onto the shoulder has a will of its own
        secondHead.zRot += smooth(age * 0.05F, seed + 11) * 0.35F;
        secondHead.xRot += stepNoise(age, 9.0F, seed + 5) * 0.15F;
        secondHead.yRot += smooth(age * 0.03F, seed + 12) * 0.5F;
        secondJaw.xRot += Math.max(0.0F, smooth(age * 0.15F, seed + 7)) * 0.8F;

        // the long arm drags and swings like dead weight
        rightArm.xRot += Mth.cos(walk + pi) * 0.45F * amt;
        rightForearm.xRot -= 0.2F * amt;

        // between bursts it does not rest: it twitches
        if (!moving) {
            rightForearm.xRot += stepNoise(age, 4.0F, seed + 21) * 0.25F;
            shoulders.yRot += stepNoise(age, 5.0F, seed + 41) * 0.09F;
            spider0B.zRot += stepNoise(age, 3.0F, seed + 31) * 0.4F;
            spider1B.zRot += stepNoise(age, 3.0F, seed + 32) * 0.4F;
            torso.xRot += twitch(age, 6.0F, seed + 42, 0.8F) * 0.2F;
        }

        // fingers flexing, one after another
        float flex = (smooth(age * 0.1F, seed + 51) + 1.0F) * 0.5F;
        finger0.xRot -= flex * 0.35F;
        finger0Tip.xRot -= flex * 0.6F;
        finger1.xRot -= (1.0F - flex) * 0.35F;
        finger1Tip.xRot -= (1.0F - flex) * 0.6F;
        finger2.xRot -= flex * 0.5F;
        finger2Tip.xRot -= flex * 0.5F;
        thumb.zRot += flex * 0.3F;

        // stitched-on spider legs never stop skittering
        spider0A.xRot += Mth.sin(age * 0.6F) * 0.25F;
        spider0B.zRot += Mth.cos(age * 0.6F) * 0.3F;
        spider0C.zRot += Mth.sin(age * 0.9F) * 0.4F;
        spider1A.xRot += Mth.sin(age * 0.6F + 2.1F) * 0.25F;
        spider1B.zRot += Mth.cos(age * 0.6F + 2.1F) * 0.3F;
        spider1C.zRot += Mth.sin(age * 0.9F + 2.1F) * 0.4F;

        // melee swing
        if (attackTime > 0.0F) {
            float a = Mth.sin(attackTime * pi);
            rightArm.xRot -= a * 1.7F;
            rightForearm.xRot -= a * 0.6F;
            shoulders.yRot += a * 0.45F;
            jaw.xRot += a * 0.5F;
        }

        // holding someone up in the air
        if (grabbing) {
            rightArm.xRot = -2.1F + stepNoise(age, 2.0F, seed) * 0.06F;
            rightArm.zRot = 0.25F;
            rightForearm.xRot = -0.45F;
            finger0.xRot = -1.2F;
            finger0Tip.xRot = -1.3F;
            finger1.xRot = -1.25F;
            finger1Tip.xRot = -1.3F;
            finger2.xRot = -1.2F;
            finger2Tip.xRot = -1.4F;
            thumb.zRot = 0.2F;
            spider0A.xRot = -1.3F + Mth.sin(age * 1.4F) * 0.2F;
            spider1A.xRot = -0.9F + Mth.cos(age * 1.4F) * 0.2F;
            head.zRot = 0.8F + stepNoise(age, 2.0F, seed + 2) * 0.1F;
            jaw.xRot = 0.95F;
            secondJaw.xRot = 1.0F;
            torso.xRot -= 0.15F;
        }

        // lulled to sleep: slumped like a dropped marionette
        if (entity.isStunned()) {
            torso.xRot += 0.55F;
            head.xRot += 0.7F;
            head.zRot += 0.4F;
            jaw.xRot = 0.6F;
            rightArm.xRot = 0.1F;
            spider0A.zRot = -0.3F;
            spider1A.zRot = -0.2F;
        }
    }
}
