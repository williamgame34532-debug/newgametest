package com.zone19.scp.item;

import net.minecraft.ChatFormatting;
import net.minecraft.client.model.HumanoidModel;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.BlockParticleOption;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.entity.projectile.ProjectileUtil;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.TooltipFlag;
import net.minecraft.world.item.UseAnim;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.EntityHitResult;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.client.extensions.common.IClientItemExtensions;
import org.jetbrains.annotations.Nullable;

import java.util.List;
import java.util.function.Consumer;
import java.util.function.Supplier;

/**
 * Hitscan firearm. The magazine lives in the stack's NBT, reserve rounds are ordinary
 * ammo items in the inventory. Sneak + use reloads by hand, an empty gun reloads itself.
 */
public class GunItem extends Item {
    private static final String TAG_AMMO = "Ammo";

    public static final class Stats {
        float damage = 5;
        int pellets = 1;
        int fireDelay = 5;
        boolean automatic;
        int magazine = 12;
        double spread = 0.02;
        float recoil = 2;
        int reload = 40;
        double range = 64;
        float volume = 1.0F;
        float pitch = 1.0F;
        Supplier<? extends Item> ammo;
        Supplier<SoundEvent> sound;

        public Stats damage(float v) { damage = v; return this; }
        public Stats pellets(int v) { pellets = v; return this; }
        public Stats fireDelay(int v) { fireDelay = v; return this; }
        public Stats automatic() { automatic = true; return this; }
        public Stats magazine(int v) { magazine = v; return this; }
        public Stats spread(double v) { spread = v; return this; }
        public Stats recoil(float v) { recoil = v; return this; }
        public Stats reload(int v) { reload = v; return this; }
        public Stats range(double v) { range = v; return this; }
        public Stats volume(float v) { volume = v; return this; }
        public Stats pitch(float v) { pitch = v; return this; }
        public Stats ammo(Supplier<? extends Item> v) { ammo = v; return this; }
        public Stats sound(Supplier<SoundEvent> v) { sound = v; return this; }
    }

    private final Stats stats;

    public GunItem(Stats stats) {
        super(new Item.Properties().stacksTo(1));
        this.stats = stats;
    }

    public static int getAmmo(ItemStack stack) {
        return stack.getOrCreateTag().getInt(TAG_AMMO);
    }

    private static void setAmmo(ItemStack stack, int ammo) {
        stack.getOrCreateTag().putInt(TAG_AMMO, ammo);
    }

    public int magazineSize() {
        return stats.magazine;
    }

    public Item ammoItem() {
        return stats.ammo.get();
    }

    public static int countReserve(Player player, Item ammo) {
        int n = 0;
        for (ItemStack s : player.getInventory().items) {
            if (s.is(ammo)) n += s.getCount();
        }
        return n;
    }

