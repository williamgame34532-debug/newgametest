package com.williamgame.echoesofsleep.client.model;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.entity.MotherHand;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.*;
import net.minecraft.util.Mth;

/**
 * One of the Deep Mother's hands: a long pale forearm with bone spurs, a palm and four three-jointed fingers
 * plus a thumb. It punches out of the floor as a fist, opens, slams palm-first and clutches.
 * Geometry: UVs packed by tools/ (see generate_textures.py, which reads the boxes below to paint the texture).
 */
public class MotherHandModel extends NightmareModel<MotherHand> {
    public static final ModelLayerLocation LAYER = new ModelLayerLocation(EchoesOfSleep.id("mother_hand"), "main");

    private final ModelPart forearm;
    private final ModelPart spurs;
    private final ModelPart wrist;
    private final ModelPart palm;
    private final ModelPart finger0;
    private final ModelPart finger0Mid;
    private final ModelPart finger0Tip;
    private final ModelPart finger1;
    private final ModelPart finger1Mid;
    private final ModelPart finger1Tip;
    private final ModelPart finger2;
    private final ModelPart finger2Mid;
    private final ModelPart finger2Tip;
    private final ModelPart finger3;
    private final ModelPart finger3Mid;
    private final ModelPart finger3Tip;
    private final ModelPart thumb;
    private final ModelPart thumbTip;

    public MotherHandModel(ModelPart root) {
        super(root);
        this.forearm = root.getChild("forearm");
        this.spurs = root.getChild("forearm").getChild("spurs");
        this.wrist = root.getChild("forearm").getChild("wrist");
        this.palm = root.getChild("forearm").getChild("wrist").getChild("palm");
        this.finger0 = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_0");
        this.finger0Mid = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_0").getChild("finger_0_mid");
        this.finger0Tip = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_0").getChild("finger_0_mid").getChild("finger_0_tip");
        this.finger1 = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_1");
        this.finger1Mid = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_1").getChild("finger_1_mid");
        this.finger1Tip = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_1").getChild("finger_1_mid").getChild("finger_1_tip");
        this.finger2 = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_2");
        this.finger2Mid = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_2").getChild("finger_2_mid");
        this.finger2Tip = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_2").getChild("finger_2_mid").getChild("finger_2_tip");
        this.finger3 = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_3");
        this.finger3Mid = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_3").getChild("finger_3_mid");
        this.finger3Tip = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("finger_3").getChild("finger_3_mid").getChild("finger_3_tip");
        this.thumb = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("thumb");
        this.thumbTip = root.getChild("forearm").getChild("wrist").getChild("palm").getChild("thumb").getChild("thumb_tip");
    }

