package com.williamgame.echoesofsleep.entity.ai;

import com.williamgame.echoesofsleep.entity.NightmareMonster;
import com.williamgame.echoesofsleep.entity.NightmareUtil;
import net.minecraft.world.entity.ai.goal.target.NearestAttackableTargetGoal;
import net.minecraft.world.entity.player.Player;

/** Targets the nearest player unless the nightmare is blinded (Dawn Blade) or asleep (Lullaby). */
public class NightmareTargetGoal extends NearestAttackableTargetGoal<Player> {
    private final NightmareMonster nightmare;

    public NightmareTargetGoal(NightmareMonster mob, boolean mustSee) {
        super(mob, Player.class, 10, mustSee, false, e -> e instanceof Player p && NightmareUtil.isValidVictim(p));
        this.nightmare = mob;
    }

    @Override
    public boolean canUse() {
        return !nightmare.isBlinded() && !nightmare.isStunned() && super.canUse();
    }
}
