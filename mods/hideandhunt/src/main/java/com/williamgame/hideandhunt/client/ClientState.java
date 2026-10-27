package com.williamgame.hideandhunt.client;

import com.williamgame.hideandhunt.network.RandomizerPacket;
import com.williamgame.hideandhunt.network.ResultsPacket;
import com.williamgame.hideandhunt.network.StatePacket;

/** Last data received from the server. Client only. */
public final class ClientState {
    private ClientState() {}

    public static StatePacket state = StatePacket.hidden();
    public static long stateTick;
    public static long ticks;

    public static RandomizerPacket randomizer;
    public static long randomizerStart;

    public static ResultsPacket lastResults;

    public static void reset() {
        state = StatePacket.hidden();
        randomizer = null;
        lastResults = null;
    }
}