    @Override
    public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        if (player.isShiftKeyDown()) {
            if (!level.isClientSide) reload(level, player, stack);
            return InteractionResultHolder.consume(stack);
        }
        if (player.getCooldowns().isOnCooldown(this)) {
            return InteractionResultHolder.fail(stack);
        }
        if (stats.automatic) {
            player.startUsingItem(hand);
        }
        fire(level, player, stack);
        return InteractionResultHolder.consume(stack);
    }

    @Override
    public void onUseTick(Level level, LivingEntity entity, ItemStack stack, int remaining) {
        if (!(entity instanceof Player player)) return;
        int held = getUseDuration(stack) - remaining;
        if (held > 0 && held % stats.fireDelay == 0 && !player.getCooldowns().isOnCooldown(this)) {
            fire(level, player, stack);
        }
    }

    @Override
    public int getUseDuration(ItemStack stack) {
        return 72000;
    }

    @Override
    public UseAnim getUseAnimation(ItemStack stack) {
        return UseAnim.NONE;
    }

    private void fire(Level level, Player player, ItemStack stack) {
        int ammo = getAmmo(stack);
        if (ammo <= 0) {
            player.stopUsingItem();
            if (!level.isClientSide && !reload(level, player, stack)) {
                level.playSound(null, player.getX(), player.getY(), player.getZ(), SoundEvents.DISPENSER_FAIL,
                        SoundSource.PLAYERS, 0.6F, 1.6F);
                player.getCooldowns().addCooldown(this, 10);
            }
            return;
        }
        if (level.isClientSide) {
            player.setXRot(player.getXRot() - stats.recoil * (0.7F + player.getRandom().nextFloat() * 0.6F));
            player.setYRot(player.getYRot() + (player.getRandom().nextFloat() - 0.5F) * stats.recoil * 0.4F);
            return;
        }
        setAmmo(stack, ammo - 1);
        ServerLevel server = (ServerLevel) level;
        for (int i = 0; i < stats.pellets; i++) {
            shoot(server, player);
        }
        Vec3 muzzle = player.getEyePosition().add(player.getViewVector(1.0F).scale(1.2)).add(0, -0.15, 0);
        server.sendParticles(ParticleTypes.SMOKE, muzzle.x, muzzle.y, muzzle.z, 2, 0.02, 0.02, 0.02, 0.01);
        server.sendParticles(ParticleTypes.SMALL_FLAME, muzzle.x, muzzle.y, muzzle.z, 1, 0.0, 0.0, 0.0, 0.0);
        level.playSound(null, player.getX(), player.getY(), player.getZ(), stats.sound.get(), SoundSource.PLAYERS,
                stats.volume * 1.5F, stats.pitch * (0.95F + player.getRandom().nextFloat() * 0.1F));
        if (!stats.automatic) {
            player.getCooldowns().addCooldown(this, stats.fireDelay);
        }
    }

    private void shoot(ServerLevel level, Player player) {
        Vec3 eye = player.getEyePosition();
        Vec3 dir = player.getViewVector(1.0F).add(
                player.getRandom().nextGaussian() * stats.spread,
                player.getRandom().nextGaussian() * stats.spread,
                player.getRandom().nextGaussian() * stats.spread).normalize();
        Vec3 end = eye.add(dir.scale(stats.range));
        BlockHitResult blockHit = level.clip(new ClipContext(eye, end, ClipContext.Block.COLLIDER, ClipContext.Fluid.NONE, player));
        Vec3 stop = blockHit.getType() == HitResult.Type.MISS ? end : blockHit.getLocation();
        AABB sweep = player.getBoundingBox().expandTowards(dir.scale(stats.range)).inflate(1.0);
        EntityHitResult entityHit = ProjectileUtil.getEntityHitResult(level, player, eye, stop, sweep,
                e -> !e.isSpectator() && e.isPickable() && e != player);

        if (entityHit != null) {
            stop = entityHit.getLocation();
            Entity target = entityHit.getEntity();
            float dmg = stats.damage;
            if (target instanceof LivingEntity living && stop.y > living.getEyeY() - 0.25) {
                dmg *= 1.5F;
            }
            target.invulnerableTime = 0;
            target.hurt(level.damageSources().playerAttack(player), dmg);
            level.sendParticles(ParticleTypes.DAMAGE_INDICATOR, stop.x, stop.y, stop.z, 2, 0.1, 0.1, 0.1, 0.1);
        } else if (blockHit.getType() == HitResult.Type.BLOCK) {
            BlockPos pos = blockHit.getBlockPos();
            BlockState state = level.getBlockState(pos);
            level.sendParticles(new BlockParticleOption(ParticleTypes.BLOCK, state), stop.x, stop.y, stop.z, 6, 0.05, 0.05, 0.05, 0.1);
            level.sendParticles(ParticleTypes.SMOKE, stop.x, stop.y, stop.z, 1, 0.0, 0.0, 0.0, 0.01);
        }

        double len = stop.distanceTo(eye);
        for (double t = 2.0; t < Math.min(len, 40.0); t += 2.5) {
            Vec3 p = eye.add(dir.scale(t));
            level.sendParticles(ParticleTypes.CRIT, p.x, p.y - 0.1, p.z, 1, 0.0, 0.0, 0.0, 0.0);
        }
    }

    private boolean reload(Level level, Player player, ItemStack stack) {
        int ammo = getAmmo(stack);
        int need = stats.magazine - ammo;
        if (need <= 0) return false;
        int taken = 0;
        if (player.getAbilities().instabuild) {
            taken = need;
        } else {
            Item ammoItem = stats.ammo.get();
            for (ItemStack s : player.getInventory().items) {
                if (taken >= need) break;
                if (s.is(ammoItem)) {
                    int t = Math.min(s.getCount(), need - taken);
                    s.shrink(t);
                    taken += t;
                }
            }
        }
        if (taken <= 0) {
            player.displayClientMessage(Component.translatable("message.scpzone19.no_ammo").withStyle(ChatFormatting.RED), true);
            return false;
        }
        setAmmo(stack, ammo + taken);
        player.stopUsingItem();
        player.getCooldowns().addCooldown(this, stats.reload);
        level.playSound(null, player.getX(), player.getY(), player.getZ(), SoundEvents.CROSSBOW_LOADING_END,
                SoundSource.PLAYERS, 0.8F, 1.3F);
        return true;
    }

    @Override
    public boolean isBarVisible(ItemStack stack) {
        return true;
    }

    @Override
    public int getBarWidth(ItemStack stack) {
        return Math.round(13.0F * getAmmo(stack) / stats.magazine);
    }

    @Override
    public int getBarColor(ItemStack stack) {
        return Mth.hsvToRgb(0.12F * getAmmo(stack) / stats.magazine, 0.8F, 1.0F);
    }

    @Override
    public boolean shouldCauseReequipAnimation(ItemStack oldStack, ItemStack newStack, boolean slotChanged) {
        return slotChanged || !oldStack.is(newStack.getItem());
    }

    @Override
    public void appendHoverText(ItemStack stack, @Nullable Level world, List<Component> tooltip, TooltipFlag flag) {
        tooltip.add(Component.translatable("tooltip.scpzone19.magazine", getAmmo(stack), stats.magazine).withStyle(ChatFormatting.GRAY));
        tooltip.add(Component.translatable("tooltip.scpzone19.caliber", Component.translatable(stats.ammo.get().getDescriptionId()))
                .withStyle(ChatFormatting.DARK_GRAY));
        tooltip.add(Component.translatable(stats.automatic ? "tooltip.scpzone19.auto" : "tooltip.scpzone19.semi")
                .withStyle(ChatFormatting.DARK_GRAY));
        tooltip.add(Component.translatable("tooltip.scpzone19.reload_hint").withStyle(ChatFormatting.DARK_GRAY));
    }

    @Override
    public void initializeClient(Consumer<IClientItemExtensions> consumer) {
        consumer.accept(new IClientItemExtensions() {
            @Override
            public HumanoidModel.ArmPose getArmPose(LivingEntity entity, InteractionHand hand, ItemStack stack) {
                return HumanoidModel.ArmPose.CROSSBOW_HOLD;
            }
        });
    }
}
