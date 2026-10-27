package com.williamgame.echoesofsleep.client.model;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.entity.TheDreamer;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.*;
import net.minecraft.util.Mth;

/**
 * The Dreamer: a floating ribbed body in tattered strips with a vertebral tail, six two-jointed arms with
 * three fingers each, a head with one enormous lidded eye and a crown of spikes, and four orbiting eyes.
 * Geometry: UVs packed by tools/ (see generate_textures.py, which reads the boxes below to paint the texture).
 */
public class DreamerModel extends NightmareModel<TheDreamer> {
    public static final ModelLayerLocation LAYER = new ModelLayerLocation(EchoesOfSleep.id("the_dreamer"), "main");

    private final ModelPart chest;
    private final ModelPart ribs;
    private final ModelPart pelvis;
    private final ModelPart strip0;
    private final ModelPart strip1;
    private final ModelPart strip2;
    private final ModelPart strip3;
    private final ModelPart strip4;
    private final ModelPart strip5;
    private final ModelPart strip6;
    private final ModelPart tail0;
    private final ModelPart tail1;
    private final ModelPart tail2;
    private final ModelPart tail3;
    private final ModelPart tail4;
    private final ModelPart neck;
    private final ModelPart head;
    private final ModelPart eyeball;
    private final ModelPart lidTop;
    private final ModelPart lidBottom;
    private final ModelPart spike0;
    private final ModelPart spike1;
    private final ModelPart spike2;
    private final ModelPart spike3;
    private final ModelPart spike4;
    private final ModelPart spike5;
    private final ModelPart spike6;
    private final ModelPart rightUpperArm;
    private final ModelPart rightUpperArmFore;
    private final ModelPart rightUpperArmHand;
    private final ModelPart rightUpperArmHandF0;
    private final ModelPart rightUpperArmHandF1;
    private final ModelPart rightUpperArmHandF2;
    private final ModelPart leftUpperArm;
    private final ModelPart leftUpperArmFore;
    private final ModelPart leftUpperArmHand;
    private final ModelPart leftUpperArmHandF0;
    private final ModelPart leftUpperArmHandF1;
    private final ModelPart leftUpperArmHandF2;
    private final ModelPart rightMiddleArm;
    private final ModelPart rightMiddleArmFore;
    private final ModelPart rightMiddleArmHand;
    private final ModelPart rightMiddleArmHandF0;
    private final ModelPart rightMiddleArmHandF1;
    private final ModelPart rightMiddleArmHandF2;
    private final ModelPart leftMiddleArm;
    private final ModelPart leftMiddleArmFore;
    private final ModelPart leftMiddleArmHand;
    private final ModelPart leftMiddleArmHandF0;
    private final ModelPart leftMiddleArmHandF1;
    private final ModelPart leftMiddleArmHandF2;
    private final ModelPart rightLowerArm;
    private final ModelPart rightLowerArmFore;
    private final ModelPart rightLowerArmHand;
    private final ModelPart rightLowerArmHandF0;
    private final ModelPart rightLowerArmHandF1;
    private final ModelPart rightLowerArmHandF2;
    private final ModelPart leftLowerArm;
    private final ModelPart leftLowerArmFore;
    private final ModelPart leftLowerArmHand;
    private final ModelPart leftLowerArmHandF0;
    private final ModelPart leftLowerArmHandF1;
    private final ModelPart leftLowerArmHandF2;
    private final ModelPart orb0;
    private final ModelPart orb1;
    private final ModelPart orb2;
    private final ModelPart orb3;

