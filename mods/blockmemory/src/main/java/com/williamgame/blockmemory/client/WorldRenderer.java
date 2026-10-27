package com.williamgame.blockmemory.client;

import com.mojang.blaze3d.systems.RenderSystem;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.williamgame.blockmemory.history.HistoryAction;
import com.williamgame.blockmemory.network.LensPacket;
import net.minecraft.client.Camera;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.LevelRenderer;
import net.minecraft.client.renderer.LightTexture;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.Sheets;
import net.minecraft.client.renderer.block.BlockRenderDispatcher;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.client.resources.model.BakedModel;
import net.minecraft.util.Mth;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.client.model.data.ModelData;
import org.joml.Matrix4f;
import org.joml.Matrix4fStack;
import org.joml.Quaternionf;

import java.util.Iterator;

/** Renders ghost replays (translucent blocks) and Echo Lens outlines in the world. */
public final class WorldRenderer {
    private WorldRenderer() {
    }

    public static void render(Camera camera, float partialTick) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.level == null) return;
        boolean lens = !ClientHooks.lensMarks.isEmpty() && mc.level.getGameTime() - ClientHooks.lensTime < 50;
        if (ClientHooks.replays.isEmpty() && !lens) return;

        Vec3 cam = camera.getPosition();
        // Set our own model-view (camera rotation) so the result does not depend on what the stage left behind.
        Matrix4fStack modelView = RenderSystem.getModelViewStack();
        modelView.pushMatrix();
        modelView.identity();
        modelView.mul(new Matrix4f().rotation(camera.rotation().conjugate(new Quaternionf())));
        RenderSystem.applyModelViewMatrix();

        PoseStack pose = new PoseStack();
        pose.translate(-cam.x, -cam.y, -cam.z);
        MultiBufferSource.BufferSource buffers = mc.renderBuffers().bufferSource();
        long now = mc.level.getGameTime();
        float time = now + partialTick;

        if (!ClientHooks.replays.isEmpty()) {
            renderGhosts(mc, pose, buffers, now, time);
        }
        if (lens) {
            renderLens(pose, buffers, time);
        }

        modelView.popMatrix();
        RenderSystem.applyModelViewMatrix();
    }

    private static void renderGhosts(Minecraft mc, PoseStack pose, MultiBufferSource.BufferSource buffers, long now, float time) {
        BlockRenderDispatcher dispatcher = mc.getBlockRenderer();
        RenderType type = Sheets.translucentCullBlockSheet();
        Iterator<ClientHooks.Replay> it = ClientHooks.replays.iterator();
        while (it.hasNext()) {
            ClientHooks.Replay replay = it.next();
            float t = time - replay.start;
            if (t > replay.duration || now < replay.start - 5) {
                it.remove();
                continue;
            }
            float fadeOut = Mth.clamp((replay.duration - t) / 30F, 0F, 1F);
            for (ClientHooks.Ghost g : replay.ghosts) {
                float appear = Mth.clamp((t - g.delay) / 12F, 0F, 1F);
                if (appear <= 0F) continue;
                float flicker = 0.85F + 0.15F * Mth.sin(time * 0.12F + g.phase);
                float alpha = 0.55F * appear * fadeOut * flicker;
                if (alpha < 0.02F) continue;
                float ease = 1F - (1F - appear) * (1F - appear);
                float scale = 0.55F + 0.45F * ease;
                float rise = (1F - ease) * -0.7F;
                pose.pushPose();
                pose.translate(g.pos.getX() + 0.5, g.pos.getY() + 0.5 + rise, g.pos.getZ() + 0.5);
                pose.scale(scale, scale, scale);
                pose.translate(-0.5, -0.5, -0.5);
                float r = g.ancient ? 1.0F : 0.62F;
                float gg = g.ancient ? 0.86F : 0.86F;
                float b = g.ancient ? 0.58F : 1.0F;
                VertexConsumer vc = new TintedConsumer(buffers.getBuffer(type), r, gg, b, alpha);
                BakedModel model = dispatcher.getBlockModel(g.state);
                dispatcher.getModelRenderer().renderModel(pose.last(), vc, g.state, model, 1F, 1F, 1F,
                        LightTexture.FULL_BRIGHT, OverlayTexture.NO_OVERLAY, ModelData.EMPTY, null);
                pose.popPose();
            }
        }
        buffers.endBatch(type);
    }

    private static void renderLens(PoseStack pose, MultiBufferSource.BufferSource buffers, float time) {
        VertexConsumer lines = buffers.getBuffer(RenderType.lines());
        float pulse = 0.8F + 0.2F * Mth.sin(time * 0.2F);
        for (LensPacket.Mark m : ClientHooks.lensMarks) {
            float age = m.ageFraction() / 255F;
            float alpha = (0.85F - 0.6F * age) * pulse;
            float r, g, b;
            switch (HistoryAction.byId(m.action())) {
                case PLACED -> { r = 0.35F; g = 1.0F; b = 0.55F; }
                case EXPLODED -> { r = 1.0F; g = 0.6F; b = 0.15F; }
                case RESTORED -> { r = 0.4F; g = 0.85F; b = 1.0F; }
                default -> { r = 1.0F; g = 0.3F; b = 0.35F; }
            }
            AABB box = new AABB(m.pos()).inflate(0.003 + 0.02 * (1 - age));
            LevelRenderer.renderLineBox(pose, lines, box, r, g, b, alpha);
        }
        buffers.endBatch(RenderType.lines());
    }
}
