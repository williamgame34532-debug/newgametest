package com.williamgame.echoesofsleep.event;

import com.williamgame.echoesofsleep.entity.NightmareMonster;
import com.williamgame.echoesofsleep.memory.PlayerMemory;
import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.monster.Enemy;
import net.minecraft.world.entity.npc.AbstractVillager;
import net.minecraft.world.level.LightLayer;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.event.entity.living.LivingDeathEvent;
import net.minecraftforge.event.entity.living.LivingHurtEvent;
import net.minecraftforge.event.entity.player.PlayerEvent;
import net.minecraftforge.event.level.BlockEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;

/** Records the player's "Trace": kills, deaths, blocks, darkness, harmed villagers and the walked path. */
public final class CommonEvents {
    private CommonEvents() {
    }

    @SubscribeEvent
    public static void onClone(PlayerEvent.Clone event) {
        PlayerMemory.copy(event.getOriginal(), event.getEntity());
    }

    @SubscribeEvent
    public static void onDeath(LivingDeathEvent event) {
        LivingEntity victim = event.getEntity();
        if (victim.level().isClientSide) return;
        if (victim instanceof ServerPlayer sp) {
            PlayerMemory mem = PlayerMemory.of(sp);
            mem.recordDeath(sp.blockPosition(), sp.level().dimension().location().toString());
            mem.addDread(6.0F);
            return;
        }
        if (event.getSource().getEntity() instanceof ServerPlayer killer && !(victim instanceof NightmareMonster)) {
            PlayerMemory mem = PlayerMemory.of(killer);
            boolean hostile = victim instanceof Enemy;
            mem.recordKill(EntityType.getKey(victim.getType()).toString(), hostile);
            if (victim instanceof AbstractVillager) {
                mem.addDread(5.0F);
                mem.addVillagerHurt();
            } else {
                mem.addDread(hostile ? 0.15F : 0.6F);
            }
        }
    }

    @SubscribeEvent
    public static void onHurt(LivingHurtEvent event) {
        if (event.getEntity().level().isClientSide) return;
        if (event.getEntity() instanceof AbstractVillager && event.getSource().getEntity() instanceof ServerPlayer sp) {
            PlayerMemory mem = PlayerMemory.of(sp);
            mem.addVillagerHurt();
            mem.addDread(2.0F);
        }
    }

    @SubscribeEvent
    public static void onPlace(BlockEvent.EntityPlaceEvent event) {
        if (event.getEntity() instanceof ServerPlayer sp) PlayerMemory.of(sp).addPlaced();
    }

    @SubscribeEvent
    public static void onBreak(BlockEvent.BreakEvent event) {
        if (event.getPlayer() instanceof ServerPlayer sp) PlayerMemory.of(sp).addBroken();
    }

    @SubscribeEvent
    public static void onPlayerTick(TickEvent.PlayerTickEvent.Post event) {
        if (!(event.player instanceof ServerPlayer sp) || sp.isSpectator()) return;
        int t = sp.tickCount;
        if (t % 40 == 0 && sp.onGround()) {
            PlayerMemory.of(sp).recordPathPoint(sp.blockPosition(), sp.level().dimension().location().toString());
        }
        if (t % 20 == 0) {
            PlayerMemory mem = PlayerMemory.of(sp);
            BlockPos pos = sp.blockPosition();
            boolean sky = sp.level().canSeeSky(pos);
            boolean underground = !sky && pos.getY() < 50;
            int light = sp.level().getBrightness(LightLayer.BLOCK, pos);
            boolean dark = sp.level().getMaxLocalRawBrightness(pos) < 5 && light < 5;
            if (underground) mem.addUnderground(1);
            if (dark) {
                mem.addDarkness(1);
                mem.addDread(underground ? 0.03F : 0.015F);
            }
            // sunlight slowly heals the mind
            if (sky && sp.level().isDay() && !sp.level().isRaining()) {
                mem.addDread(-0.04F);
            }
        }
    }
}
