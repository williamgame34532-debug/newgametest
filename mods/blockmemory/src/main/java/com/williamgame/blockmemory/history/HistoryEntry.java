package com.williamgame.blockmemory.history;

import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.state.BlockState;

import java.util.UUID;

/**
 * One remembered change of one block.
 *
 * @param timeSec  real-world epoch seconds of the change
 * @param actorId  UUID of the player responsible, or null for mobs / explosions without a player
 */
public record HistoryEntry(BlockPos pos, long timeSec, HistoryAction action, String actorName, UUID actorId,
                           BlockState oldState, BlockState newState) {
}
