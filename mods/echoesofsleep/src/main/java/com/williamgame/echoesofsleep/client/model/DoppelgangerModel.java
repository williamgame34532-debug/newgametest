package com.williamgame.echoesofsleep.client.model;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.williamgame.echoesofsleep.EchoesOfSleep;
import com.williamgame.echoesofsleep.entity.EchoDoppelganger;
import net.minecraft.client.model.geom.ModelLayerLocation;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.model.geom.PartPose;
import net.minecraft.client.model.geom.builders.*;
import net.minecraft.util.Mth;

/**
 * Echo Doppelganger: a player-shaped echo wearing its source player's skin (64x64 player layout), but
 * wrong: legs and body stretched, arms 1.6x too long and split at the elbow and knee so they can bend
 * the wrong way, long thin fingers, and no face - a separate mask part covers it (rendered by a layer).
 */
public class DoppelgangerModel extends NightmareModel<EchoDoppelganger> {
    public static final ModelLayerLocation LAYER = new ModelLayerLocation(EchoesOfSleep.id("echo_doppelganger"), "main");
    private static final float BODY_STRETCH = 1.1F;
    private static final float ARM_STRETCH = 1.6F;
    private static final float LEG_STRETCH = 1.25F;

    private final ModelPart body;
    private final ModelPart head;
    private final ModelPart mask;
    private final ModelPart[] arms = new ModelPart[4];      // right wide, left wide, right slim, left slim
    private final ModelPart[] forearms = new ModelPart[4];
    private final ModelPart[][] fingers = new ModelPart[4][4];
    private final ModelPart rightLeg, rightShin, leftLeg, leftShin;
    private boolean slim;

    public DoppelgangerModel(ModelPart root) {
        super(root);
        this.body = root.getChild("body");
        this.head = body.getChild("head");
        this.mask = head.getChild("mask");
        String[] names = {"right_arm", "left_arm", "right_arm_slim", "left_arm_slim"};
        for (int i = 0; i < 4; i++) {
            arms[i] = body.getChild(names[i]);
            forearms[i] = arms[i].getChild("forearm");
            for (int f = 0; f < 4; f++) {
                fingers[i][f] = forearms[i].getChild("finger_" + f);
            }
        }
        this.rightLeg = root.getChild("right_leg");
        this.rightShin = rightLeg.getChild("shin");
        this.leftLeg = root.getChild("left_leg");
        this.leftShin = leftLeg.getChild("shin");
    }

    public static LayerDefinition createLayer() {
        MeshDefinition mesh = new MeshDefinition();
        PartDefinition root = mesh.getRoot();
        PartDefinition body = root.addOrReplaceChild("body", CubeListBuilder.create()
                .texOffs(16, 16).addBox(-4.0F, -12.0F, -2.0F, 8.0F, 12.0F, 4.0F), PartPose.offset(0.0F, 9.0F, 0.0F));
        PartDefinition head = body.addOrReplaceChild("head", CubeListBuilder.create()
                .texOffs(0, 0).addBox(-4.0F, -8.0F, -4.0F, 8.0F, 8.0F, 8.0F)
                .texOffs(32, 0).addBox(-4.0F, -8.0F, -4.0F, 8.0F, 8.0F, 8.0F, new CubeDeformation(0.5F)), PartPose.offset(0.0F, -12.0F, 0.0F));
        // the faceless mask, drawn only by DoppelgangerMaskLayer with its own texture
        head.addOrReplaceChild("mask", CubeListBuilder.create()
                .texOffs(0, 0).addBox(-4.0F, -8.0F, -4.0F, 8.0F, 8.0F, 8.0F, new CubeDeformation(0.62F)), PartPose.ZERO);

        // arms: upper and lower half of the skin's arm texture, so the elbow can bend
        addArm(body, "right_arm", -5.0F, 40, 16, 40, 22, 4, -3.0F);
        addArm(body, "left_arm", 5.0F, 32, 48, 32, 54, 4, -1.0F);
        addArm(body, "right_arm_slim", -5.0F, 40, 16, 40, 22, 3, -2.0F);
        addArm(body, "left_arm_slim", 5.0F, 32, 48, 32, 54, 3, -1.0F);

        PartDefinition rightLeg = root.addOrReplaceChild("right_leg", CubeListBuilder.create()
                .texOffs(0, 16).addBox(-2.0F, 0.0F, -2.0F, 4.0F, 6.0F, 4.0F), PartPose.offset(-1.9F, 9.0F, 0.0F));
        rightLeg.addOrReplaceChild("shin", CubeListBuilder.create()
                .texOffs(0, 22).addBox(-2.0F, 0.0F, -2.0F, 4.0F, 6.0F, 4.0F), PartPose.offset(0.0F, 6.0F, 0.0F));
        PartDefinition leftLeg = root.addOrReplaceChild("left_leg", CubeListBuilder.create()
                .texOffs(16, 48).addBox(-2.0F, 0.0F, -2.0F, 4.0F, 6.0F, 4.0F), PartPose.offset(1.9F, 9.0F, 0.0F));
        leftLeg.addOrReplaceChild("shin", CubeListBuilder.create()
                .texOffs(16, 54).addBox(-2.0F, 0.0F, -2.0F, 4.0F, 6.0F, 4.0F), PartPose.offset(0.0F, 6.0F, 0.0F));
        return LayerDefinition.create(mesh, 64, 64);
    }

