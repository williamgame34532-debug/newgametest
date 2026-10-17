package com.zone19.scp.client.render;

import com.zone19.scp.entity.Scp096Entity;
import net.minecraft.client.model.HumanoidModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.util.Mth;

/** Calm: hunched, hands over its face. Triggered: arms thrown up. Rage: sprinting, arms flailing. */
public class Scp096Model extends HumanoidModel<Scp096Entity> {
    public Scp096Model(ModelPart root) {
        super(root);
    }

    @Override
    public void setupAnim(Scp096Entity e, float limbSwing, float limbSwingAmount, float age, float headYaw, float headPitch) {
        super.setupAnim(e, limbSwing, limbSwingAmount, age, headYaw, headPitch);
        switch (e.getState()) {
            case Scp096Entity.CALM -> {
                head.xRot = 0.55F;
                rightArm.xRot = -2.25F;
                rightArm.yRot = -0.55F;
                leftArm.xRot = -2.25F;
                leftArm.yRot = 0.55F;
                body.xRot = 0.25F;
                rightArm.xRot += Mth.sin(age * 0.25F) * 0.04F;
                leftArm.xRot += Mth.cos(age * 0.25F) * 0.04F;
            }
            case Scp096Entity.TRIGGERED -> {
                float shake = Mth.sin(age * 2.2F) * 0.25F;
                rightArm.xRot = -2.9F + shake;
                leftArm.xRot = -2.9F - shake;
                rightArm.zRot = 0.3F;
                leftArm.zRot = -0.3F;
                head.xRot = -0.4F + shake * 0.5F;
            }
            default -> {
                rightArm.xRot = -1.4F + Mth.sin(age * 1.3F) * 0.7F;
                leftArm.xRot = -1.4F - Mth.sin(age * 1.3F) * 0.7F;
                head.xRot = -0.15F;
                body.xRot = 0.35F;
            }
        }
        hat.copyFrom(head);
    }
}
