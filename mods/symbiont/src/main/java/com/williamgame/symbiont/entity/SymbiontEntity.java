package com.williamgame.symbiont.entity;

import com.williamgame.symbiont.Form;
import com.williamgame.symbiont.Symbiont;
import com.williamgame.symbiont.SymbiontData;
import com.williamgame.symbiont.SymbiontManager;
import net.minecraft.core.component.DataComponents;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.damagesource.DamageTypes;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityDimensions;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.PathfinderMob;
import net.minecraft.world.entity.Pose;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.goal.FloatGoal;
import net.minecraft.world.entity.ai.goal.Goal;
import net.minecraft.world.entity.ai.goal.LookAtPlayerGoal;
import net.minecraft.world.entity.ai.goal.MeleeAttackGoal;
import net.minecraft.world.entity.ai.goal.RandomLookAroundGoal;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.Vec3;

import java.util.EnumSet;
import java.util.Optional;
import java.util.UUID;

/**
 * The companion creature. It is never saved to the world (see {@link #shouldBeSaved()}): the
 * authoritative state lives in the owner's {@link SymbiontData}, and {@link SymbiontManager}
 * (re)summons the entity next to its owner whenever needed.
 */
public class SymbiontEntity extends PathfinderMob {
    private static final EntityDataAccessor<Integer> FORM = SynchedEntityData.defineId(SymbiontEntity.class, EntityDataSerializers.INT);
    /** 0 = content, 1 = happy, 2 = sad (hungry / low bond), 3 = weak (about to leave). */
    private static final EntityDataAccessor<Integer> MOOD = SynchedEntityData.defineId(SymbiontEntity.class, EntityDataSerializers.INT);
    private static final EntityDataAccessor<Optional<UUID>> OWNER = SynchedEntityData.defineId(SymbiontEntity.class, EntityDataSerializers.OPTIONAL_UUID);
    private static final EntityDataAccessor<Boolean> HAPPY = SynchedEntityData.defineId(SymbiontEntity.class, EntityDataSerializers.BOOLEAN);

    public static final int MOOD_CONTENT = 0;
    public static final int MOOD_HAPPY = 1;
    public static final int MOOD_SAD = 2;
    public static final int MOOD_WEAK = 3;

    private int happyTicks;
    private boolean deathHandled;
    /** Game time until which the "teleport to owner" rule is relaxed (after respawning at the nest). */
    public long nestGraceUntil;
    /** Client-only: when true this instance is a GUI preview dummy and never ticks in a world. */
    public boolean previewOnly;

    public SymbiontEntity(EntityType<? extends PathfinderMob> type, Level level) {
        super(type, level);
        this.xpReward = 0;
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Mob.createMobAttributes()
                .add(Attributes.MAX_HEALTH, 14.0)
                .add(Attributes.MOVEMENT_SPEED, 0.28)
                .add(Attributes.ATTACK_DAMAGE, 1.0)
                .add(Attributes.FOLLOW_RANGE, 32.0)
                .add(Attributes.FLYING_SPEED, 0.5);
    }

    @Override
    protected void defineSynchedData(SynchedEntityData.Builder builder) {
        super.defineSynchedData(builder);
        builder.define(FORM, 0);
        builder.define(MOOD, 0);
        builder.define(OWNER, Optional.empty());
        builder.define(HAPPY, false);
    }

    @Override
    protected void registerGoals() {
        goalSelector.addGoal(0, new FloatGoal(this));
        goalSelector.addGoal(1, new FightGoal(this));
        goalSelector.addGoal(2, new FollowOwnerGoal(this));
        goalSelector.addGoal(4, new LookAtPlayerGoal(this, Player.class, 8.0F));
        goalSelector.addGoal(5, new RandomLookAroundGoal(this));
    }

    // ------------------------------------------------------------------ state accessors
    public Form getForm() {
        if (entityData == null) return Form.HATCHLING;
        return Form.byOrdinal(entityData.get(FORM));
    }

    public int getMood() {
        return entityData.get(MOOD);
    }

    public void setMood(int mood) {
        if (getMood() != mood) {
            entityData.set(MOOD, mood);
            updateSpeed();
        }
    }

    public boolean isHappy() {
        return entityData.get(HAPPY);
    }

