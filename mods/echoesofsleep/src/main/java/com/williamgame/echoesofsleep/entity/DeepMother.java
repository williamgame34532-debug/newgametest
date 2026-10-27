package com.williamgame.echoesofsleep.entity;

import com.williamgame.echoesofsleep.Config;
import com.williamgame.echoesofsleep.network.FxPacket;
import com.williamgame.echoesofsleep.network.ModNetwork;
import com.williamgame.echoesofsleep.registry.ModEntities;
import com.williamgame.echoesofsleep.registry.ModSounds;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.BlockParticleOption;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerBossEvent;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.tags.DamageTypeTags;
import net.minecraft.util.Mth;
import net.minecraft.world.BossEvent;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.item.FallingBlockEntity;
import net.minecraft.world.entity.monster.Monster;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.GameRules;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.Vec3;

/**
 * Deep Mother - boss. She lives inside the walls underground. Most of the time only her enormous
 * hands break out of the stone around you; when she surfaces, her emaciated body rises out of the
 * floor. Hurting her hands hurts her. Below half health the cave itself starts to collapse.
 */
public class DeepMother extends NightmareMonster {
    public static final byte SUBMERGED = 0, EMERGING = 1, ACTIVE = 2, SINKING = 3;
    public static final int EMERGE_TICKS = 40, SINK_TICKS = 30;
    public static final byte ATTACK_NONE = 0, ATTACK_SWEEP = 1, ATTACK_SLAM = 2;

    private static final EntityDataAccessor<Byte> DATA_STATE = SynchedEntityData.defineId(DeepMother.class, EntityDataSerializers.BYTE);
    private static final EntityDataAccessor<Integer> DATA_PHASE = SynchedEntityData.defineId(DeepMother.class, EntityDataSerializers.INT);
    private static final EntityDataAccessor<Byte> DATA_ATTACK = SynchedEntityData.defineId(DeepMother.class, EntityDataSerializers.BYTE);

    private final ServerBossEvent bossEvent = new ServerBossEvent(getDisplayName(), BossEvent.BossBarColor.PURPLE, BossEvent.BossBarOverlay.NOTCHED_10);
    private int stateTicks;
    private int attackCooldown = 40;
    private int attackWindup;
    private int handCooldown = 40;
    private int collapseCooldown;
    private boolean handDamage;

    public int clientStateStart;
    public int clientAttackStart;

    public DeepMother(EntityType<? extends Monster> type, Level level) {
        super(type, level);
        this.xpReward = 150;
        setPersistenceRequired();
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Monster.createMonsterAttributes()
                .add(Attributes.MAX_HEALTH, 320.0)
                .add(Attributes.MOVEMENT_SPEED, 0.0)
                .add(Attributes.ATTACK_DAMAGE, 14.0)
                .add(Attributes.FOLLOW_RANGE, 48.0)
                .add(Attributes.ARMOR, 10.0)
                .add(Attributes.ARMOR_TOUGHNESS, 4.0)
                .add(Attributes.KNOCKBACK_RESISTANCE, 1.0);
    }

    @Override
    protected void defineSynchedData(SynchedEntityData.Builder builder) {
        super.defineSynchedData(builder);
        builder.define(DATA_STATE, EMERGING);
        builder.define(DATA_PHASE, 1);
        builder.define(DATA_ATTACK, ATTACK_NONE);
    }

    @Override
    public void onSyncedDataUpdated(EntityDataAccessor<?> key) {
        super.onSyncedDataUpdated(key);
        if (DATA_STATE.equals(key)) clientStateStart = tickCount;
        if (DATA_ATTACK.equals(key)) clientAttackStart = tickCount;
    }

    @Override
    public boolean isBoss() {
        return true;
    }

    public byte getMotherState() {
        return entityData.get(DATA_STATE);
    }

    public int getPhase() {
        return entityData.get(DATA_PHASE);
    }

    public byte getAttack() {
        return entityData.get(DATA_ATTACK);
    }

    private void setMotherState(byte s) {
        entityData.set(DATA_STATE, s);
        stateTicks = 0;
        boolean under = s == SUBMERGED;
        noPhysics = under;
        setNoGravity(under);
        setInvisible(under);
        if (s == EMERGING) {
            playSound(ModSounds.MOTHER_EMERGE.get(), 3.0F, 0.8F);
            if (level() instanceof ServerLevel sl) {
                BlockState below = sl.getBlockState(blockPosition().below());
                if (!below.isAir()) {
                    sl.sendParticles(new BlockParticleOption(ParticleTypes.BLOCK, below), getX(), getY() + 0.2, getZ(), 80, 1.4, 0.3, 1.4, 0.15);
                }
            }
        }
    }

    @Override
    protected void registerGoals() {
        // all behaviour is driven by the state machine in customServerAiStep
    }

    @Override
    public boolean isPushable() {
        return false;
    }

    @Override
    public void knockback(double strength, double x, double z) {
    }

