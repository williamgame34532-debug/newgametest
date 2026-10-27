package com.williamgame.echoesofsleep.item;

import com.williamgame.echoesofsleep.entity.NightmareMonster;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.SwordItem;
import net.minecraft.world.item.Tier;
import net.minecraft.world.item.TooltipFlag;

import java.util.List;

/** Dawn Blade: double damage against nightmares, and the first light blinds them. */
public class DawnBladeItem extends SwordItem {
    public DawnBladeItem(Tier tier, Properties props) {
        super(tier, props);
    }

    @Override
    public float getAttackDamageBonus(Entity target, float baseDamage, DamageSource source) {
        return target instanceof NightmareMonster ? baseDamage : 0.0F;
    }

    @Override
    public boolean hurtEnemy(ItemStack stack, LivingEntity target, LivingEntity attacker) {
        if (target instanceof NightmareMonster && target.level() instanceof ServerLevel sl) {
            target.addEffect(new MobEffectInstance(MobEffects.BLINDNESS, 80, 0), attacker);
            sl.sendParticles(ParticleTypes.END_ROD, target.getX(), target.getY() + target.getBbHeight() * 0.6, target.getZ(),
                    12, 0.3, 0.4, 0.3, 0.08);
        }
        return super.hurtEnemy(stack, target, attacker);
    }

    @Override
    public void appendHoverText(ItemStack stack, TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.echoesofsleep.dawn_blade.desc").withStyle(ChatFormatting.GOLD, ChatFormatting.ITALIC));
    }
}
