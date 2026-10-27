package com.williamgame.echoesofsleep.client.renderer;

import com.mojang.blaze3d.vertex.PoseStack;
import com.williamgame.echoesofsleep.client.model.DoppelgangerModel;
import com.williamgame.echoesofsleep.entity.EchoDoppelganger;
import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.ClientPacketListener;
import net.minecraft.client.multiplayer.PlayerInfo;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.entity.MobRenderer;
import net.minecraft.client.resources.DefaultPlayerSkin;
import net.minecraft.client.resources.PlayerSkin;
import net.minecraft.resources.ResourceLocation;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Renders the Doppelganger wearing the skin of the player it was made from. The skin comes from the
 * tab-list info of that player (works in multiplayer); if they are offline, the last skin we saw for them
 * is reused, and otherwise the default skin for their UUID.
 */
public class DoppelgangerRenderer extends MobRenderer<EchoDoppelganger, DoppelgangerModel> {
    private static final Map<UUID, PlayerSkin> SEEN = new HashMap<>();

    public DoppelgangerRenderer(EntityRendererProvider.Context ctx) {
        super(ctx, new DoppelgangerModel(ctx.bakeLayer(DoppelgangerModel.LAYER)), 0.5F);
        addLayer(new DoppelgangerMaskLayer(this));
    }

    static PlayerSkin skinOf(EchoDoppelganger entity) {
        Optional<UUID> source = entity.getSourceId();
        UUID id = source.orElse(entity.getUUID());
        if (source.isPresent()) {
            ClientPacketListener connection = Minecraft.getInstance().getConnection();
            PlayerInfo info = connection != null ? connection.getPlayerInfo(id) : null;
            if (info != null) {
                PlayerSkin skin = info.getSkin();
                SEEN.put(id, skin);
                return skin;
            }
            PlayerSkin cached = SEEN.get(id);
            if (cached != null) return cached;
        }
        return DefaultPlayerSkin.get(id);
    }

    @Override
    public void render(EchoDoppelganger entity, float yaw, float partialTicks, PoseStack poseStack, MultiBufferSource buffer, int light) {
        getModel().setSlim(skinOf(entity).model() == PlayerSkin.Model.SLIM);
        super.render(entity, yaw, partialTicks, poseStack, buffer, light);
    }

    @Override
    public ResourceLocation getTextureLocation(EchoDoppelganger entity) {
        return skinOf(entity).texture();
    }

    @Override
    protected boolean shouldShowName(EchoDoppelganger entity) {
        return false;
    }
}