    public void makeHappy(int ticks) {
        happyTicks = Math.max(happyTicks, ticks);
        entityData.set(HAPPY, true);
    }

    public UUID getOwnerUUID() {
        return entityData.get(OWNER).orElse(null);
    }

    public void setOwnerUUID(UUID id) {
        entityData.set(OWNER, Optional.ofNullable(id));
    }

    public boolean isOwnedBy(Entity e) {
        UUID id = getOwnerUUID();
        return e != null && id != null && id.equals(e.getUUID());
    }

    public ServerPlayer getOwnerPlayer() {
        UUID id = getOwnerUUID();
        MinecraftServer server = level().getServer();
        if (id == null || server == null) return null;
        return server.getPlayerList().getPlayer(id);
    }

    public boolean isFlyingNow() {
        return getForm().flying && !onGround();
    }

    /** Client-side preview helper: set the form without touching attributes. */
    public void setFormClient(Form form) {
        entityData.set(FORM, form.ordinal());
        refreshDimensions();
    }

    /** Server side: switch to a form and update attributes. */
    public void applyForm(Form form, boolean heal) {
        entityData.set(FORM, form.ordinal());
        setBase(Attributes.MAX_HEALTH, form.maxHealth);
        setBase(Attributes.ATTACK_DAMAGE, form.damage);
        setBase(Attributes.FLYING_SPEED, form.speed * 1.6);
        updateSpeed();
        setNoGravity(form.flying);
        refreshDimensions();
        if (heal || getHealth() > getMaxHealth()) {
            setHealth(getMaxHealth());
        }
    }

    private void updateSpeed() {
        double s = getForm().speed;
        if (getMood() == MOOD_WEAK) s *= 0.6;
        setBase(Attributes.MOVEMENT_SPEED, s);
    }

    private void setBase(net.minecraft.core.Holder<net.minecraft.world.entity.ai.attributes.Attribute> attr, double v) {
        AttributeInstance inst = getAttribute(attr);
        if (inst != null) inst.setBaseValue(v);
    }

    /** Warriors fight; every form defends itself a little except while weak. */
    public boolean canFight() {
        Form f = getForm();
        return f.branch == com.williamgame.symbiont.Branch.WARRIOR && getMood() != MOOD_WEAK;
    }

    // ------------------------------------------------------------------ lifecycle
    @Override
    public boolean shouldBeSaved() {
        return false; // the owner's data is the source of truth; the entity is re-summoned on demand
    }

    @Override
    public boolean removeWhenFarAway(double distance) {
        return false;
    }

    @Override
    public void checkDespawn() {
    }

    @Override
    public boolean canBeLeashed() {
        return false;
    }

    @Override
    protected boolean shouldDropLoot() {
        return false;
    }

    @Override
    public boolean shouldDropExperience() {
        return false;
    }

    @Override
    protected EntityDimensions getDefaultDimensions(Pose pose) {
        Form f = getForm();
        return EntityDimensions.scalable(f.width, f.height);
    }

    @Override
    public void onSyncedDataUpdated(EntityDataAccessor<?> key) {
        super.onSyncedDataUpdated(key);
        if (FORM.equals(key)) {
            refreshDimensions();
        }
    }

    @Override
    public void tick() {
        super.tick();
        if (level().isClientSide) {
            clientEffects();
            return;
        }
        if (isRemoved()) return;
        ServerPlayer owner = getOwnerPlayer();
        if (owner == null || owner.level() != level()) {
            discard();
            return;
        }
        SymbiontData data = SymbiontData.of(owner);
        if (data.state() != SymbiontData.STATE_ALIVE || !getUUID().equals(data.entityUuid())) {
            discard(); // stale duplicate (old dimension, reload, ...)
            return;
        }
        if (happyTicks > 0 && --happyTicks == 0) {
            entityData.set(HAPPY, false);
        }
        if (getTarget() != null && (!getTarget().isAlive() || getTarget().distanceToSqr(owner) > 24 * 24)) {
            setTarget(null);
        }
    }