    @SuppressWarnings("unused")
    public static LayerDefinition createLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition root = mesh.getRoot();
        PartDefinition forearm = root.addOrReplaceChild("forearm", CubeListBuilder.create()
                .texOffs(0, 0).addBox(-4.0F, -24.0F, -4.0F, 8.0F, 24.0F, 8.0F), PartPose.offset(0.0F, 24.0F, 0.0F));
        PartDefinition spurs = forearm.addOrReplaceChild("spurs", CubeListBuilder.create()
                .texOffs(122, 0).addBox(-5.0F, -2.0F, -1.0F, 1.0F, 4.0F, 2.0F)
                .texOffs(44, 12).addBox(4.0F, -8.0F, -1.0F, 1.0F, 3.0F, 2.0F)
                .texOffs(50, 12).addBox(-1.0F, 4.0F, -5.0F, 2.0F, 3.0F, 1.0F), PartPose.offset(0.0F, -14.0F, 0.0F));
        PartDefinition wrist = forearm.addOrReplaceChild("wrist", CubeListBuilder.create()
                .texOffs(70, 0).addBox(-3.5F, -3.0F, -3.5F, 7.0F, 3.0F, 7.0F), PartPose.offset(0.0F, -23.5F, 0.0F));
        PartDefinition palm = wrist.addOrReplaceChild("palm", CubeListBuilder.create()
                .texOffs(32, 0).addBox(-5.5F, -4.0F, -4.0F, 11.0F, 4.0F, 8.0F), PartPose.offset(0.0F, -3.0F, 0.0F));
        PartDefinition finger0 = palm.addOrReplaceChild("finger_0", CubeListBuilder.create()
                .texOffs(98, 0).addBox(-1.0F, -8.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(-4.0F, -4.0F, -1.1F, 0.35F, 0.0F, -0.3F));
        PartDefinition finger0Mid = finger0.addOrReplaceChild("finger_0_mid", CubeListBuilder.create()
                .texOffs(78, 10).addBox(-1.0F, -6.0F, -1.0F, 2.0F, 6.0F, 2.0F), PartPose.offsetAndRotation(0.0F, -7.5F, 0.0F, 0.45F, 0.0F, 0.0F));
        PartDefinition finger0Tip = finger0Mid.addOrReplaceChild("finger_0_tip", CubeListBuilder.create()
                .texOffs(122, 6).addBox(-0.5F, -5.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -5.5F, 0.0F, 0.5F, 0.0F, 0.0F));
        PartDefinition finger1 = palm.addOrReplaceChild("finger_1", CubeListBuilder.create()
                .texOffs(106, 0).addBox(-1.0F, -8.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(-1.34F, -4.0F, -1.7F, 0.35F, 0.0F, -0.1F));
        PartDefinition finger1Mid = finger1.addOrReplaceChild("finger_1_mid", CubeListBuilder.create()
                .texOffs(86, 10).addBox(-1.0F, -6.0F, -1.0F, 2.0F, 6.0F, 2.0F), PartPose.offsetAndRotation(0.0F, -7.5F, 0.0F, 0.45F, 0.0F, 0.0F));
        PartDefinition finger1Tip = finger1Mid.addOrReplaceChild("finger_1_tip", CubeListBuilder.create()
                .texOffs(118, 10).addBox(-0.5F, -5.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -5.5F, 0.0F, 0.5F, 0.0F, 0.0F));
        PartDefinition finger2 = palm.addOrReplaceChild("finger_2", CubeListBuilder.create()
                .texOffs(114, 0).addBox(-1.0F, -8.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(1.32F, -4.0F, -1.7F, 0.35F, 0.0F, 0.1F));
        PartDefinition finger2Mid = finger2.addOrReplaceChild("finger_2_mid", CubeListBuilder.create()
                .texOffs(94, 10).addBox(-1.0F, -6.0F, -1.0F, 2.0F, 6.0F, 2.0F), PartPose.offsetAndRotation(0.0F, -7.5F, 0.0F, 0.45F, 0.0F, 0.0F));
        PartDefinition finger2Tip = finger2Mid.addOrReplaceChild("finger_2_tip", CubeListBuilder.create()
                .texOffs(32, 12).addBox(-0.5F, -5.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -5.5F, 0.0F, 0.5F, 0.0F, 0.0F));
        PartDefinition finger3 = palm.addOrReplaceChild("finger_3", CubeListBuilder.create()
                .texOffs(70, 10).addBox(-1.0F, -8.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(3.98F, -4.0F, -1.1F, 0.35F, 0.0F, 0.3F));
        PartDefinition finger3Mid = finger3.addOrReplaceChild("finger_3_mid", CubeListBuilder.create()
                .texOffs(102, 10).addBox(-1.0F, -6.0F, -1.0F, 2.0F, 6.0F, 2.0F), PartPose.offsetAndRotation(0.0F, -7.5F, 0.0F, 0.45F, 0.0F, 0.0F));
        PartDefinition finger3Tip = finger3Mid.addOrReplaceChild("finger_3_tip", CubeListBuilder.create()
                .texOffs(36, 12).addBox(-0.5F, -5.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -5.5F, 0.0F, 0.5F, 0.0F, 0.0F));
        PartDefinition thumb = palm.addOrReplaceChild("thumb", CubeListBuilder.create()
                .texOffs(110, 10).addBox(-1.0F, -6.0F, -1.0F, 2.0F, 6.0F, 2.0F), PartPose.offsetAndRotation(5.5F, -2.0F, -1.0F, 0.3F, 0.0F, 1.0F));
        PartDefinition thumbTip = thumb.addOrReplaceChild("thumb_tip", CubeListBuilder.create()
                .texOffs(40, 12).addBox(-0.5F, -5.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -5.5F, 0.0F, 0.4F, 0.0F, 0.0F));
        return LayerDefinition.create(mesh, 128, 128);
    }

    /** 0..1 how far the hand has risen out of the floor (used by the renderer too). */
    public static float emergeProgress(MotherHand hand, float partial) {
        float t = hand.tickCount + partial;
        if (hand.deathTime > 0) return clamp01(1.0F - (hand.deathTime + partial) / 12.0F);
        if (t < MotherHand.EMERGE) {
            float p = t / MotherHand.EMERGE;
            return 1.0F - (1.0F - p) * (1.0F - p) * (1.0F - p);
        }
        if (t > MotherHand.SINK_FROM) return clamp01(1.0F - (t - MotherHand.SINK_FROM) / (MotherHand.LIFETIME - MotherHand.SINK_FROM));
        return 1.0F;
    }

    @Override
    public void setupAnim(MotherHand entity, float limbSwing, float limbSwingAmount, float t, float netHeadYaw, float headPitch) {
        resetAll();
        int seed = entity.getId();
        ModelPart[] fingers = {finger0, finger1, finger2, finger3};
        ModelPart[] mids = {finger0Mid, finger1Mid, finger2Mid, finger3Mid};
        ModelPart[] tips = {finger0Tip, finger1Tip, finger2Tip, finger3Tip};

        // constant tremor, like a muscle that has been clenched for a century
        forearm.zRot += stepNoise(t, 2.0F, seed) * 0.025F;
        forearm.xRot += stepNoise(t, 2.0F, seed + 1) * 0.025F;

        float curl;
        if (t < MotherHand.EMERGE) {
            curl = 1.0F - t / MotherHand.EMERGE; // a fist punching up through the stone, opening
        } else {
            curl = 0.15F + 0.1F * Mth.sin(t * 0.3F + seed);
        }

        // slam: rear back, then crash forward palm-first
        float slamWind = clamp01((t - (MotherHand.SLAM_AT - 10)) / 10.0F);
        float slamHit = clamp01((t - MotherHand.SLAM_AT) / 2.0F);
        float slamRecover = clamp01((t - MotherHand.SLAM_AT - 4) / 14.0F);
        float slam = slamHit * (1.0F - slamRecover);
        forearm.xRot += slamWind * (1.0F - slamHit) * 0.45F - slam * 1.25F;
        wrist.xRot -= slam * 0.5F;
        if (slam > 0.0F) curl = -0.25F * slam; // fingers splayed back on impact

        // clutch: fingers close hard around whatever is standing there
        float clutchIn = clamp01((t - (MotherHand.CLUTCH_AT - 6)) / 6.0F);
        float clutchOut = clamp01((t - (MotherHand.CLUTCH_AT + 18)) / 8.0F);
        float clutch = clutchIn * (1.0F - clutchOut);
        curl = Mth.lerp(clutch, curl, 1.25F);
        forearm.xRot -= clutch * 0.35F;

        for (int i = 0; i < 4; i++) {
            float lag = (i - 1.5F) * 0.05F;
            float c = curl + lag + (t > MotherHand.SINK_FROM ? stepNoise(t, 2.0F, seed + i) * 0.3F : 0.0F);
            fingers[i].xRot += c * 0.5F;
            mids[i].xRot += c * 0.75F;
            tips[i].xRot += c * 0.8F;
            fingers[i].zRot += (i - 1.5F) * 0.12F * (1.0F - clamp01(c));
        }
        thumb.zRot -= curl * 0.6F;
        thumbTip.xRot += curl * 0.5F;
    }
}