    @Override
    protected void customServerAiStep() {
        super.customServerAiStep();
        bossEvent.setProgress(getHealth() / getMaxHealth());
        if (!(level() instanceof ServerLevel sl)) return;
        stateTicks++;
        if (attackCooldown > 0) attackCooldown--;
        if (handCooldown > 0) handCooldown--;

        Player target = null;
        double best = 40 * 40;
        for (Player p : sl.players()) {
            if (!NightmareUtil.isValidVictim(p)) continue;
            double d = p.distanceToSqr(this);
            if (d < best) {
                best = d;
                target = p;
            }
        }
        setTarget(target);

        if (getPhase() == 1 && getHealth() < getMaxHealth() * 0.5F) {
            entityData.set(DATA_PHASE, 2);
            bossEvent.setColor(BossEvent.BossBarColor.RED);
            playSound(ModSounds.MOTHER_DEATH.get(), 4.0F, 1.3F);
            for (ServerPlayer sp : sl.players()) {
                if (sp.distanceToSqr(this) < 48 * 48) ModNetwork.sendTo(sp, new FxPacket(FxPacket.DREAMER_PULSE, 0.8F));
            }
        }
        boolean enraged = getPhase() >= 2;

        switch (getMotherState()) {
            case SUBMERGED -> {
                setDeltaMovement(Vec3.ZERO);
                if (target != null && handCooldown <= 0) {
                    spawnHand(sl, target);
                    handCooldown = enraged ? 25 : 40;
                }
                if (stateTicks == 30 && target != null) {
                    BlockPos spot = NightmareUtil.findStandingSpot(sl, getType(), target.position(), 4, 10, 12, random);
                    if (spot != null) teleportTo(spot.getX() + 0.5, spot.getY(), spot.getZ() + 0.5);
                }
                if (stateTicks > (enraged ? 60 : 90) && target != null) setMotherState(EMERGING);
            }
            case EMERGING -> {
                faceTarget(target);
                if (stateTicks >= EMERGE_TICKS) setMotherState(ACTIVE);
            }
            case ACTIVE -> {
                faceTarget(target);
                tickAttacks(sl, target, enraged);
                if (stateTicks > (enraged ? 170 : 240) || (target == null && stateTicks > 60)) setMotherState(SINKING);
            }
            case SINKING -> {
                if (stateTicks >= SINK_TICKS) setMotherState(SUBMERGED);
            }
            default -> setMotherState(ACTIVE);
        }

        if (enraged && --collapseCooldown <= 0 && target != null) {
            collapseCooldown = 30 + random.nextInt(20);
            collapseCeiling(sl);
        }
    }

    private void faceTarget(Player target) {
        if (target == null) return;
        Vec3 d = target.position().subtract(position());
        float want = (float) (Mth.atan2(d.z, d.x) * Mth.RAD_TO_DEG) - 90.0F;
        float yaw = Mth.approachDegrees(getYRot(), want, 6.0F);
        setYRot(yaw);
        yBodyRot = yaw;
        yHeadRot = Mth.approachDegrees(yHeadRot, want, 12.0F);
    }

    private void tickAttacks(ServerLevel sl, Player target, boolean enraged) {
        if (attackWindup > 0) {
            if (--attackWindup == 0) {
                if (getAttack() == ATTACK_SWEEP) doSweep(sl);
                else doSlam(sl);
                entityData.set(DATA_ATTACK, ATTACK_NONE);
                attackCooldown = enraged ? 30 : 45;
            }
            return;
        }
        if (target == null || attackCooldown > 0) return;
        double d = distanceTo(target);
        if (d < 6.5) {
            entityData.set(DATA_ATTACK, ATTACK_SWEEP);
            attackWindup = 14;
        } else if (d < 14 && random.nextInt(3) == 0) {
            entityData.set(DATA_ATTACK, ATTACK_SLAM);
            attackWindup = 20;
        } else if (handCooldown <= 0) {
            spawnHand(sl, target);
            if (enraged) spawnHand(sl, target);
            handCooldown = enraged ? 40 : 60;
            attackCooldown = 20;
        }
    }

    private void doSweep(ServerLevel sl) {
        Vec3 look = Vec3.directionFromRotation(0, getYRot());
        playSound(ModSounds.MOTHER_AMBIENT.get(), 2.0F, 1.4F);
        for (Player p : sl.players()) {
            if (!NightmareUtil.isValidVictim(p)) continue;
            Vec3 to = p.position().subtract(position());
            if (to.length() > 7.0) continue;
            if (to.normalize().dot(look) < 0.1) continue;
            p.hurt(damageSources().mobAttack(this), (float) getAttributeValue(Attributes.ATTACK_DAMAGE));
            Vec3 push = to.normalize().scale(1.6);
            p.setDeltaMovement(push.x, 0.5, push.z);
            p.hurtMarked = true;
        }
        sl.sendParticles(ParticleTypes.SWEEP_ATTACK, getX() + look.x * 3, getY() + 1.5, getZ() + look.z * 3, 6, 1.5, 0.3, 1.5, 0.0);
    }