    private void clientEffects() {
        int mood = getMood();
        if (mood == MOOD_WEAK && random.nextInt(12) == 0) {
            level().addParticle(ParticleTypes.FALLING_WATER, getRandomX(0.4), getY() + getBbHeight() * 0.8, getRandomZ(0.4), 0, 0, 0);
        } else if (mood == MOOD_SAD && random.nextInt(40) == 0) {
            level().addParticle(ParticleTypes.FALLING_WATER, getRandomX(0.3), getY() + getBbHeight() * 0.8, getRandomZ(0.3), 0, 0, 0);
        }
        if (isHappy() && random.nextInt(8) == 0) {
            level().addParticle(ParticleTypes.HEART, getRandomX(0.6), getY() + getBbHeight() + 0.2, getRandomZ(0.6), 0, 0.05, 0);
        }
        Form f = getForm();
        if (f.branch != null && f.stage == 3 && random.nextInt(10) == 0) {
            level().addParticle(f.branch == com.williamgame.symbiont.Branch.FARMER ? ParticleTypes.HAPPY_VILLAGER
                            : f.branch == com.williamgame.symbiont.Branch.EXPLORER ? ParticleTypes.END_ROD
                            : f.branch == com.williamgame.symbiont.Branch.WARRIOR ? ParticleTypes.CRIT : ParticleTypes.WAX_ON,
                    getRandomX(0.8), getRandomY(), getRandomZ(0.8), 0, 0.02, 0);
        }
    }

    @Override
    protected void customServerAiStep() {
        super.customServerAiStep();
        Form form = getForm();
        ServerPlayer owner = getOwnerPlayer();
        if (form.flying) {
            if (!isNoGravity()) setNoGravity(true);
            if (owner != null) hoverNear(owner);
        } else {
            if (isNoGravity()) setNoGravity(false);
            // Explorer hatchlings glide instead of falling
            if (form == Form.EXPLORER_1 && !onGround()) {
                Vec3 v = getDeltaMovement();
                if (v.y < -0.1) setDeltaMovement(v.x, -0.1, v.z);
                fallDistance = 0;
            }
        }
    }

    private void hoverNear(ServerPlayer owner) {
        getNavigation().stop();
        float yaw = owner.getYRot() * Mth.DEG_TO_RAD;
        double fx = -Mth.sin(yaw), fz = Mth.cos(yaw);
        double rx = -Mth.cos(yaw), rz = -Mth.sin(yaw);
        double t = tickCount * 0.05;
        double side = (getId() % 2 == 0) ? 1.3 : -1.3;
        Vec3 target = owner.position().add(-fx * 2.0 + rx * side + Math.sin(t) * 0.6,
                owner.getBbHeight() + 0.5 + Math.sin(t * 1.7) * 0.35,
                -fz * 2.0 + rz * side + Math.cos(t * 0.8) * 0.6);
        LivingEntity carryTarget = owner;
        if (SymbiontManager.isCarrying(owner)) {
            target = owner.position().add(0, owner.getBbHeight() + 0.3, 0);
        }
        Vec3 diff = target.subtract(position());
        double dist = diff.length();
        Vec3 vel = getDeltaMovement().scale(0.55).add(diff.scale(dist > 6 ? 0.14 : 0.07));
        double max = 1.4;
        if (vel.length() > max) vel = vel.normalize().scale(max);
        setDeltaMovement(vel);
        float wantYaw;
        if (dist > 1.5 && vel.horizontalDistanceSqr() > 0.004) {
            wantYaw = (float) (Mth.atan2(vel.z, vel.x) * Mth.RAD_TO_DEG) - 90.0F;
        } else {
            wantYaw = carryTarget.getYRot();
        }
        setYRot(Mth.rotLerp(0.25F, getYRot(), wantYaw));
        yBodyRot = getYRot();
        fallDistance = 0;
    }

    // ------------------------------------------------------------------ interaction / combat
    @Override
    protected InteractionResult mobInteract(Player player, InteractionHand hand) {
        ItemStack stack = player.getItemInHand(hand);
        boolean food = stack.is(Symbiont.TREAT.get()) || stack.has(DataComponents.FOOD);
        boolean pet = player.isShiftKeyDown() && stack.isEmpty();
        if (!food && !pet) return super.mobInteract(player, hand);
        if (!isOwnedBy(player)) {
            if (!level().isClientSide) {
                player.displayClientMessage(net.minecraft.network.chat.Component.translatable("symbiont.msg.not_yours", getName()), true);
            }
            return InteractionResult.sidedSuccess(level().isClientSide);
        }
        if (level().isClientSide) return InteractionResult.SUCCESS;
        if (player instanceof ServerPlayer sp) {
            if (food) {
                SymbiontManager.feed(sp, this, stack, hand);
            } else {
                SymbiontManager.pet(sp, this);
            }
        }
        return InteractionResult.CONSUME;
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        if (source.is(DamageTypes.IN_WALL) || source.is(DamageTypes.FALL) || source.is(DamageTypes.CRAMMING)
                || source.is(DamageTypes.FLY_INTO_WALL) || source.is(DamageTypes.DROWN)) {
            return false;
        }
        Entity attacker = source.getEntity();
        if (attacker instanceof Player || attacker instanceof SymbiontEntity) {
            return false; // neither its owner nor other players/companions can hurt it
        }
        return super.hurt(source, amount);
    }