    private static void addArm(PartDefinition body, String name, float x, int u1, int v1, int u2, int v2, int width, float boxX) {
        PartDefinition arm = body.addOrReplaceChild(name, CubeListBuilder.create()
                .texOffs(u1, v1).addBox(boxX, -2.0F, -2.0F, width, 6.0F, 4.0F), PartPose.offset(x, -10.0F, 0.0F));
        float cx = boxX + width / 2.0F;
        PartDefinition forearm = arm.addOrReplaceChild("forearm", CubeListBuilder.create()
                .texOffs(u2, v2).addBox(-width / 2.0F, 0.0F, -2.0F, width, 6.0F, 4.0F), PartPose.offset(cx, 4.0F, 0.0F));
        // long thin fingers, textured from the skin's chin/neck area (head bottom face)
        for (int f = 0; f < 4; f++) {
            float fx = -width / 2.0F + 0.5F + f * (width - 1.0F) / 3.0F;
            forearm.addOrReplaceChild("finger_" + f, CubeListBuilder.create()
                    .texOffs(16, 0).addBox(-0.5F, 0.0F, -0.5F, 1.0F, 6.0F, 1.0F),
                    PartPose.offsetAndRotation(fx, 5.6F, -0.8F + (f == 0 || f == 3 ? 0.6F : 0.0F), 0.0F, 0.0F, (f - 1.5F) * 0.06F));
        }
    }

    public void setSlim(boolean slim) {
        this.slim = slim;
    }

    /** Draw only the face mask (used by the mask layer with its own textures). */
    public void renderMask(PoseStack poseStack, VertexConsumer buffer, int light, int overlay, int color) {
        root.getAllParts().forEach(p -> p.skipDraw = true);
        mask.skipDraw = false;
        mask.visible = true;
        root.render(poseStack, buffer, light, overlay, color);
        root.getAllParts().forEach(p -> p.skipDraw = false);
        mask.visible = false;
    }

