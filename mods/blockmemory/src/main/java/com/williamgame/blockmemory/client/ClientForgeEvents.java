package com.williamgame.blockmemory.client;

import com.williamgame.blockmemory.BlockMemory;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.util.RandomSource;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.ClientPlayerNetworkEvent;
import net.minecraftforge.client.event.InputEvent;
import net.minecraftforge.client.event.RenderLevelStageEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = BlockMemory.MODID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
public class ClientForgeEvents {
    @SubscribeEvent
    public static void levelStage(RenderLevelStageEvent event) {
        if (event.getStage() == RenderLevelStageEvent.Stage.AFTER_PARTICLES) {
            WorldRenderer.render(event.getCamera(), event.getPartialTick());
        }
    }

    @SubscribeEvent
    public static void key(InputEvent.Key event) {
        Minecraft mc = Minecraft.getInstance();
        while (ClientModEvents.OPEN_CODEX.consumeClick()) {
            if (mc.player != null && mc.screen == null) ClientHooks.openCodex();
        }
    }

    @SubscribeEvent
    public static void tick(TickEvent.ClientTickEvent.Post event) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.level == null || mc.isPaused()) return;
        long now = mc.level.getGameTime();
        RandomSource random = mc.level.random;
        for (ClientHooks.Replay replay : ClientHooks.replays) {
            long t = now - replay.start;
            if (t > replay.duration - 20) continue;
            for (ClientHooks.Ghost g : replay.ghosts) {
                // a puff of glyphs when each ghost block arrives
                if (t == g.delay && random.nextInt(3) == 0) {
                    BlockPos p = g.pos;
                    mc.level.addParticle(ParticleTypes.ENCHANT, p.getX() + 0.5, p.getY() + 1.4, p.getZ() + 0.5,
                            (random.nextDouble() - 0.5) * 1.5, -1.0, (random.nextDouble() - 0.5) * 1.5);
                }
            }
            // whispers drifting off the ghosts
            for (int i = 0; i < 3 && !replay.ghosts.isEmpty(); i++) {
                ClientHooks.Ghost g = replay.ghosts.get(random.nextInt(replay.ghosts.size()));
                if (t < g.delay) continue;
                BlockPos p = g.pos;
                mc.level.addParticle(g.ancient ? ParticleTypes.WAX_OFF : ParticleTypes.SOUL_FIRE_FLAME,
                        p.getX() + random.nextDouble(), p.getY() + random.nextDouble(), p.getZ() + random.nextDouble(),
                        0, 0.01 + random.nextDouble() * 0.02, 0);
            }
        }
    }

    @SubscribeEvent
    public static void loggingOut(ClientPlayerNetworkEvent.LoggingOut event) {
        ClientHooks.clear();
        ClientHooks.fragments = 0;
        ClientHooks.claimed = 0;
        ClientHooks.unseen.clear();
    }
}
