package com.williamgame.blockmemory.client;

import com.williamgame.blockmemory.ModRegistry;
import com.williamgame.blockmemory.codex.Fragments;
import com.williamgame.blockmemory.network.GhostReplayPacket;
import com.williamgame.blockmemory.network.LensPacket;
import net.minecraft.client.Minecraft;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** Client-side state: codex progress, active ghost replays and Echo Lens marks. */
public final class ClientHooks {
    private ClientHooks() {
    }

    // ------------------------------------------------------------------ codex
    public static int fragments;
    public static int claimed;
    /** Fragments unlocked during this session and not yet looked at in the Codex. */
    public static final Set<Integer> unseen = new HashSet<>();

    public static void onCodexSync(int newFragments, int newClaimed, int newly, int completedChapter) {
        fragments = newFragments;
        claimed = newClaimed;
        if (Fragments.valid(newly)) {
            unseen.add(newly);
            Minecraft.getInstance().getToasts().addToast(new FragmentToast(newly, completedChapter));
        }
        if (Minecraft.getInstance().screen instanceof CodexScreen screen) {
            screen.onSync();
        }
    }

    public static void openCodex() {
        Minecraft mc = Minecraft.getInstance();
        mc.setScreen(new CodexScreen());
        mc.getSoundManager().play(SimpleSoundInstance.forUI(ModRegistry.SOUND_CODEX_OPEN.get(), 1.0F, 0.7F));
    }

    // ------------------------------------------------------------------ ghosts
    public static final class Ghost {
        public final BlockPos pos;
        public final BlockState state;
        public final boolean ancient;
        public final int delay;
        public final float phase;

        Ghost(BlockPos pos, BlockState state, boolean ancient, int delay, float phase) {
            this.pos = pos;
            this.state = state;
            this.ancient = ancient;
            this.delay = delay;
            this.phase = phase;
        }
    }

    public static final class Replay {
        public final BlockPos center;
        public final long start;
        public final int duration;
        public final List<Ghost> ghosts;

        Replay(BlockPos center, long start, int duration, List<Ghost> ghosts) {
            this.center = center;
            this.start = start;
            this.duration = duration;
            this.ghosts = ghosts;
        }
    }

    public static final List<Replay> replays = new ArrayList<>();

    public static void onGhosts(BlockPos center, int duration, List<GhostReplayPacket.Ghost> list) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.level == null) return;
        List<Ghost> ghosts = new ArrayList<>(list.size());
        int maxDelay = 0;
        for (GhostReplayPacket.Ghost g : list) {
            BlockState state = Block.stateById(g.stateId());
            if (state.isAir()) continue;
            int delay = (int) (Math.sqrt(g.pos().distSqr(center)) * 1.6);
            maxDelay = Math.max(maxDelay, delay);
            float phase = (float) ((g.pos().asLong() * 31L) % 628) / 100F;
            ghosts.add(new Ghost(g.pos(), state, g.ancient(), delay, phase));
        }
        if (ghosts.isEmpty()) return;
        // the rise must finish before the fade starts
        int total = Math.max(duration, maxDelay + 60);
        replays.add(new Replay(center, mc.level.getGameTime(), total, ghosts));
        while (replays.size() > 4) replays.remove(0);
    }

    // ------------------------------------------------------------------ lens
    public static List<LensPacket.Mark> lensMarks = new ArrayList<>();
    public static long lensTime;

    public static void onLens(List<LensPacket.Mark> marks) {
        Minecraft mc = Minecraft.getInstance();
        lensMarks = marks;
        lensTime = mc.level != null ? mc.level.getGameTime() : 0;
    }

    public static void clear() {
        replays.clear();
        lensMarks = new ArrayList<>();
    }
}
