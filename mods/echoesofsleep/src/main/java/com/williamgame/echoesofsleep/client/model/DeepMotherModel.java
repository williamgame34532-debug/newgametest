package com.williamgame.echoesofsleep.client.model;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.entity.DeepMother;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.*;
import net.minecraft.util.Mth;

/**
 * Deep Mother: an emaciated giant torso with an exposed ribcage and vertebrae, a long bent neck,
 * a skull with an unhinged jaw and hanging hair, and two huge arms whose hands end in three-jointed fingers.
 * Rises out of the floor (renderer offset), sweeps and slams.
 * Geometry: UVs packed by tools/ (see generate_textures.py, which reads the boxes below to paint the texture).
 */
public class DeepMotherModel extends NightmareModel<DeepMother> {
    public static final ModelLayerLocation LAYER = new ModelLayerLocation(EchoesOfSleep.id("deep_mother"), "main");

    private final ModelPart pelvis;
    private final ModelPart abdomen;
    private final ModelPart ribcage;
    private final ModelPart ribs;
    private final ModelPart spine;
    private final ModelPart shoulders;
    private final ModelPart neck;
    private final ModelPart head;
    private final ModelPart jaw;
    private final ModelPart hair0;
    private final ModelPart hair1;
    private final ModelPart hair2;
    private final ModelPart hair3;
    private final ModelPart hair4;
    private final ModelPart hair5;
    private final ModelPart rightArm;
    private final ModelPart rightForearm;
    private final ModelPart rightHand;
    private final ModelPart rightFinger0;
    private final ModelPart rightFinger0Mid;
    private final ModelPart rightFinger0Tip;
    private final ModelPart rightFinger1;
    private final ModelPart rightFinger1Mid;
    private final ModelPart rightFinger1Tip;
    private final ModelPart rightFinger2;
    private final ModelPart rightFinger2Mid;
    private final ModelPart rightFinger2Tip;
    private final ModelPart rightFinger3;
    private final ModelPart rightFinger3Mid;
    private final ModelPart rightFinger3Tip;
    private final ModelPart rightThumb;
    private final ModelPart rightThumbTip;
    private final ModelPart leftArm;
    private final ModelPart leftForearm;
    private final ModelPart leftHand;
    private final ModelPart leftFinger0;
    private final ModelPart leftFinger0Mid;
    private final ModelPart leftFinger0Tip;
    private final ModelPart leftFinger1;
    private final ModelPart leftFinger1Mid;
    private final ModelPart leftFinger1Tip;
    private final ModelPart leftFinger2;
    private final ModelPart leftFinger2Mid;
    private final ModelPart leftFinger2Tip;
    private final ModelPart leftFinger3;
    private final ModelPart leftFinger3Mid;
    private final ModelPart leftFinger3Tip;
    private final ModelPart leftThumb;
    private final ModelPart leftThumbTip;

