package com.williamgame.echoesofsleep.entity;

import com.williamgame.echoesofsleep.registry.ModItems;
import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.Mth;
import net.minecraft.util.RandomSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.ClipContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.HitResult;
import net.minecraft.world.phys.Vec3;

/** Shared helpers for nightmare AI: per-player view checks and safe spawn positions. */
public final class NightmareUtil {
    private NightmareUtil() {
    }

    public static boolean isValidVictim(Player p) {
        return p != null && p.isAlive() && !p.isSpectator() && !p.isCreative();
    }

    /**
     * True if the player is looking at the entity: the entity must be inside the player's view cone
     * (about 60 degrees from the centre, widened by the entity's angular size) and at least one of
     * several sample points on its body must be reachable by a ray from the player's eyes.
     */
    public static boolean isLookedAtBy(Player player, Entity entity, double maxDistance) {
        return couldSee(player, entity.position(), entity.getBbHeight(), entity.getBbWidth(), maxDistance);
    }

    /**
     * True if the player could see a body standing at {@code feet} with the given height: the body must be
     * inside the player's view cone (about 60 degrees from the centre, widened by its angular size) and at
     * least one of several sample points on it (head, chest, knees) must be reachable by a ray from the eyes.
     */
    public static boolean couldSee(Player player, Vec3 feet, double height, double width, double maxDistance) {
        if (player.isSpectator() || !player.isAlive()) return false;
        Vec3 eye = player.getEyePosition(1.0F);
        Vec3 center = feet.add(0, height * 0.5, 0);
        Vec3 to = center.subtract(eye);
        double dist = to.length();
        if (dist > maxDistance) return false;
        if (dist < 0.5) return true;
        Vec3 view = player.getViewVector(1.0F).normalize();
        double dot = view.dot(to.normalize());
        double halfSize = Math.atan2(height * 0.5 + width, dist);
        double cone = Math.cos(Math.min(Math.PI * 0.5, Math.toRadians(60.0) + halfSize));
        if (dot < cone) return false;
        Level level = player.level();
        for (int i = 0; i < 3; i++) {
            Vec3 target = feet.add(0, height * (0.92 - i * 0.38), 0);
            HitResult hit = level.clip(new ClipContext(eye, target, ClipContext.Block.VISUAL, ClipContext.Fluid.NONE, player));
            if (hit.getType() == HitResult.Type.MISS || hit.getLocation().distanceToSqr(target) < 0.25) {
                return true;
            }
        }
        return false;
    }

    /** Is any player in the level watching this entity? */
    public static boolean isWatchedByAnyone(Entity entity, double maxDistance) {
        for (Player p : entity.level().players()) {
            if (isLookedAtBy(p, entity, maxDistance)) return true;
        }
        return false;
    }

    public static boolean holdsLantern(Player p) {
        return p.getMainHandItem().is(ModItems.INSOMNIA_LANTERN.get()) || p.getOffhandItem().is(ModItems.INSOMNIA_LANTERN.get());
    }

    /**
     * Finds a free standing spot for {@code type} near {@code center}, between minDist and maxDist
     * horizontally, searching vertically around the centre height. Returns null if none found.
     */
    public static BlockPos findStandingSpot(ServerLevel level, EntityType<?> type, Vec3 center, double minDist, double maxDist,
                                            int tries, RandomSource random) {
        for (int i = 0; i < tries; i++) {
            double angle = random.nextDouble() * Math.PI * 2.0;
            double d = minDist + random.nextDouble() * (maxDist - minDist);
            int x = Mth.floor(center.x + Math.cos(angle) * d);
            int z = Mth.floor(center.z + Math.sin(angle) * d);
            BlockPos found = findGround(level, type, new BlockPos(x, Mth.floor(center.y), z), 8);
            if (found != null) return found;
        }
        return null;
    }

    public static BlockPos findGround(ServerLevel level, EntityType<?> type, BlockPos start, int vertical) {
        if (!level.isLoaded(start)) return null;
        for (int dy = 0; dy <= vertical * 2; dy++) {
            int off = (dy % 2 == 0) ? dy / 2 : -(dy / 2 + 1);
            BlockPos p = start.offset(0, off, 0);
            if (p.getY() <= level.getMinBuildHeight() + 1 || p.getY() >= level.getMaxBuildHeight() - 4) continue;
            BlockPos below = p.below();
            if (!level.getBlockState(below).isFaceSturdy(level, below, net.minecraft.core.Direction.UP)) continue;
            if (!level.getFluidState(p).isEmpty()) continue;
            AABB box = type.getDimensions().makeBoundingBox(p.getX() + 0.5, p.getY(), p.getZ() + 0.5);
            if (level.noCollision(box)) {
                return p;
            }
        }
        return null;
    }
}
