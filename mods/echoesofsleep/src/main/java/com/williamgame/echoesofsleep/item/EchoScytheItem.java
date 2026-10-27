package com.williamgame.echoesofsleep.item;

import com.williamgame.echoesofsleep.distortion.ServerScheduler;
import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.SwordItem;
import net.minecraft.world.item.Tier;
import net.minecraft.world.item.TooltipFlag;

import java.util.List;

/** Echo Scythe: every hit is repeated one second later by a ghost of the slash. */
public class EchoScytheItem extends SwordItem {
    public EchoScytheItem(Tier tier, Properties props) {
        super(tier, props);
    }

    @Override
    public boolean hurtEnemy(ItemStack stack, LivingEntity target, LivingEntity attacker) {
        if (attacker instanceof Player player && target.level() instanceof ServerLevel sl) {
            float damage = (float) player.getAttributeValue(Attributes.ATTACK_DAMAGE) * 0.8F;
            ServerScheduler.schedule(sl, 20, level -> {
                if (!target.isAlive() || target.level() != level || !player.isAlive() || player.distanceToSqr(target) > 12 * 12) return;
                target.invulnerableTime = 0;
                target.hurt(level.damageSources().playerAttack(player), damage);
                level.sendParticles(ParticleTypes.SWEEP_ATTACK, target.getX(), target.getY() + target.getBbHeight() * 0.5, target.getZ(), 2, 0.2, 0.2, 0.2, 0.0);
                level.sendParticles(ParticleTypes.SOUL, target.getX(), target.getY() + target.getBbHeight() * 0.5, target.getZ(), 10, 0.3, 0.4, 0.3, 0.03);
                level.playSound(null, target.getX(), target.getY(), target.getZ(), ModSounds.GHOST_SLASH.get(), SoundSource.PLAYERS, 1.0F, 0.9F + level.random.nextFloat() * 0.2F);
            });
        }
        return super.hurtEnemy(stack, target, attacker);
    }

    @Override
    public void appendHoverText(ItemStack stack, TooltipContext context, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("item.echoesofsleep.echo_scythe.desc").withStyle(ChatFormatting.AQUA, ChatFormatting.ITALIC));
    }
}