    public DeepMotherModel(ModelPart root) {
        super(root);
        this.pelvis = root.getChild("pelvis");
        this.abdomen = root.getChild("pelvis").getChild("abdomen");
        this.ribcage = root.getChild("pelvis").getChild("abdomen").getChild("ribcage");
        this.ribs = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("ribs");
        this.spine = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("spine");
        this.shoulders = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders");
        this.neck = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("neck");
        this.head = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("neck").getChild("head");
        this.jaw = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("neck").getChild("head").getChild("jaw");
        this.hair0 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("neck").getChild("head").getChild("hair_0");
        this.hair1 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("neck").getChild("head").getChild("hair_1");
        this.hair2 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("neck").getChild("head").getChild("hair_2");
        this.hair3 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("neck").getChild("head").getChild("hair_3");
        this.hair4 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("neck").getChild("head").getChild("hair_4");
        this.hair5 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("neck").getChild("head").getChild("hair_5");
        this.rightArm = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm");
        this.rightForearm = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm");
        this.rightHand = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand");
        this.rightFinger0 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_0");
        this.rightFinger0Mid = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_0").getChild("right_finger_0_mid");
        this.rightFinger0Tip = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_0").getChild("right_finger_0_mid").getChild("right_finger_0_tip");
        this.rightFinger1 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_1");
        this.rightFinger1Mid = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_1").getChild("right_finger_1_mid");
        this.rightFinger1Tip = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_1").getChild("right_finger_1_mid").getChild("right_finger_1_tip");
        this.rightFinger2 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_2");
        this.rightFinger2Mid = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_2").getChild("right_finger_2_mid");
        this.rightFinger2Tip = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_2").getChild("right_finger_2_mid").getChild("right_finger_2_tip");
        this.rightFinger3 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_3");
        this.rightFinger3Mid = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_3").getChild("right_finger_3_mid");
        this.rightFinger3Tip = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_finger_3").getChild("right_finger_3_mid").getChild("right_finger_3_tip");
        this.rightThumb = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_thumb");
        this.rightThumbTip = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("right_arm").getChild("right_forearm").getChild("right_hand").getChild("right_thumb").getChild("right_thumb_tip");
        this.leftArm = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm");
        this.leftForearm = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm");
        this.leftHand = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand");
        this.leftFinger0 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_0");
        this.leftFinger0Mid = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_0").getChild("left_finger_0_mid");
        this.leftFinger0Tip = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_0").getChild("left_finger_0_mid").getChild("left_finger_0_tip");
        this.leftFinger1 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_1");
        this.leftFinger1Mid = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_1").getChild("left_finger_1_mid");
        this.leftFinger1Tip = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_1").getChild("left_finger_1_mid").getChild("left_finger_1_tip");
        this.leftFinger2 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_2");
        this.leftFinger2Mid = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_2").getChild("left_finger_2_mid");
        this.leftFinger2Tip = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_2").getChild("left_finger_2_mid").getChild("left_finger_2_tip");
        this.leftFinger3 = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_3");
        this.leftFinger3Mid = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_3").getChild("left_finger_3_mid");
        this.leftFinger3Tip = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_finger_3").getChild("left_finger_3_mid").getChild("left_finger_3_tip");
        this.leftThumb = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_thumb");
        this.leftThumbTip = root.getChild("pelvis").getChild("abdomen").getChild("ribcage").getChild("shoulders").getChild("left_arm").getChild("left_forearm").getChild("left_hand").getChild("left_thumb").getChild("left_thumb_tip");
    }

