package com.zone19.scp.item;

import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.SwordItem;
import net.minecraft.world.item.Tiers;

/** Standard issue baton: modest damage, but the shock leaves the target sluggish. */
public class StunBatonItem extends SwordItem {
    public StunBatonItem() {
        super(Tiers.IRON, 2, -2.2F, new Properties().stacksTo(1).durability(600));
    }

    @Override
    public boolean hurtEnemy(ItemStack stack, LivingEntity target, LivingEntity attacker) {
        target.addEffect(new MobEffectInstance(MobEffects.MOVEMENT_SLOWDOWN, 50, 3));
        target.addEffect(new MobEffectInstance(MobEffects.WEAKNESS, 50, 1));
        if (target.level() instanceof ServerLevel level) {
            level.sendParticles(ParticleTypes.ELECTRIC_SPARK, target.getX(), target.getY(0.6), target.getZ(), 12, 0.3, 0.4, 0.3, 0.2);
            level.playSound(null, target.blockPosition(), SoundEvents.BEE_STING, SoundSource.PLAYERS, 0.8F, 1.8F);
        }
        return super.hurtEnemy(stack, target, attacker);
    }
}