    public DreamerModel(ModelPart root) {
        super(root);
        this.chest = root.getChild("chest");
        this.ribs = root.getChild("chest").getChild("ribs");
        this.pelvis = root.getChild("chest").getChild("pelvis");
        this.strip0 = root.getChild("chest").getChild("pelvis").getChild("strip_0");
        this.strip1 = root.getChild("chest").getChild("pelvis").getChild("strip_1");
        this.strip2 = root.getChild("chest").getChild("pelvis").getChild("strip_2");
        this.strip3 = root.getChild("chest").getChild("pelvis").getChild("strip_3");
        this.strip4 = root.getChild("chest").getChild("pelvis").getChild("strip_4");
        this.strip5 = root.getChild("chest").getChild("pelvis").getChild("strip_5");
        this.strip6 = root.getChild("chest").getChild("pelvis").getChild("strip_6");
        this.tail0 = root.getChild("chest").getChild("pelvis").getChild("tail_0");
        this.tail1 = root.getChild("chest").getChild("pelvis").getChild("tail_0").getChild("tail_1");
        this.tail2 = root.getChild("chest").getChild("pelvis").getChild("tail_0").getChild("tail_1").getChild("tail_2");
        this.tail3 = root.getChild("chest").getChild("pelvis").getChild("tail_0").getChild("tail_1").getChild("tail_2").getChild("tail_3");
        this.tail4 = root.getChild("chest").getChild("pelvis").getChild("tail_0").getChild("tail_1").getChild("tail_2").getChild("tail_3").getChild("tail_4");
        this.neck = root.getChild("chest").getChild("neck");
        this.head = root.getChild("chest").getChild("neck").getChild("head");
        this.eyeball = root.getChild("chest").getChild("neck").getChild("head").getChild("eyeball");
        this.lidTop = root.getChild("chest").getChild("neck").getChild("head").getChild("lid_top");
        this.lidBottom = root.getChild("chest").getChild("neck").getChild("head").getChild("lid_bottom");
        this.spike0 = root.getChild("chest").getChild("neck").getChild("head").getChild("spike_0");
        this.spike1 = root.getChild("chest").getChild("neck").getChild("head").getChild("spike_1");
        this.spike2 = root.getChild("chest").getChild("neck").getChild("head").getChild("spike_2");
        this.spike3 = root.getChild("chest").getChild("neck").getChild("head").getChild("spike_3");
        this.spike4 = root.getChild("chest").getChild("neck").getChild("head").getChild("spike_4");
        this.spike5 = root.getChild("chest").getChild("neck").getChild("head").getChild("spike_5");
        this.spike6 = root.getChild("chest").getChild("neck").getChild("head").getChild("spike_6");
        this.rightUpperArm = root.getChild("chest").getChild("right_upper_arm");
        this.rightUpperArmFore = root.getChild("chest").getChild("right_upper_arm").getChild("right_upper_arm_fore");
        this.rightUpperArmHand = root.getChild("chest").getChild("right_upper_arm").getChild("right_upper_arm_fore").getChild("right_upper_arm_hand");
        this.rightUpperArmHandF0 = root.getChild("chest").getChild("right_upper_arm").getChild("right_upper_arm_fore").getChild("right_upper_arm_hand").getChild("right_upper_arm_hand_f0");
        this.rightUpperArmHandF1 = root.getChild("chest").getChild("right_upper_arm").getChild("right_upper_arm_fore").getChild("right_upper_arm_hand").getChild("right_upper_arm_hand_f1");
        this.rightUpperArmHandF2 = root.getChild("chest").getChild("right_upper_arm").getChild("right_upper_arm_fore").getChild("right_upper_arm_hand").getChild("right_upper_arm_hand_f2");
        this.leftUpperArm = root.getChild("chest").getChild("left_upper_arm");
        this.leftUpperArmFore = root.getChild("chest").getChild("left_upper_arm").getChild("left_upper_arm_fore");
        this.leftUpperArmHand = root.getChild("chest").getChild("left_upper_arm").getChild("left_upper_arm_fore").getChild("left_upper_arm_hand");
        this.leftUpperArmHandF0 = root.getChild("chest").getChild("left_upper_arm").getChild("left_upper_arm_fore").getChild("left_upper_arm_hand").getChild("left_upper_arm_hand_f0");
        this.leftUpperArmHandF1 = root.getChild("chest").getChild("left_upper_arm").getChild("left_upper_arm_fore").getChild("left_upper_arm_hand").getChild("left_upper_arm_hand_f1");
        this.leftUpperArmHandF2 = root.getChild("chest").getChild("left_upper_arm").getChild("left_upper_arm_fore").getChild("left_upper_arm_hand").getChild("left_upper_arm_hand_f2");
        this.rightMiddleArm = root.getChild("chest").getChild("right_middle_arm");
        this.rightMiddleArmFore = root.getChild("chest").getChild("right_middle_arm").getChild("right_middle_arm_fore");
        this.rightMiddleArmHand = root.getChild("chest").getChild("right_middle_arm").getChild("right_middle_arm_fore").getChild("right_middle_arm_hand");
        this.rightMiddleArmHandF0 = root.getChild("chest").getChild("right_middle_arm").getChild("right_middle_arm_fore").getChild("right_middle_arm_hand").getChild("right_middle_arm_hand_f0");
        this.rightMiddleArmHandF1 = root.getChild("chest").getChild("right_middle_arm").getChild("right_middle_arm_fore").getChild("right_middle_arm_hand").getChild("right_middle_arm_hand_f1");
        this.rightMiddleArmHandF2 = root.getChild("chest").getChild("right_middle_arm").getChild("right_middle_arm_fore").getChild("right_middle_arm_hand").getChild("right_middle_arm_hand_f2");
        this.leftMiddleArm = root.getChild("chest").getChild("left_middle_arm");
        this.leftMiddleArmFore = root.getChild("chest").getChild("left_middle_arm").getChild("left_middle_arm_fore");
        this.leftMiddleArmHand = root.getChild("chest").getChild("left_middle_arm").getChild("left_middle_arm_fore").getChild("left_middle_arm_hand");
        this.leftMiddleArmHandF0 = root.getChild("chest").getChild("left_middle_arm").getChild("left_middle_arm_fore").getChild("left_middle_arm_hand").getChild("left_middle_arm_hand_f0");
        this.leftMiddleArmHandF1 = root.getChild("chest").getChild("left_middle_arm").getChild("left_middle_arm_fore").getChild("left_middle_arm_hand").getChild("left_middle_arm_hand_f1");
        this.leftMiddleArmHandF2 = root.getChild("chest").getChild("left_middle_arm").getChild("left_middle_arm_fore").getChild("left_middle_arm_hand").getChild("left_middle_arm_hand_f2");
        this.rightLowerArm = root.getChild("chest").getChild("right_lower_arm");
        this.rightLowerArmFore = root.getChild("chest").getChild("right_lower_arm").getChild("right_lower_arm_fore");
        this.rightLowerArmHand = root.getChild("chest").getChild("right_lower_arm").getChild("right_lower_arm_fore").getChild("right_lower_arm_hand");
        this.rightLowerArmHandF0 = root.getChild("chest").getChild("right_lower_arm").getChild("right_lower_arm_fore").getChild("right_lower_arm_hand").getChild("right_lower_arm_hand_f0");
        this.rightLowerArmHandF1 = root.getChild("chest").getChild("right_lower_arm").getChild("right_lower_arm_fore").getChild("right_lower_arm_hand").getChild("right_lower_arm_hand_f1");
        this.rightLowerArmHandF2 = root.getChild("chest").getChild("right_lower_arm").getChild("right_lower_arm_fore").getChild("right_lower_arm_hand").getChild("right_lower_arm_hand_f2");
        this.leftLowerArm = root.getChild("chest").getChild("left_lower_arm");
        this.leftLowerArmFore = root.getChild("chest").getChild("left_lower_arm").getChild("left_lower_arm_fore");
        this.leftLowerArmHand = root.getChild("chest").getChild("left_lower_arm").getChild("left_lower_arm_fore").getChild("left_lower_arm_hand");
        this.leftLowerArmHandF0 = root.getChild("chest").getChild("left_lower_arm").getChild("left_lower_arm_fore").getChild("left_lower_arm_hand").getChild("left_lower_arm_hand_f0");
        this.leftLowerArmHandF1 = root.getChild("chest").getChild("left_lower_arm").getChild("left_lower_arm_fore").getChild("left_lower_arm_hand").getChild("left_lower_arm_hand_f1");
        this.leftLowerArmHandF2 = root.getChild("chest").getChild("left_lower_arm").getChild("left_lower_arm_fore").getChild("left_lower_arm_hand").getChild("left_lower_arm_hand_f2");
        this.orb0 = root.getChild("orb_0");
        this.orb1 = root.getChild("orb_1");
        this.orb2 = root.getChild("orb_2");
        this.orb3 = root.getChild("orb_3");
    }

