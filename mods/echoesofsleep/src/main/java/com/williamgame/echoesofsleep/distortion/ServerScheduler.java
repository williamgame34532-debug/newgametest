package com.williamgame.echoesofsleep.distortion;

import net.minecraft.resources.ResourceKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.Level;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.function.Consumer;

/** Tiny delayed-task queue (ghost slashes, creaking doors). Ticked from DistortionManager. */
public final class ServerScheduler {
    private record Task(ResourceKey<Level> dimension, long due, Consumer<ServerLevel> action) {
    }

    private static final List<Task> TASKS = new ArrayList<>();
    private static long now;

    private ServerScheduler() {
    }

    public static void schedule(ServerLevel level, int delayTicks, Consumer<ServerLevel> action) {
        TASKS.add(new Task(level.dimension(), now + Math.max(1, delayTicks), action));
    }

    static void tick(MinecraftServer server) {
        now++;
        if (TASKS.isEmpty()) return;
        List<Task> due = new ArrayList<>();
        for (Iterator<Task> it = TASKS.iterator(); it.hasNext(); ) {
            Task t = it.next();
            if (t.due() <= now) {
                due.add(t);
                it.remove();
            }
        }
        for (Task t : due) {
            ServerLevel level = server.getLevel(t.dimension());
            if (level != null) {
                t.action().accept(level);
            }
        }
    }

    static void clear() {
        TASKS.clear();
    }
}