    private void doSlam(ServerLevel sl) {
        playSound(ModSounds.MOTHER_EMERGE.get(), 3.0F, 1.2F);
        BlockState below = sl.getBlockState(blockPosition().below());
        for (int i = 0; i < 24; i++) {
            double a = i / 24.0 * Math.PI * 2;
            if (!below.isAir()) {
                sl.sendParticles(new BlockParticleOption(ParticleTypes.BLOCK, below), getX() + Math.cos(a) * 4, getY() + 0.1, getZ() + Math.sin(a) * 4, 6, 0.4, 0.1, 0.4, 0.1);
            }
        }
        for (Player p : sl.players()) {
            if (!NightmareUtil.isValidVictim(p) || p.distanceToSqr(this) > 10 * 10 || !p.onGround()) continue;
            p.hurt(damageSources().mobAttack(this), (float) getAttributeValue(Attributes.ATTACK_DAMAGE) * 0.7F);
            p.setDeltaMovement(p.getDeltaMovement().add(0, 0.9, 0));
            p.hurtMarked = true;
            p.addEffect(new MobEffectInstance(MobEffects.MOVEMENT_SLOWDOWN, 60, 2), this);
        }
    }

    private void spawnHand(ServerLevel sl, Player target) {
        MotherHand hand = ModEntities.MOTHER_HAND.get().create(sl);
        if (hand == null) return;
        Vec3 around = target.position().add(target.getDeltaMovement().scale(8.0));
        BlockPos spot = NightmareUtil.findStandingSpot(sl, hand.getType(), around, 0.5, 2.5, 6, random);
        if (spot == null) spot = NightmareUtil.findGround(sl, hand.getType(), target.blockPosition(), 4);
        if (spot == null) return;
        hand.moveTo(spot.getX() + 0.5, spot.getY(), spot.getZ() + 0.5, random.nextFloat() * 360.0F, 0.0F);
        hand.setOwner(this);
        sl.addFreshEntity(hand);
    }

    /** The arena crumbles: blocks above the players come loose and fall. */
    private void collapseCeiling(ServerLevel sl) {
        if (!Config.BOSS_ARENA_GRIEFING.get() || !sl.getGameRules().getBoolean(GameRules.RULE_MOBGRIEFING)) return;
        for (Player p : sl.players()) {
            if (!NightmareUtil.isValidVictim(p) || p.distanceToSqr(this) > 24 * 24) continue;
            for (int tries = 0; tries < 3; tries++) {
                int dx = random.nextInt(9) - 4, dz = random.nextInt(9) - 4;
                if (dx == 0 && dz == 0) continue; // never straight onto someone's head (suffocation trap)
                BlockPos base = p.blockPosition().offset(dx, 2, dz);
                for (int up = 0; up < 10; up++) {
                    BlockPos pos = base.above(up);
                    BlockState state = sl.getBlockState(pos);
                    if (state.isAir()) continue;
                    float hardness = state.getDestroySpeed(sl, pos);
                    // only plain full blocks: falling torches, doors, beds etc. would break or duplicate them
                    if (hardness >= 0 && hardness < 10 && !state.hasBlockEntity() && state.isCollisionShapeFullBlock(sl, pos)
                            && state.getFluidState().isEmpty() && sl.getBlockState(pos.below()).isAir()) {
                        FallingBlockEntity.fall(sl, pos, state);
                    }
                    break;
                }
            }
        }
    }

    /** Damage dealt to one of her hands is passed on to her, even while she hides in the walls. */
    public void hurtThroughHand(DamageSource source, float amount) {
        handDamage = true;
        invulnerableTime = 0;
        hurt(source, amount);
        handDamage = false;
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        if (!handDamage && !source.is(DamageTypeTags.BYPASSES_INVULNERABILITY)) {
            byte s = getMotherState();
            if (s == SUBMERGED || (s == SINKING && stateTicks > SINK_TICKS / 2)) return false;
        }
        return super.hurt(source, amount);
    }

    @Override
    public void startSeenByPlayer(ServerPlayer player) {
        super.startSeenByPlayer(player);
        bossEvent.addPlayer(player);
    }

    @Override
    public void stopSeenByPlayer(ServerPlayer player) {
        super.stopSeenByPlayer(player);
        bossEvent.removePlayer(player);
    }

    @Override
    protected SoundEvent getAmbientSound() {
        return getMotherState() == SUBMERGED ? ModSounds.DRONE.get() : ModSounds.MOTHER_AMBIENT.get();
    }

    @Override
    protected SoundEvent getHurtSound(DamageSource source) {
        return ModSounds.MOTHER_HURT.get();
    }

    @Override
    protected SoundEvent getDeathSound() {
        return ModSounds.MOTHER_DEATH.get();
    }

    @Override
    protected float getSoundVolume() {
        return 3.0F;
    }

    @Override
    public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        tag.putInt("Phase", getPhase());
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        entityData.set(DATA_PHASE, Math.max(1, tag.getInt("Phase")));
        // the state machine is not saved and restarts by emerging: drop the "submerged" flags that NBT kept
        noPhysics = false;
        setNoGravity(false);
        setInvisible(false);
        if (hasCustomName()) bossEvent.setName(getDisplayName());
        if (getPhase() >= 2) bossEvent.setColor(BossEvent.BossBarColor.RED);
    }
}