    @SuppressWarnings("unused")
    public static LayerDefinition createLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition root = mesh.getRoot();
        PartDefinition chest = root.addOrReplaceChild("chest", CubeListBuilder.create()
                .texOffs(0, 0).addBox(-6.0F, -14.0F, -4.0F, 12.0F, 14.0F, 8.0F), PartPose.offset(0.0F, -12.0F, 0.0F));
        PartDefinition ribs = chest.addOrReplaceChild("ribs", CubeListBuilder.create()
                .texOffs(78, 55).addBox(-7.0F, 0.0F, -1.0F, 14.0F, 1.0F, 2.0F)
                .texOffs(0, 56).addBox(-7.0F, 2.0F, -1.0F, 14.0F, 1.0F, 2.0F)
                .texOffs(78, 58).addBox(-7.0F, 4.0F, -1.0F, 14.0F, 1.0F, 2.0F)
                .texOffs(0, 59).addBox(-7.0F, 6.0F, -1.0F, 14.0F, 1.0F, 2.0F)
                .texOffs(32, 59).addBox(-7.0F, 8.0F, -1.0F, 14.0F, 1.0F, 2.0F), PartPose.offset(0.0F, -11.0F, -4.0F));
        PartDefinition pelvis = chest.addOrReplaceChild("pelvis", CubeListBuilder.create()
                .texOffs(0, 34).addBox(-4.0F, 0.0F, -3.0F, 8.0F, 4.0F, 6.0F), PartPose.offset(0.0F, 0.0F, 0.0F));
        PartDefinition strip0 = pelvis.addOrReplaceChild("strip_0", CubeListBuilder.create()
                .texOffs(80, 0).addBox(-1.5F, 0.0F, -0.5F, 3.0F, 20.0F, 1.0F), PartPose.offsetAndRotation(-4.5F, 3.0F, -3.2F, -0.12F, 0.0F, 0.158F));
        PartDefinition strip1 = pelvis.addOrReplaceChild("strip_1", CubeListBuilder.create()
                .texOffs(104, 0).addBox(-1.5F, 0.0F, -0.5F, 3.0F, 17.0F, 1.0F), PartPose.offsetAndRotation(-1.5F, 3.0F, -3.6F, -0.12F, 0.0F, 0.053F));
        PartDefinition strip2 = pelvis.addOrReplaceChild("strip_2", CubeListBuilder.create()
                .texOffs(48, 21).addBox(-1.5F, 0.0F, -0.5F, 3.0F, 14.0F, 1.0F), PartPose.offsetAndRotation(1.5F, 3.0F, -3.6F, -0.12F, 0.0F, -0.053F));
        PartDefinition strip3 = pelvis.addOrReplaceChild("strip_3", CubeListBuilder.create()
                .texOffs(88, 0).addBox(-1.5F, 0.0F, -0.5F, 3.0F, 20.0F, 1.0F), PartPose.offsetAndRotation(4.5F, 3.0F, -3.2F, -0.12F, 0.0F, -0.158F));
        PartDefinition strip4 = pelvis.addOrReplaceChild("strip_4", CubeListBuilder.create()
                .texOffs(112, 0).addBox(-1.5F, 0.0F, -0.5F, 3.0F, 17.0F, 1.0F), PartPose.offsetAndRotation(-4.0F, 3.0F, 2.8F, 0.12F, 0.0F, 0.14F));
        PartDefinition strip5 = pelvis.addOrReplaceChild("strip_5", CubeListBuilder.create()
                .texOffs(56, 21).addBox(-1.5F, 0.0F, -0.5F, 3.0F, 14.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 3.0F, 3.4F, 0.12F, 0.0F, 0.0F));
        PartDefinition strip6 = pelvis.addOrReplaceChild("strip_6", CubeListBuilder.create()
                .texOffs(96, 0).addBox(-1.5F, 0.0F, -0.5F, 3.0F, 20.0F, 1.0F), PartPose.offsetAndRotation(4.0F, 3.0F, 2.8F, 0.12F, 0.0F, -0.14F));
        PartDefinition tail0 = pelvis.addOrReplaceChild("tail_0", CubeListBuilder.create()
                .texOffs(28, 40).addBox(-1.5F, 0.0F, -1.5F, 3.0F, 5.0F, 3.0F), PartPose.offsetAndRotation(0.0F, 4.0F, 1.0F, 0.15F, 0.0F, 0.0F));
        PartDefinition tail1 = tail0.addOrReplaceChild("tail_1", CubeListBuilder.create()
                .texOffs(80, 43).addBox(-1.5F, 0.0F, -1.5F, 3.0F, 5.0F, 3.0F), PartPose.offsetAndRotation(0.0F, 4.5F, 0.0F, 0.15F, 0.0F, 0.0F));
        PartDefinition tail2 = tail1.addOrReplaceChild("tail_2", CubeListBuilder.create()
                .texOffs(40, 37).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 5.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 4.5F, 0.0F, 0.15F, 0.0F, 0.0F));
        PartDefinition tail3 = tail2.addOrReplaceChild("tail_3", CubeListBuilder.create()
                .texOffs(106, 43).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 5.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 4.5F, 0.0F, 0.15F, 0.0F, 0.0F));
        PartDefinition tail4 = tail3.addOrReplaceChild("tail_4", CubeListBuilder.create()
                .texOffs(114, 43).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 5.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 4.5F, 0.0F, 0.15F, 0.0F, 0.0F));
        PartDefinition neck = chest.addOrReplaceChild("neck", CubeListBuilder.create()
                .texOffs(64, 35).addBox(-2.0F, -5.0F, -2.0F, 4.0F, 5.0F, 4.0F), PartPose.offset(0.0F, -13.5F, 0.0F));
        PartDefinition head = neck.addOrReplaceChild("head", CubeListBuilder.create()
                .texOffs(40, 0).addBox(-5.0F, -11.0F, -5.0F, 10.0F, 11.0F, 10.0F), PartPose.offset(0.0F, -4.5F, 0.0F));
        PartDefinition eyeball = head.addOrReplaceChild("eyeball", CubeListBuilder.create()
                .texOffs(92, 43).addBox(-3.0F, -3.0F, -1.0F, 6.0F, 6.0F, 1.0F), PartPose.offset(0.0F, -6.0F, -5.0F));
        PartDefinition lidTop = head.addOrReplaceChild("lid_top", CubeListBuilder.create()
                .texOffs(60, 51).addBox(-4.0F, -3.0F, -0.5F, 8.0F, 3.0F, 1.0F), PartPose.offset(0.0F, -6.0F, -6.0F));
        PartDefinition lidBottom = head.addOrReplaceChild("lid_bottom", CubeListBuilder.create()
                .texOffs(60, 55).addBox(-4.0F, 0.0F, -0.5F, 8.0F, 3.0F, 1.0F), PartPose.offset(0.0F, -6.0F, -6.0F));
        PartDefinition spike0 = head.addOrReplaceChild("spike_0", CubeListBuilder.create()
                .texOffs(32, 33).addBox(-0.5F, -6.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -10.0F, 1.5F, -0.3F, 0.0F, -1.2F));
        PartDefinition spike1 = head.addOrReplaceChild("spike_1", CubeListBuilder.create()
                .texOffs(36, 22).addBox(-0.5F, -8.0F, -0.5F, 1.0F, 8.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -10.0F, 1.5F, -0.3F, 0.0F, -0.8F));
        PartDefinition spike2 = head.addOrReplaceChild("spike_2", CubeListBuilder.create()
                .texOffs(100, 21).addBox(-0.5F, -10.0F, -0.5F, 1.0F, 10.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -10.0F, 1.5F, -0.3F, 0.0F, -0.4F));
        PartDefinition spike3 = head.addOrReplaceChild("spike_3", CubeListBuilder.create()
                .texOffs(96, 21).addBox(-0.5F, -12.0F, -0.5F, 1.0F, 12.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -10.0F, 1.5F, -0.3F, 0.0F, 0.0F));
        PartDefinition spike4 = head.addOrReplaceChild("spike_4", CubeListBuilder.create()
                .texOffs(32, 22).addBox(-0.5F, -10.0F, -0.5F, 1.0F, 10.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -10.0F, 1.5F, -0.3F, 0.0F, 0.4F));
        PartDefinition spike5 = head.addOrReplaceChild("spike_5", CubeListBuilder.create()
                .texOffs(36, 31).addBox(-0.5F, -8.0F, -0.5F, 1.0F, 8.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -10.0F, 1.5F, -0.3F, 0.0F, 0.8F));
        PartDefinition spike6 = head.addOrReplaceChild("spike_6", CubeListBuilder.create()
                .texOffs(122, 43).addBox(-0.5F, -6.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, -10.0F, 1.5F, -0.3F, 0.0F, 1.2F));
        PartDefinition rightUpperArm = chest.addOrReplaceChild("right_upper_arm", CubeListBuilder.create()
                .texOffs(104, 18).addBox(-1.5F, -1.0F, -1.5F, 3.0F, 14.0F, 3.0F), PartPose.offsetAndRotation(-6.5F, -12.0F, 0.0F, -0.2F, -0.35F, 1.05F));
        PartDefinition rightUpperArmFore = rightUpperArm.addOrReplaceChild("right_upper_arm_fore", CubeListBuilder.create()
                .texOffs(120, 0).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 14.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 12.5F, 0.0F, -0.5F, 0.0F, 0.0F));
        PartDefinition rightUpperArmHand = rightUpperArmFore.addOrReplaceChild("right_upper_arm_hand", CubeListBuilder.create()
                .texOffs(92, 50).addBox(-2.0F, 0.0F, -1.5F, 4.0F, 2.0F, 3.0F), PartPose.offset(0.0F, 13.5F, 0.0F));
        PartDefinition rightUpperArmHandF0 = rightUpperArmHand.addOrReplaceChild("right_upper_arm_hand_f0", CubeListBuilder.create()
                .texOffs(0, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(-1.3F, 1.5F, -0.5F, -0.3F, 0.0F, -0.15F));
        PartDefinition rightUpperArmHandF1 = rightUpperArmHand.addOrReplaceChild("right_upper_arm_hand_f1", CubeListBuilder.create()
                .texOffs(4, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 1.5F, -0.5F, -0.3F, 0.0F, 0.0F));
        PartDefinition rightUpperArmHandF2 = rightUpperArmHand.addOrReplaceChild("right_upper_arm_hand_f2", CubeListBuilder.create()
                .texOffs(8, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(1.3F, 1.5F, -0.5F, -0.3F, 0.0F, 0.15F));
        PartDefinition leftUpperArm = chest.addOrReplaceChild("left_upper_arm", CubeListBuilder.create()
                .texOffs(116, 18).addBox(-1.5F, -1.0F, -1.5F, 3.0F, 14.0F, 3.0F), PartPose.offsetAndRotation(6.5F, -12.0F, 0.0F, -0.2F, 0.35F, -1.05F));
        PartDefinition leftUpperArmFore = leftUpperArm.addOrReplaceChild("left_upper_arm_fore", CubeListBuilder.create()
                .texOffs(40, 21).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 14.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 12.5F, 0.0F, -0.5F, 0.0F, 0.0F));
        PartDefinition leftUpperArmHand = leftUpperArmFore.addOrReplaceChild("left_upper_arm_hand", CubeListBuilder.create()
                .texOffs(106, 50).addBox(-2.0F, 0.0F, -1.5F, 4.0F, 2.0F, 3.0F), PartPose.offset(0.0F, 13.5F, 0.0F));
        PartDefinition leftUpperArmHandF0 = leftUpperArmHand.addOrReplaceChild("left_upper_arm_hand_f0", CubeListBuilder.create()
                .texOffs(12, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(-1.3F, 1.5F, -0.5F, -0.3F, 0.0F, -0.15F));
        PartDefinition leftUpperArmHandF1 = leftUpperArmHand.addOrReplaceChild("left_upper_arm_hand_f1", CubeListBuilder.create()
                .texOffs(16, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 1.5F, -0.5F, -0.3F, 0.0F, 0.0F));
        PartDefinition leftUpperArmHandF2 = leftUpperArmHand.addOrReplaceChild("left_upper_arm_hand_f2", CubeListBuilder.create()
                .texOffs(20, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(1.3F, 1.5F, -0.5F, -0.3F, 0.0F, 0.15F));
        PartDefinition rightMiddleArm = chest.addOrReplaceChild("right_middle_arm", CubeListBuilder.create()
                .texOffs(64, 21).addBox(-1.0F, -1.0F, -1.0F, 2.0F, 12.0F, 2.0F), PartPose.offsetAndRotation(-6.5F, -8.0F, 0.0F, 0.1F, 0.1F, 0.6F));
        PartDefinition rightMiddleArmFore = rightMiddleArm.addOrReplaceChild("right_middle_arm_fore", CubeListBuilder.create()
                .texOffs(72, 21).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 12.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 10.5F, 0.0F, -0.5F, 0.0F, 0.0F));
        PartDefinition rightMiddleArmHand = rightMiddleArmFore.addOrReplaceChild("right_middle_arm_hand", CubeListBuilder.create()
                .texOffs(0, 51).addBox(-2.0F, 0.0F, -1.5F, 4.0F, 2.0F, 3.0F), PartPose.offset(0.0F, 11.5F, 0.0F));
        PartDefinition rightMiddleArmHandF0 = rightMiddleArmHand.addOrReplaceChild("right_middle_arm_hand_f0", CubeListBuilder.create()
                .texOffs(24, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(-1.3F, 1.5F, -0.5F, -0.3F, 0.0F, -0.15F));
        PartDefinition rightMiddleArmHandF1 = rightMiddleArmHand.addOrReplaceChild("right_middle_arm_hand_f1", CubeListBuilder.create()
                .texOffs(40, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 1.5F, -0.5F, -0.3F, 0.0F, 0.0F));
        PartDefinition rightMiddleArmHandF2 = rightMiddleArmHand.addOrReplaceChild("right_middle_arm_hand_f2", CubeListBuilder.create()
                .texOffs(44, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(1.3F, 1.5F, -0.5F, -0.3F, 0.0F, 0.15F));
        PartDefinition leftMiddleArm = chest.addOrReplaceChild("left_middle_arm", CubeListBuilder.create()
                .texOffs(80, 21).addBox(-1.0F, -1.0F, -1.0F, 2.0F, 12.0F, 2.0F), PartPose.offsetAndRotation(6.5F, -8.0F, 0.0F, 0.1F, -0.1F, -0.6F));
        PartDefinition leftMiddleArmFore = leftMiddleArm.addOrReplaceChild("left_middle_arm_fore", CubeListBuilder.create()
                .texOffs(88, 21).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 12.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 10.5F, 0.0F, -0.5F, 0.0F, 0.0F));
        PartDefinition leftMiddleArmHand = leftMiddleArmFore.addOrReplaceChild("left_middle_arm_hand", CubeListBuilder.create()
                .texOffs(14, 51).addBox(-2.0F, 0.0F, -1.5F, 4.0F, 2.0F, 3.0F), PartPose.offset(0.0F, 11.5F, 0.0F));
        PartDefinition leftMiddleArmHandF0 = leftMiddleArmHand.addOrReplaceChild("left_middle_arm_hand_f0", CubeListBuilder.create()
                .texOffs(48, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(-1.3F, 1.5F, -0.5F, -0.3F, 0.0F, -0.15F));
        PartDefinition leftMiddleArmHandF1 = leftMiddleArmHand.addOrReplaceChild("left_middle_arm_hand_f1", CubeListBuilder.create()
                .texOffs(52, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 1.5F, -0.5F, -0.3F, 0.0F, 0.0F));
        PartDefinition leftMiddleArmHandF2 = leftMiddleArmHand.addOrReplaceChild("left_middle_arm_hand_f2", CubeListBuilder.create()
                .texOffs(56, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(1.3F, 1.5F, -0.5F, -0.3F, 0.0F, 0.15F));
        PartDefinition rightLowerArm = chest.addOrReplaceChild("right_lower_arm", CubeListBuilder.create()
                .texOffs(0, 22).addBox(-1.0F, -1.0F, -1.0F, 2.0F, 10.0F, 2.0F), PartPose.offsetAndRotation(-6.5F, -4.0F, 0.0F, 0.35F, 0.45F, 0.3F));
        PartDefinition rightLowerArmFore = rightLowerArm.addOrReplaceChild("right_lower_arm_fore", CubeListBuilder.create()
                .texOffs(8, 22).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 10.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 8.5F, 0.0F, -0.5F, 0.0F, 0.0F));
        PartDefinition rightLowerArmHand = rightLowerArmFore.addOrReplaceChild("right_lower_arm_hand", CubeListBuilder.create()
                .texOffs(32, 51).addBox(-2.0F, 0.0F, -1.5F, 4.0F, 2.0F, 3.0F), PartPose.offset(0.0F, 9.5F, 0.0F));
        PartDefinition rightLowerArmHandF0 = rightLowerArmHand.addOrReplaceChild("right_lower_arm_hand_f0", CubeListBuilder.create()
                .texOffs(60, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(-1.3F, 1.5F, -0.5F, -0.3F, 0.0F, -0.15F));
        PartDefinition rightLowerArmHandF1 = rightLowerArmHand.addOrReplaceChild("right_lower_arm_hand_f1", CubeListBuilder.create()
                .texOffs(64, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 1.5F, -0.5F, -0.3F, 0.0F, 0.0F));
        PartDefinition rightLowerArmHandF2 = rightLowerArmHand.addOrReplaceChild("right_lower_arm_hand_f2", CubeListBuilder.create()
                .texOffs(68, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(1.3F, 1.5F, -0.5F, -0.3F, 0.0F, 0.15F));
        PartDefinition leftLowerArm = chest.addOrReplaceChild("left_lower_arm", CubeListBuilder.create()
                .texOffs(16, 22).addBox(-1.0F, -1.0F, -1.0F, 2.0F, 10.0F, 2.0F), PartPose.offsetAndRotation(6.5F, -4.0F, 0.0F, 0.35F, -0.45F, -0.3F));
        PartDefinition leftLowerArmFore = leftLowerArm.addOrReplaceChild("left_lower_arm_fore", CubeListBuilder.create()
                .texOffs(24, 22).addBox(-1.0F, 0.0F, -1.0F, 2.0F, 10.0F, 2.0F), PartPose.offsetAndRotation(0.0F, 8.5F, 0.0F, -0.5F, 0.0F, 0.0F));
        PartDefinition leftLowerArmHand = leftLowerArmFore.addOrReplaceChild("left_lower_arm_hand", CubeListBuilder.create()
                .texOffs(46, 51).addBox(-2.0F, 0.0F, -1.5F, 4.0F, 2.0F, 3.0F), PartPose.offset(0.0F, 9.5F, 0.0F));
        PartDefinition leftLowerArmHandF0 = leftLowerArmHand.addOrReplaceChild("left_lower_arm_hand_f0", CubeListBuilder.create()
                .texOffs(72, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(-1.3F, 1.5F, -0.5F, -0.3F, 0.0F, -0.15F));
        PartDefinition leftLowerArmHandF1 = leftLowerArmHand.addOrReplaceChild("left_lower_arm_hand_f1", CubeListBuilder.create()
                .texOffs(76, 44).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(0.0F, 1.5F, -0.5F, -0.3F, 0.0F, 0.0F));
        PartDefinition leftLowerArmHandF2 = leftLowerArmHand.addOrReplaceChild("left_lower_arm_hand_f2", CubeListBuilder.create()
                .texOffs(28, 48).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F), PartPose.offsetAndRotation(1.3F, 1.5F, -0.5F, -0.3F, 0.0F, 0.15F));
        PartDefinition orb0 = root.addOrReplaceChild("orb_0", CubeListBuilder.create()
                .texOffs(80, 35).addBox(-2.0F, -2.0F, -2.0F, 4.0F, 4.0F, 4.0F), PartPose.offset(0.0F, -20.0F, 0.0F));
        PartDefinition orb1 = root.addOrReplaceChild("orb_1", CubeListBuilder.create()
                .texOffs(96, 35).addBox(-2.0F, -2.0F, -2.0F, 4.0F, 4.0F, 4.0F), PartPose.offset(0.0F, -20.0F, 0.0F));
        PartDefinition orb2 = root.addOrReplaceChild("orb_2", CubeListBuilder.create()
                .texOffs(112, 35).addBox(-2.0F, -2.0F, -2.0F, 4.0F, 4.0F, 4.0F), PartPose.offset(0.0F, -20.0F, 0.0F));
        PartDefinition orb3 = root.addOrReplaceChild("orb_3", CubeListBuilder.create()
                .texOffs(48, 36).addBox(-2.0F, -2.0F, -2.0F, 4.0F, 4.0F, 4.0F), PartPose.offset(0.0F, -20.0F, 0.0F));
        return LayerDefinition.create(mesh, 128, 128);
    }

    @Override
    public void setupAnim(TheDreamer entity, float limbSwing, float limbSwingAmount, float age, float netHeadYaw, float headPitch) {
        resetAll();
        int seed = entity.getId();
        int phase = entity.getPhase();
        float partial = age - entity.tickCount;
        byte cast = entity.getCast();
        float castTime = entity.tickCount - entity.clientCastStart + partial;
        float cp = cast == TheDreamer.CAST_NONE ? 0.0F : clamp01(castTime / 8.0F);
        float glitch = phase >= 3 ? 1.0F : phase == 2 ? 0.4F : 0.0F;

        // it floats, breathing slowly
        chest.y += Mth.sin(age * 0.08F) * 1.5F;
        float breath = Mth.sin(age * 0.06F);
        chest.xScale = 1.0F + breath * 0.04F;
        ribs.zScale = 1.0F + Math.max(0.0F, breath) * 0.5F;

        // the head regards you; the crown of spikes slowly breathes open and shut
        head.yRot += netHeadYaw * Mth.DEG_TO_RAD * 0.7F;
        head.xRot += headPitch * Mth.DEG_TO_RAD * 0.5F;
        ModelPart[] spikes = {spike0, spike1, spike2, spike3, spike4, spike5, spike6};
        for (int i = 0; i < spikes.length; i++) {
            spikes[i].zRot *= 1.0F + Mth.sin(age * 0.04F) * 0.15F;
            spikes[i].zRot += Mth.sin(age * 0.03F + i) * 0.04F;
            spikes[i].xRot += Mth.cos(age * 0.05F + i * 0.8F) * 0.06F;
        }

        // the eye: a slit in phase 1, half open in phase 2, wide and darting in phase 3
        float open = phase == 1 ? 0.3F + Math.max(0.0F, twitch(age, 10.0F, seed, 0.8F)) * 0.5F : phase == 2 ? 0.65F : 1.0F;
        if (cast != TheDreamer.CAST_NONE) open = Math.max(open, 0.85F * cp);
        lidTop.xRot += open * 1.35F;
        lidBottom.xRot -= open * 1.35F;
        eyeball.x += Mth.clamp(netHeadYaw / 45.0F, -1.0F, 1.0F) * 0.6F + stepNoise(age, 4.0F, seed + 2) * 0.4F * glitch;
        eyeball.y += stepNoise(age, 5.0F, seed + 3) * 0.3F * glitch;

        // tattered strips and the vertebral tail ripple in a wind that is not there
        ModelPart[] strips = {strip0, strip1, strip2, strip3, strip4, strip5, strip6};
        for (int i = 0; i < strips.length; i++) {
            strips[i].xRot += Mth.sin(age * 0.07F + i) * 0.15F;
            strips[i].zRot += Mth.cos(age * 0.05F + i * 1.3F) * 0.12F + (i % 4 - 1.5F) * 0.04F;
        }
        ModelPart[] tail = {tail0, tail1, tail2, tail3, tail4};
        for (int i = 0; i < tail.length; i++) {
            tail[i].xRot += Mth.sin(age * 0.1F - i * 0.6F) * 0.2F;
            tail[i].zRot += Mth.cos(age * 0.08F - i * 0.6F) * 0.15F;
        }

        // six arms "conducting" the dream, each on its own rhythm
        ModelPart[] arms = {rightUpperArm, leftUpperArm, rightMiddleArm, leftMiddleArm, rightLowerArm, leftLowerArm};
        ModelPart[] fores = {rightUpperArmFore, leftUpperArmFore, rightMiddleArmFore, leftMiddleArmFore, rightLowerArmFore, leftLowerArmFore};
        ModelPart[][] hands = {
                {rightUpperArmHandF0, rightUpperArmHandF1, rightUpperArmHandF2}, {leftUpperArmHandF0, leftUpperArmHandF1, leftUpperArmHandF2},
                {rightMiddleArmHandF0, rightMiddleArmHandF1, rightMiddleArmHandF2}, {leftMiddleArmHandF0, leftMiddleArmHandF1, leftMiddleArmHandF2},
                {rightLowerArmHandF0, rightLowerArmHandF1, rightLowerArmHandF2}, {leftLowerArmHandF0, leftLowerArmHandF1, leftLowerArmHandF2}};
        for (int k = 0; k < arms.length; k++) {
            float sgn = (k % 2 == 0) ? 1.0F : -1.0F;
            int row = k / 2;
            arms[k].zRot += Mth.sin(age * 0.05F + k * 1.1F) * 0.15F * sgn;
            arms[k].xRot += Mth.sin(age * 0.04F + k * 1.7F) * 0.25F;
            fores[k].xRot += Mth.sin(age * 0.06F + k) * 0.2F;
            float grip = 0.5F + 0.5F * Mth.sin(age * 0.09F + k * 0.9F);

            switch (cast) {
                case TheDreamer.CAST_PULSE -> {
                    arms[k].zRot += 1.2F * sgn * cp;
                    arms[k].xRot -= 0.3F * cp;
                    fores[k].xRot += 0.3F * cp;
                    grip = 0.0F;
                }
                case TheDreamer.CAST_SUMMON -> {
                    arms[k].xRot -= (row < 2 ? 2.5F : 0.8F) * cp;
                    arms[k].zRot += (row == 2 ? 0.8F : 0.1F) * sgn * cp;
                    grip = 0.2F;
                }
                case TheDreamer.CAST_SWIPE -> {
                    if (row == 0) {
                        arms[k].xRot -= 1.7F * cp;
                        fores[k].xRot -= 0.3F * cp;
                    } else {
                        arms[k].xRot += 0.4F * cp;
                    }
                    grip = 1.0F;
                }
                case TheDreamer.CAST_PULL -> {
                    arms[k].xRot -= 1.4F * cp;
                    arms[k].zRot -= 0.3F * sgn * cp;
                    grip = 0.5F + 0.5F * Mth.sin(castTime * 0.8F);
                }
                default -> {
                }
            }
            for (int f = 0; f < 3; f++) {
                hands[k][f].xRot -= grip * 0.9F;
                hands[k][f].zRot += (f - 1) * 0.2F * (1.0F - grip);
            }
        }
        if (cast == TheDreamer.CAST_SWIPE) chest.xRot += 0.4F * cp;
        if (cast == TheDreamer.CAST_PULSE) head.xRot -= 0.4F * cp;

        // the floating eyes orbit it
        ModelPart[] orbs = {orb0, orb1, orb2, orb3};
        for (int i = 0; i < orbs.length; i++) {
            float a = age * (0.05F + phase * 0.015F) + i * Mth.HALF_PI;
            float r = 14.0F + Mth.sin(age * 0.07F + i) * 2.0F;
            orbs[i].x = Mth.cos(a) * r;
            orbs[i].z = Mth.sin(a) * r;
            orbs[i].y = -20.0F + Mth.sin(age * 0.1F + i * 1.3F) * 3.0F;
            orbs[i].yRot = -a;
            orbs[i].xRot = Mth.sin(age * 0.2F + i) * 0.3F;
        }

        // the dream starts tearing: parts skip like a broken film
        if (glitch > 0.0F) {
            head.x += stepNoise(age, 2.0F, seed + 10) * 0.8F * glitch * (stepNoise(age, 7.0F, seed + 11) > 0.4F ? 1.0F : 0.0F);
            chest.zRot += stepNoise(age, 2.0F, seed + 12) * 0.06F * glitch;
            neck.zRot += twitch(age, 3.0F, seed + 13, 0.7F) * 0.5F * glitch;
        }
    }
}