    @SuppressWarnings("unused")
    public static LayerDefinition createLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition root = mesh.getRoot();
        PartDefinition pelvis = root.addOrReplaceChild("pelvis", CubeListBuilder.create()
                .texOffs(196, 24).addBox(-7.0F, -4.0F, -5.0F, 14.0F, 8.0F, 10.0F), PartPose.offset(0.0F, 4.0F, 0.0F));
        PartDefinition abdomen = pelvis.addOrReplaceChild("abdomen", CubeListBuilder.create()
                .texOffs(212, 0).addBox(-5.0F, -14.0F, -4.0F, 10.0F, 14.0F, 8.0F), PartPose.offsetAndRotation(0.0F, -4.0F, 0.0F, 0.12F, 0.0F, 0.0F));
        PartDefinition ribcage = abdomen.addOrReplaceChild("ribcage", CubeListBuilder.create()
                .texOffs(88, 0).addBox(-9.0F, -16.0F, -6.0F, 18.0F, 16.0F, 12.0F), PartPose.offsetAndRotation(0.0F, -13.0F, 0.0F, 0.2F, 0.0F, 0.0F));
        PartDefinition ribs = ribcage.addOrReplaceChild("ribs", CubeListBuilder.create()
                .texOffs(144, 52).addBox(-10.0F, 1.0F, -1.5F, 20.0F, 1.0F, 2.0F)
                .texOffs(188, 52).addBox(-10.0F, 4.0F, -1.5F, 20.0F, 1.0F, 2.0F)
                .texOffs(0, 53).addBox(-10.0F, 7.0F, -1.5F, 20.0F, 1.0F, 2.0F)
                .texOffs(92, 53).addBox(-10.0F, 10.0F, -1.5F, 20.0F, 1.0F, 2.0F)
                .texOffs(136, 55).addBox(-10.0F, 13.0F, -1.5F, 20.0F, 1.0F, 2.0F), PartPose.offset(0.0F, -14.0F, -6.0F));
        PartDefinition spine = ribcage.addOrReplaceChild("spine", CubeListBuilder.create()
                .texOffs(96, 47).addBox(-1.5F, 0.0F, -1.0F, 3.0F, 2.0F, 3.0F)
                .texOffs(108, 47).addBox(-1.5F, 3.0F, -1.0F, 3.0F, 2.0F, 3.0F)
                .texOffs(0, 48).addBox(-1.5F, 6.0F, -1.0F, 3.0F, 2.0F, 3.0F)
                .texOffs(12, 48).addBox(-1.5F, 9.0F, -1.0F, 3.0F, 2.0F, 3.0F)
                .texOffs(24, 48).addBox(-1.5F, 12.0F, -1.0F, 3.0F, 2.0F, 3.0F)
                .texOffs(120, 48).addBox(-1.5F, 15.0F, -1.0F, 3.0F, 2.0F, 3.0F)
                .texOffs(132, 48).addBox(-1.5F, 18.0F, -1.0F, 3.0F, 2.0F, 3.0F), PartPose.offset(0.0F, -15.0F, 6.0F));
        PartDefinition shoulders = ribcage.addOrReplaceChild("shoulders", CubeListBuilder.create()
                .texOffs(48, 31).addBox(-14.0F, -3.0F, -5.0F, 28.0F, 6.0F, 10.0F), PartPose.offset(0.0F, -15.0F, 0.0F));
        PartDefinition neck = shoulders.addOrReplaceChild("neck", CubeListBuilder.create()
                .texOffs(148, 25).addBox(-3.0F, -12.0F, -3.0F, 6.0F, 12.0F, 6.0F), PartPose.offsetAndRotation(0.0F, -2.0F, -2.0F, 0.7F, 0.0F, 0.0F));
        PartDefinition head = neck.addOrReplaceChild("head", CubeListBuilder.create()
                .texOffs(148, 0).addBox(-6.0F, -13.0F, -7.0F, 12.0F, 13.0F, 12.0F), PartPose.offsetAndRotation(0.0F, -11.0F, 0.0F, -0.5F, 0.0F, 0.0F));
        PartDefinition jaw = head.addOrReplaceChild("jaw", CubeListBuilder.create()
                .texOffs(0, 34).addBox(-5.0F, 0.0F, -11.0F, 10.0F, 4.0F, 10.0F), PartPose.offsetAndRotation(0.0F, -1.0F, 4.0F, 0.5F, 0.0F, 0.0F));
        PartDefinition hair0 = head.addOrReplaceChild("hair_0", CubeListBuilder.create()
                .texOffs(196, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 22.0F, 2.0F), PartPose.offset(-5.0F, -12.0F, -6.0F));
        PartDefinition hair1 = head.addOrReplaceChild("hair_1", CubeListBuilder.create()
                .texOffs(248, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 19.0F, 2.0F), PartPose.offset(-2.0F, -12.0F, 4.0F));
        PartDefinition hair2 = head.addOrReplaceChild("hair_2", CubeListBuilder.create()
                .texOffs(172, 25).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 16.0F, 2.0F), PartPose.offset(2.0F, -12.0F, 4.0F));
        PartDefinition hair3 = head.addOrReplaceChild("hair_3", CubeListBuilder.create()
                .texOffs(204, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 22.0F, 2.0F), PartPose.offset(5.0F, -12.0F, -6.0F));
        PartDefinition hair4 = head.addOrReplaceChild("hair_4", CubeListBuilder.create()
                .texOffs(248, 21).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 19.0F, 2.0F), PartPose.offset(-5.5F, -12.0F, 0.0F));
        PartDefinition hair5 = head.addOrReplaceChild("hair_5", CubeListBuilder.create()
                .texOffs(180, 25).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 16.0F, 2.0F), PartPose.offset(5.5F, -12.0F, 1.0F));
        PartDefinition rightArm = shoulders.addOrReplaceChild("right_arm", CubeListBuilder.create()
                .texOffs(0, 0).addBox(-3.0F, -2.0F, -3.0F, 6.0F, 28.0F, 6.0F), PartPose.offsetAndRotation(-15.0F, 0.0F, 0.0F, -0.4F, 0.0F, 0.25F));
        PartDefinition rightForearm = rightArm.addOrReplaceChild("right_forearm", CubeListBuilder.create()
                .texOffs(48, 0).addBox(-2.5F, 0.0F, -2.5F, 5.0F, 26.0F, 5.0F), PartPose.offsetAndRotation(0.0F, 27.0F, 0.0F, -0.7F, 0.0F, 0.0F));
        PartDefinition rightHand = rightForearm.addOrReplaceChild("right_hand", CubeListBuilder.create()
                .texOffs(188, 42).addBox(-4.5F, 0.0F, -3.5F, 9.0F, 3.0F, 7.0F), PartPose.offset(0.0F, 25.5F, 0.0F));
        PartDefinition rightFinger0 = rightHand.addOrReplaceChild("right_finger_0", CubeListBuilder.create()
                .texOffs(188, 25).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(-3.4F, 2.5F, -2.0F, -0.3F, 0.0F, -0.09F));
        PartDefinition rightFinger0Mid = rightFinger0.addOrReplaceChild("right_finger_0_mid", CubeListBuilder.create()
                .texOffs(148, 43).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 7.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 7.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition rightFinger0Tip = rightFinger0Mid.addOrReplaceChild("right_finger_0_tip", CubeListBuilder.create()
                .texOffs(244, 22).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 6.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition rightFinger1 = rightHand.addOrReplaceChild("right_finger_1", CubeListBuilder.create()
                .texOffs(124, 28).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(-1.15F, 2.5F, -2.0F, -0.3F, 0.0F, -0.03F));
        PartDefinition rightFinger1Mid = rightFinger1.addOrReplaceChild("right_finger_1_mid", CubeListBuilder.create()
                .texOffs(156, 43).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 7.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 7.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition rightFinger1Tip = rightFinger1Mid.addOrReplaceChild("right_finger_1_tip", CubeListBuilder.create()
                .texOffs(244, 29).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 6.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition rightFinger2 = rightHand.addOrReplaceChild("right_finger_2", CubeListBuilder.create()
                .texOffs(132, 28).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(1.1F, 2.5F, -2.0F, -0.3F, 0.0F, 0.03F));
        PartDefinition rightFinger2Mid = rightFinger2.addOrReplaceChild("right_finger_2_mid", CubeListBuilder.create()
                .texOffs(164, 43).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 7.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 7.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition rightFinger2Tip = rightFinger2Mid.addOrReplaceChild("right_finger_2_tip", CubeListBuilder.create()
                .texOffs(188, 35).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 6.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition rightFinger3 = rightHand.addOrReplaceChild("right_finger_3", CubeListBuilder.create()
                .texOffs(140, 28).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(3.35F, 2.5F, -2.0F, -0.3F, 0.0F, 0.09F));
        PartDefinition rightFinger3Mid = rightFinger3.addOrReplaceChild("right_finger_3_mid", CubeListBuilder.create()
                .texOffs(172, 43).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 7.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 7.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition rightFinger3Tip = rightFinger3Mid.addOrReplaceChild("right_finger_3_tip", CubeListBuilder.create()
                .texOffs(192, 35).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 6.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition rightThumb = rightHand.addOrReplaceChild("right_thumb", CubeListBuilder.create()
                .texOffs(64, 47).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 6.0F, 2.0F), PartPose.offsetAndRotation(-4.5F, 1.5F, -1.0F, -0.4F, 0.0F, 0.7F));
        PartDefinition rightThumbTip = rightThumb.addOrReplaceChild("right_thumb_tip", CubeListBuilder.create()
                .texOffs(244, 36).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 5.5F, 0.0F, -0.3F, 0.0F, 0.0F));
        PartDefinition leftArm = shoulders.addOrReplaceChild("left_arm", CubeListBuilder.create()
                .texOffs(24, 0).addBox(-3.0F, -2.0F, -3.0F, 6.0F, 28.0F, 6.0F), PartPose.offsetAndRotation(15.0F, 0.0F, 0.0F, -0.4F, 0.0F, -0.25F));
        PartDefinition leftForearm = leftArm.addOrReplaceChild("left_forearm", CubeListBuilder.create()
                .texOffs(68, 0).addBox(-2.5F, 0.0F, -2.5F, 5.0F, 26.0F, 5.0F), PartPose.offsetAndRotation(0.0F, 27.0F, 0.0F, -0.7F, 0.0F, 0.0F));
        PartDefinition leftHand = leftForearm.addOrReplaceChild("left_hand", CubeListBuilder.create()
                .texOffs(220, 42).addBox(-4.5F, 0.0F, -3.5F, 9.0F, 3.0F, 7.0F), PartPose.offset(0.0F, 25.5F, 0.0F));
        PartDefinition leftFinger0 = leftHand.addOrReplaceChild("left_finger_0", CubeListBuilder.create()
                .texOffs(40, 34).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(-3.4F, 2.5F, -2.0F, -0.3F, 0.0F, -0.09F));
        PartDefinition leftFinger0Mid = leftFinger0.addOrReplaceChild("left_finger_0_mid", CubeListBuilder.create()
                .texOffs(180, 43).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 7.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 7.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition leftFinger0Tip = leftFinger0Mid.addOrReplaceChild("left_finger_0_tip", CubeListBuilder.create()
                .texOffs(252, 42).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 6.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition leftFinger1 = leftHand.addOrReplaceChild("left_finger_1", CubeListBuilder.create()
                .texOffs(124, 38).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(-1.15F, 2.5F, -2.0F, -0.3F, 0.0F, -0.03F));
        PartDefinition leftFinger1Mid = leftFinger1.addOrReplaceChild("left_finger_1_mid", CubeListBuilder.create()
                .texOffs(40, 44).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 7.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 7.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition leftFinger1Tip = leftFinger1Mid.addOrReplaceChild("left_finger_1_tip", CubeListBuilder.create()
                .texOffs(80, 47).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 6.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition leftFinger2 = leftHand.addOrReplaceChild("left_finger_2", CubeListBuilder.create()
                .texOffs(132, 38).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(1.1F, 2.5F, -2.0F, -0.3F, 0.0F, 0.03F));
        PartDefinition leftFinger2Mid = leftFinger2.addOrReplaceChild("left_finger_2_mid", CubeListBuilder.create()
                .texOffs(48, 47).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 7.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 7.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition leftFinger2Tip = leftFinger2Mid.addOrReplaceChild("left_finger_2_tip", CubeListBuilder.create()
                .texOffs(84, 47).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 6.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition leftFinger3 = leftHand.addOrReplaceChild("left_finger_3", CubeListBuilder.create()
                .texOffs(140, 38).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 8.0F, 2.0F), PartPose.offsetAndRotation(3.35F, 2.5F, -2.0F, -0.3F, 0.0F, 0.09F));
        PartDefinition leftFinger3Mid = leftFinger3.addOrReplaceChild("left_finger_3_mid", CubeListBuilder.create()
                .texOffs(56, 47).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 7.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 7.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition leftFinger3Tip = leftFinger3Mid.addOrReplaceChild("left_finger_3_tip", CubeListBuilder.create()
                .texOffs(88, 47).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 6.5F, 0.0F, -0.35F, 0.0F, 0.0F));
        PartDefinition leftThumb = leftHand.addOrReplaceChild("left_thumb", CubeListBuilder.create()
                .texOffs(72, 47).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 6.0F, 2.0F), PartPose.offsetAndRotation(4.5F, 1.5F, -1.0F, -0.4F, 0.0F, -0.7F));
        PartDefinition leftThumbTip = leftThumb.addOrReplaceChild("left_thumb_tip", CubeListBuilder.create()
                .texOffs(92, 47).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 5.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 5.5F, 0.0F, -0.3F, 0.0F, 0.0F));
        return LayerDefinition.create(mesh, 256, 256);
    }

    @Override
    public void setupAnim(DeepMother entity, float limbSwing, float limbSwingAmount, float age, float netHeadYaw, float headPitch) {
        resetAll();
        int seed = entity.getId();
        boolean enraged = entity.getPhase() >= 2;
        float partial = age - entity.tickCount;

        // slow, rattling breath
        float breath = Mth.sin(age * 0.045F);
        ribcage.xScale = 1.0F + breath * 0.04F;
        ribcage.zScale = 1.0F + breath * 0.07F;
        ribs.zScale = 1.0F + Math.max(0.0F, breath) * 0.5F;
        abdomen.zRot += Mth.sin(age * 0.03F) * 0.05F;
        ribcage.xRot += Mth.sin(age * 0.05F) * 0.04F;

        // head: looks at you over a long, bent neck; the jaw hangs open
        head.yRot += netHeadYaw * Mth.DEG_TO_RAD * 0.8F;
        neck.xRot += headPitch * Mth.DEG_TO_RAD * 0.4F + smooth(age * 0.02F, seed) * 0.08F;
        head.zRot += smooth(age * 0.015F, seed + 1) * 0.25F;
        jaw.xRot += 0.2F + Math.max(0.0F, Mth.sin(age * 0.06F)) * 0.45F;

        // long fingers curling in a slow wave
        ModelPart[] fingers = {rightFinger0, rightFinger1, rightFinger2, rightFinger3, leftFinger0, leftFinger1, leftFinger2, leftFinger3};
        ModelPart[] mids = {rightFinger0Mid, rightFinger1Mid, rightFinger2Mid, rightFinger3Mid, leftFinger0Mid, leftFinger1Mid, leftFinger2Mid, leftFinger3Mid};
        ModelPart[] tips = {rightFinger0Tip, rightFinger1Tip, rightFinger2Tip, rightFinger3Tip, leftFinger0Tip, leftFinger1Tip, leftFinger2Tip, leftFinger3Tip};
        for (int i = 0; i < fingers.length; i++) {
            float c = 0.5F + 0.5F * Mth.sin(age * 0.1F + (i % 4) * 0.6F + (i / 4) * 2.0F);
            fingers[i].xRot -= c * 0.35F;
            mids[i].xRot -= c * 0.5F;
            tips[i].xRot -= c * 0.6F;
            if (enraged) fingers[i].xRot += stepNoise(age, 2.0F, seed + i) * 0.2F;
        }
        rightThumb.zRot += Mth.sin(age * 0.07F) * 0.15F;
        leftThumb.zRot -= Mth.sin(age * 0.07F + 1.0F) * 0.15F;

        rightArm.xRot += Mth.sin(age * 0.04F) * 0.1F;
        leftArm.xRot += Mth.sin(age * 0.04F + 2.0F) * 0.1F;
        rightForearm.xRot += smooth(age * 0.03F, seed + 3) * 0.12F;
        leftForearm.xRot += smooth(age * 0.03F, seed + 4) * 0.12F;

        byte state = entity.getMotherState();
        float stateTime = entity.tickCount - entity.clientStateStart + partial;
        if (state == DeepMother.EMERGING) {
            // she claws her way up: arms thrust upwards, then come down onto the floor
            float p = clamp01(stateTime / DeepMother.EMERGE_TICKS);
            float up = 1.0F - p;
            rightArm.xRot -= up * 2.4F;
            leftArm.xRot -= up * 2.4F;
            rightArm.zRot -= up * 0.3F;
            leftArm.zRot += up * 0.3F;
            rightForearm.xRot += up * 0.6F;
            leftForearm.xRot += up * 0.6F;
            head.xRot += up * 0.6F;
            jaw.xRot += up * 0.6F;
        } else if (state == DeepMother.SINKING || state == DeepMother.SUBMERGED) {
            float p = clamp01(stateTime / DeepMother.SINK_TICKS);
            rightArm.xRot -= p * 1.6F;
            leftArm.xRot -= p * 1.6F;
            head.xRot -= p * 0.5F;
        }

        byte attack = entity.getAttack();
        float at = entity.tickCount - entity.clientAttackStart + partial;
        if (attack == DeepMother.ATTACK_SWEEP) {
            float wind = clamp01(at / 12.0F);
            float strike = clamp01((at - 12.0F) / 4.0F);
            rightArm.zRot += wind * 1.2F - strike * 1.0F;
            rightArm.xRot -= wind * 0.9F;
            shoulders.yRot += wind * 0.5F - strike * 1.1F;
            rightForearm.xRot -= wind * 0.4F;
            jaw.xRot += wind * 0.5F;
        } else if (attack == DeepMother.ATTACK_SLAM) {
            float wind = clamp01(at / 17.0F);
            float strike = clamp01((at - 17.0F) / 3.0F);
            float raise = wind * (1.0F - strike);
            rightArm.xRot -= raise * 2.8F - strike * 0.4F;
            leftArm.xRot -= raise * 2.8F - strike * 0.4F;
            rightForearm.xRot += raise * 0.5F;
            leftForearm.xRot += raise * 0.5F;
            ribcage.xRot += strike * 0.4F - raise * 0.25F;
            head.xRot -= raise * 0.4F;
            jaw.xRot += raise * 0.7F;
        }

        if (enraged) {
            head.zRot += stepNoise(age, 3.0F, seed + 20) * 0.12F;
            neck.yRot += twitch(age, 5.0F, seed + 21, 0.7F) * 0.4F;
        }

        // hair hangs straight down whatever the head does, swaying
        float headPitchSum = pelvis.xRot + abdomen.xRot + ribcage.xRot + shoulders.xRot + neck.xRot + head.xRot;
        ModelPart[] hair = {hair0, hair1, hair2, hair3, hair4, hair5};
        for (int i = 0; i < hair.length; i++) {
            hair[i].xRot = -headPitchSum + Mth.sin(age * 0.05F + i) * 0.12F;
            hair[i].zRot = -head.zRot + Mth.cos(age * 0.04F + i * 1.7F) * 0.1F;
        }
    }
}
