package com.zone19.scp.entity;

import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.player.Player;
import org.jetbrains.annotations.Nullable;

import java.util.List;

final class ScpUtil {
    /** Players an SCP may hunt: alive, not spectating, not in creative. */
    static boolean huntable(Player p) {
        return p.isAlive() && !p.isSpectator() && !p.isCreative();
    }

    @Nullable
    static Player nearestHuntable(Entity self, double range) {
        List<Player> list = self.level().getEntitiesOfClass(Player.class, self.getBoundingBox().inflate(range), ScpUtil::huntable);
        Player best = null;
        double bestD = Double.MAX_VALUE;
        for (Player p : list) {
            double d = p.distanceToSqr(self);
            if (d < bestD) {
                bestD = d;
                best = p;
            }
        }
        return best;
    }

    private ScpUtil() {
    }
}