    @Override
    public void setupAnim(EchoDoppelganger entity, float limbSwing, float limbSwingAmount, float age, float netHeadYaw, float headPitch) {
        resetAll();
        mask.visible = false;
        for (int i = 0; i < 4; i++) {
            boolean show = (i >= 2) == slim;
            arms[i].visible = show;
        }
        body.yScale = BODY_STRETCH;
        for (ModelPart arm : arms) arm.yScale = ARM_STRETCH / BODY_STRETCH;
        rightLeg.yScale = LEG_STRETCH;
        leftLeg.yScale = LEG_STRETCH;

        int seed = entity.getId();
        float partial = age - entity.tickCount;
        byte state = entity.getState();
        float stateT = entity.tickCount - entity.clientStateStart + partial;
        float w = limbSwing * 0.6662F;
        float amt = Math.min(1.0F, limbSwingAmount);

        // a face that is not there still looks at you
        head.yRot += netHeadYaw * Mth.DEG_TO_RAD;
        head.xRot += headPitch * Mth.DEG_TO_RAD;
        // stop-motion micro jitter: it never quite holds still
        head.xRot += stepNoise(age, 2.0F, seed) * 0.03F;
        head.yRot += stepNoise(age, 2.0F, seed + 1) * 0.03F;
        float breath = Mth.sin(age * 0.1F);
        body.zScale = 1.0F + breath * 0.05F;
        body.xScale = 1.0F + breath * 0.02F;

        for (int i = 0; i < 4; i++) {
            float side = (i % 2 == 0) ? 1.0F : -1.0F;
            arms[i].zRot += 0.06F * side;
            for (int f = 0; f < 4; f++) {
                fingers[i][f].xRot -= (0.5F + 0.5F * Mth.sin(age * 0.13F + f * 0.9F + i)) * 0.35F;
                fingers[i][f].xRot += twitch(age, 3.0F, seed + i * 4 + f, 0.85F) * 0.6F;
            }
        }

        if (state == EchoDoppelganger.STATE_HUNT) {
            // sprinting: leaning far forward, arms flung back, knees snapping the wrong way
            float run = limbSwing * 0.9F;
            float ramt = Math.max(0.6F, amt);
            body.xRot += 0.55F;
            head.xRot -= 0.45F;
            head.zRot += stepNoise(age, 2.0F, seed + 5) * 0.25F;
            rightLeg.xRot += Mth.cos(run) * 1.3F * ramt - 0.3F;
            leftLeg.xRot += Mth.cos(run + Mth.PI) * 1.3F * ramt - 0.3F;
            rightShin.xRot -= Math.max(0.0F, Mth.sin(run)) * 1.2F * ramt;
            leftShin.xRot -= Math.max(0.0F, Mth.sin(run + Mth.PI)) * 1.2F * ramt;
            for (int i = 0; i < 4; i++) {
                float ph = (i % 2 == 0) ? 0.0F : Mth.PI;
                arms[i].xRot += 1.1F + Mth.sin(run * 2.0F + ph) * 0.6F;
                arms[i].zRot += ((i % 2 == 0) ? 0.35F : -0.35F);
                forearms[i].xRot += 0.6F + Mth.sin(run * 2.0F + ph + 1.0F) * 0.5F;
                for (int f = 0; f < 4; f++) fingers[i][f].zRot += (f - 1.5F) * 0.3F;
            }
        } else if (state == EchoDoppelganger.STATE_STARE) {
            // frozen... the head slowly tilts over until it is almost sideways
            float p = clamp01(stateT / 22.0F);
            float ease = p * p * (3.0F - 2.0F * p);
            head.zRot += ease * 1.05F + stepNoise(age, 2.0F, seed + 6) * 0.04F * p;
            head.xRot -= ease * 0.15F;
            body.x += stepNoise(age, 2.0F, seed + 7) * 0.15F * p;
            body.zRot -= ease * 0.08F;
            for (int i = 0; i < 4; i++) {
                arms[i].xRot -= ease * 0.25F;
                arms[i].zRot += ((i % 2 == 0) ? 0.2F : -0.2F) * ease;
                forearms[i].xRot -= ease * 0.35F;
                for (int f = 0; f < 4; f++) {
                    fingers[i][f].zRot += (f - 1.5F) * 0.35F * ease;
                    fingers[i][f].xRot += 0.3F * ease;
                }
            }
            rightShin.xRot -= ease * 0.1F;
            leftShin.xRot -= ease * 0.1F;
        } else {
            // walking yesterday's path: mechanical legs, limp dangling arms, knees bending forward
            rightLeg.xRot += Mth.cos(w) * 0.9F * amt;
            leftLeg.xRot += Mth.cos(w + Mth.PI) * 0.9F * amt;
            rightShin.xRot -= Math.max(0.0F, Mth.sin(w)) * 0.8F * amt;
            leftShin.xRot -= Math.max(0.0F, Mth.sin(w + Mth.PI)) * 0.8F * amt;
            body.xRot += 0.12F + Math.abs(Mth.sin(w)) * 0.05F * amt;
            head.zRot += smooth(age * 0.02F, seed + 8) * 0.3F;
            for (int i = 0; i < 4; i++) {
                float ph = (i % 2 == 0) ? Mth.PI : 0.0F;
                arms[i].xRot += Mth.cos(w + ph) * 0.15F * amt;
                forearms[i].xRot += Mth.sin(w + ph - 0.8F) * 0.2F * amt;
            }
        }

        if (attackTime > 0.0F) {
            float a = Mth.sin(attackTime * Mth.PI);
            for (int i = 0; i < 4; i++) {
                arms[i].xRot -= a * 2.0F;
                forearms[i].xRot -= a * 0.4F;
            }
        }

        if (entity.isStunned()) {
            body.xRot += 0.5F;
            head.xRot += 0.6F;
            head.zRot += 0.4F;
        }
    }
}
