package com.zone19.scp;

import com.zone19.scp.command.Zone19Command;
import com.zone19.scp.entity.Scp0492Entity;
import com.zone19.scp.story.StoryManager;
import com.zone19.scp.world.BlinkManager;
import com.zone19.scp.world.SkinManager;
import com.zone19.scp.world.ZoneManager;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.event.entity.living.LivingDeathEvent;
import net.minecraftforge.event.entity.player.PlayerEvent;
import net.minecraftforge.event.server.ServerStoppedEvent;
import net.minecraftforge.eventbus.api.EventPriority;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.server.ServerLifecycleHooks;

@Mod.EventBusSubscriber(modid = Zone19Mod.MODID)
public final class CommonEvents {
    @SubscribeEvent
    public static void onCommands(RegisterCommandsEvent event) {
        Zone19Command.register(event.getDispatcher());
    }

    @SubscribeEvent
    public static void onLogin(PlayerEvent.PlayerLoggedInEvent event) {
        if (event.getEntity() instanceof ServerPlayer p) {
            SkinManager.onLogin(p);
            ZoneManager.onLogin(p);
        }
    }

    @SubscribeEvent
    public static void onLogout(PlayerEvent.PlayerLoggedOutEvent event) {
        if (event.getEntity() instanceof ServerPlayer p) {
            SkinManager.onLogout(p);
            BlinkManager.forget(p.getUUID());
        }
    }

    @SubscribeEvent
    public static void onDimensionChange(PlayerEvent.PlayerChangedDimensionEvent event) {
        if (event.getEntity() instanceof ServerPlayer p) StoryManager.sync(p);
    }

    @SubscribeEvent
    public static void onRespawn(PlayerEvent.PlayerRespawnEvent event) {
        if (event.getEntity() instanceof ServerPlayer p) StoryManager.sync(p);
    }

    @SubscribeEvent
    public static void onPlayerTick(TickEvent.PlayerTickEvent event) {
        if (event.phase == TickEvent.Phase.END && event.player instanceof ServerPlayer p) BlinkManager.tick(p);
    }

    @SubscribeEvent
    public static void onServerTick(TickEvent.ServerTickEvent event) {
        if (event.phase != TickEvent.Phase.END) return;
        MinecraftServer server = ServerLifecycleHooks.getCurrentServer();
        if (server != null) StoryManager.serverTick(server);
    }

    @SubscribeEvent(priority = EventPriority.LOWEST)
    public static void onDeath(LivingDeathEvent event) {
        if (event.isCanceled() || event.getEntity().level().isClientSide) return;
        if (event.getEntity() instanceof Scp0492Entity) {
            MinecraftServer server = ServerLifecycleHooks.getCurrentServer();
            if (server != null) StoryManager.onKill(server, "scp049_2");
        } else if (event.getEntity() instanceof ServerPlayer p) {
            ZoneManager.onDeath(p);
        }
    }

    @SubscribeEvent
    public static void onClone(PlayerEvent.Clone event) {
        if (event.isWasDeath()) ZoneManager.onClone(event.getOriginal(), event.getEntity());
    }

    @SubscribeEvent
    public static void onServerStopped(ServerStoppedEvent event) {
        BlinkManager.clear();
        SkinManager.clear();
    }

    private CommonEvents() {
    }
}