    @Override
    public void die(DamageSource source) {
        super.die(source);
        if (!level().isClientSide && !deathHandled) {
            deathHandled = true;
            ServerPlayer owner = getOwnerPlayer();
            if (owner != null) SymbiontManager.onCompanionDied(owner, this);
        }
    }

    @Override
    public boolean canAttack(LivingEntity target) {
        if (target instanceof Player || target instanceof SymbiontEntity) return false;
        return super.canAttack(target);
    }

    @Override
    public boolean isAlliedTo(Entity other) {
        if (isOwnedBy(other) || other instanceof SymbiontEntity) return true;
        return super.isAlliedTo(other);
    }

    @Override
    public boolean causeFallDamage(float distance, float multiplier, DamageSource source) {
        return false;
    }

    // ------------------------------------------------------------------ sounds
    @Override
    protected SoundEvent getAmbientSound() {
        return getMood() >= MOOD_SAD ? Symbiont.SOUND_SAD.get() : Symbiont.SOUND_CHIRP.get();
    }

    @Override
    protected SoundEvent getHurtSound(DamageSource source) {
        return Symbiont.SOUND_HURT.get();
    }

    @Override
    protected SoundEvent getDeathSound() {
        return Symbiont.SOUND_DEATH.get();
    }

    @Override
    public int getAmbientSoundInterval() {
        return 240;
    }

    @Override
    protected float getSoundVolume() {
        return 0.6F;
    }

    @Override
    public float getVoicePitch() {
        float base = switch (getForm().stage) {
            case 0 -> 1.45F;
            case 1 -> 1.2F;
            case 2 -> 1.0F;
            default -> 0.8F;
        };
        return base + (random.nextFloat() - 0.5F) * 0.15F;
    }

    // ------------------------------------------------------------------ goals
    static class FightGoal extends MeleeAttackGoal {
        private final SymbiontEntity sym;

        FightGoal(SymbiontEntity sym) {
            super(sym, 1.35, true);
            this.sym = sym;
        }

        @Override
        public boolean canUse() {
            return sym.canFight() && super.canUse();
        }

        @Override
        public boolean canContinueToUse() {
            return sym.canFight() && super.canContinueToUse();
        }
    }

    static class FollowOwnerGoal extends Goal {
        private final SymbiontEntity sym;
        private ServerPlayer owner;
        private int repath;

        FollowOwnerGoal(SymbiontEntity sym) {
            this.sym = sym;
            setFlags(EnumSet.of(Goal.Flag.MOVE, Goal.Flag.LOOK));
        }

        @Override
        public boolean canUse() {
            if (sym.getForm().flying) return false;
            ServerPlayer o = sym.getOwnerPlayer();
            if (o == null || o.isSpectator() || !o.isAlive()) return false;
            if (sym.distanceToSqr(o) < 3.5 * 3.5) return false;
            owner = o;
            return true;
        }

        @Override
        public boolean canContinueToUse() {
            return owner != null && owner.isAlive() && !sym.getForm().flying && sym.distanceToSqr(owner) > 2.2 * 2.2;
        }

        @Override
        public void start() {
            repath = 0;
        }

        @Override
        public void stop() {
            owner = null;
            sym.getNavigation().stop();
        }

        @Override
        public void tick() {
            if (owner == null) return;
            sym.getLookControl().setLookAt(owner, 10.0F, 40.0F);
            if (--repath <= 0) {
                repath = 10;
                double d = sym.distanceToSqr(owner);
                sym.getNavigation().moveTo(owner, d > 64 ? 1.7 : 1.25);
            }
        }
    }
}
