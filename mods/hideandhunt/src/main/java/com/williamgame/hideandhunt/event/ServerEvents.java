package com.williamgame.hideandhunt.event;

import com.williamgame.hideandhunt.command.HHCommands;
import com.williamgame.hideandhunt.game.GameManager;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.event.entity.item.ItemTossEvent;
import net.minecraftforge.event.entity.living.LivingAttackEvent;
import net.minecraftforge.event.entity.living.LivingDeathEvent;
import net.minecraftforge.event.entity.player.AttackEntityEvent;
import net.minecraftforge.event.entity.player.PlayerEvent;
import net.minecraftforge.event.server.ServerStoppedEvent;
import net.minecraftforge.event.server.ServerStoppingEvent;
import net.minecraftforge.eventbus.api.EventPriority;
import net.minecraftforge.eventbus.api.SubscribeEvent;

/** Forge-bus handlers (registered in the mod constructor). All server side. */
public final class ServerEvents {
    private ServerEvents() {}

    @SubscribeEvent
    public static void onCommands(RegisterCommandsEvent event) {
        HHCommands.register(event.getDispatcher());
    }

    @SubscribeEvent
    public static void onServerTick(TickEvent.ServerTickEvent.Post event) {
        GameManager.get(event.getServer()).tick();
    }

    @SubscribeEvent
    public static void onLogin(PlayerEvent.PlayerLoggedInEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) {
            GameManager.get(sp.server).onLogin(sp);
        }
    }

    @SubscribeEvent
    public static void onLogout(PlayerEvent.PlayerLoggedOutEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) {
            GameManager.get(sp.server).onLogout(sp);
        }
    }

    @SubscribeEvent
    public static void onDimension(PlayerEvent.PlayerChangedDimensionEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) {
            GameManager.get(sp.server).onDimensionChange(sp);
        }
    }

    @SubscribeEvent
    public static void onRespawn(PlayerEvent.PlayerRespawnEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) {
            GameManager.get(sp.server).onRespawn(sp);
        }
    }

    /** Melee tag: a hunter hitting a hider catches them (works even without damage). */
    @SubscribeEvent
    public static void onAttackEntity(AttackEntityEvent event) {
        if (event.getEntity() instanceof ServerPlayer attacker && event.getTarget() instanceof ServerPlayer target) {
            GameManager gm = GameManager.get(attacker.server);
            if (gm.tryCatch(attacker, target)) {
                event.setCanceled(true);
            }
        }
    }

    @SubscribeEvent
    public static void onLivingAttack(LivingAttackEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) {
            if (GameManager.get(sp.server).onPlayerAttacked(sp, event.getSource())) {
                event.setCanceled(true);
            }
        }
    }

    /** HIGHEST: a rescued participant must not be seen as dead by other mods' death handlers (graves, stats...). */
    @SubscribeEvent(priority = EventPriority.HIGHEST)
    public static void onDeath(LivingDeathEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) {
            if (GameManager.get(sp.server).onPlayerDeath(sp, event.getSource())) {
                event.setCanceled(true);
            }
        }
    }

    /**
     * Kit items can't be thrown away during a round: they are put back into the inventory instead
     * (the round inventory is wiped and replaced by the snapshot at the end anyway).
     * Not a dupe: in Forge 1.21.1 {@code ForgeHooks.onPlayerTossEvent} has already removed the stack from the
     * inventory and, when the event is cancelled, simply never spawns the ItemEntity (the item is destroyed).
     * If the inventory can't take everything back, only the remainder is dropped so nothing is lost either.
     */
    @SubscribeEvent
    public static void onToss(ItemTossEvent event) {
        if (event.getPlayer() instanceof ServerPlayer sp) {
            GameManager gm = GameManager.get(sp.server);
            if (gm.inRound(sp) && gm.inventorySandboxed(sp.getUUID())) {
                ItemStack rest = event.getEntity().getItem().copy();
                sp.getInventory().add(rest);
                if (rest.isEmpty()) event.setCanceled(true);
                else event.getEntity().setItem(rest);
            }
        }
    }

    @SubscribeEvent
    public static void onStopping(ServerStoppingEvent event) {
        GameManager.get(event.getServer()).onServerStopping();
    }

    @SubscribeEvent
    public static void onStopped(ServerStoppedEvent event) {
        GameManager.forget();
    }
}
