package com.williamgame.echoesofsleep.event;

import com.williamgame.echoesofsleep.distortion.DistortionData;
import com.williamgame.echoesofsleep.entity.NightmareMonster;
import com.williamgame.echoesofsleep.item.ArmorSet;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.event.entity.living.LivingDeathEvent;
import net.minecraftforge.event.entity.living.LivingEvent;
import net.minecraftforge.event.entity.living.LivingHurtEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;

/** Full-set bonuses of the three dream armors. */
public final class GearEvents {
    private static final String DASH_KEY = "echoesofsleep_dash";

    private GearEvents() {
    }

    @SubscribeEvent
    public static void onPlayerTick(TickEvent.PlayerTickEvent.Post event) {
        if (!(event.player instanceof ServerPlayer sp) || sp.tickCount % 20 != 0) return;
        if (ArmorSet.DREAMCATCHER.isWornBy(sp)) {
            ServerLevel sl = sp.serverLevel();
            if (DistortionData.get(sl).isActive()) {
                sp.addEffect(new MobEffectInstance(MobEffects.NIGHT_VISION, 260, 0, true, false, true));
            }
            // only the nightmares that are hunting the wearer light up (Glowing is visible to everyone, so keep it tight)
            for (NightmareMonster m : sl.getEntitiesOfClass(NightmareMonster.class, new AABB(sp.blockPosition()).inflate(16),
                    n -> n.getTarget() == sp)) {
                m.addEffect(new MobEffectInstance(MobEffects.GLOWING, 25, 0, true, false));
            }
        }
    }

    private static boolean isNightmareSource(Entity e) {
        return e instanceof NightmareMonster;
    }

    @SubscribeEvent
    public static void onHurt(LivingHurtEvent event) {
        if (!(event.getEntity() instanceof ServerPlayer sp)) return;
        if (ArmorSet.WAKEFUL.isWornBy(sp) && (isNightmareSource(event.getSource().getEntity()) || isNightmareSource(event.getSource().getDirectEntity()))) {
            event.setAmount(event.getAmount() * 0.7F);
        }
    }

    @SubscribeEvent
    public static void onKill(LivingDeathEvent event) {
        if (event.getEntity() instanceof NightmareMonster && event.getSource().getEntity() instanceof ServerPlayer sp
                && ArmorSet.NIGHTMARE_EATER.isWornBy(sp)) {
            boolean boss = ((NightmareMonster) event.getEntity()).isBoss();
            sp.heal(boss ? 20.0F : 6.0F);
            sp.addEffect(new MobEffectInstance(MobEffects.ABSORPTION, 300, boss ? 3 : 0));
            sp.serverLevel().sendParticles(ParticleTypes.SOUL, event.getEntity().getX(), event.getEntity().getY() + 1, event.getEntity().getZ(),
                    16, 0.4, 0.6, 0.4, 0.05);
            sp.serverLevel().playSound(null, sp.getX(), sp.getY(), sp.getZ(), SoundEvents.SOUL_ESCAPE.value(), SoundSource.PLAYERS, 1.0F, 0.8F);
        }
    }

    /** Nightmare Eater: sneak + jump to dash forward (2 s cooldown). */
    @SubscribeEvent
    public static void onJump(LivingEvent.LivingJumpEvent event) {
        if (!(event.getEntity() instanceof ServerPlayer sp) || !sp.isShiftKeyDown() || !ArmorSet.NIGHTMARE_EATER.isWornBy(sp)) return;
        long now = sp.level().getGameTime();
        long ready = sp.getPersistentData().getLong(DASH_KEY);
        if (now < ready) return;
        sp.getPersistentData().putLong(DASH_KEY, now + 40);
        Vec3 look = sp.getLookAngle().multiply(1, 0, 1).normalize();
        sp.setDeltaMovement(look.x * 1.7, 0.42, look.z * 1.7);
        sp.hurtMarked = true;
        sp.resetFallDistance();
        sp.serverLevel().sendParticles(ParticleTypes.SQUID_INK, sp.getX(), sp.getY() + 0.6, sp.getZ(), 14, 0.3, 0.4, 0.3, 0.02);
        sp.serverLevel().playSound(null, sp.getX(), sp.getY(), sp.getZ(), SoundEvents.PLAYER_ATTACK_SWEEP, SoundSource.PLAYERS, 0.8F, 0.6F);
    }
}
