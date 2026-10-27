package com.williamgame.modcritic.client;

import com.williamgame.modcritic.RatingEntry;
import com.williamgame.modcritic.network.OpenScreenPacket;
import com.williamgame.modcritic.network.ServerResultsPacket;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.screens.Screen;

import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Client entry points called from packets / events, plus the cached server results. */
public final class ClientHooks {
    /** player name -> that player's entries, as last received from the server; null = never received. */
    private static Map<String, Collection<RatingEntry>> serverData;
    private static long serverDataTime;

    private ClientHooks() {
    }

    public static Map<String, Collection<RatingEntry>> serverData() {
        return serverData;
    }

    public static long serverDataTime() {
        return serverDataTime;
    }

    public static void clearServerData() {
        serverData = null;
    }

    public static void onServerResults(List<ServerResultsPacket.PlayerRatings> players) {
        Map<String, Collection<RatingEntry>> map = new LinkedHashMap<>();
        for (ServerResultsPacket.PlayerRatings p : players) {
            if (!p.entries().isEmpty()) map.put(p.name(), new ArrayList<>(p.entries()));
        }
        serverData = map;
        serverDataTime = System.currentTimeMillis();
        if (Minecraft.getInstance().screen instanceof ResultsScreen rs) rs.onServerData();
    }

    public static void openFromServer(int screen) {
        Minecraft mc = Minecraft.getInstance();
        Screen parent = null; // opened from a command: closing returns straight to the game
        if (screen == OpenScreenPacket.RESULTS) {
            mc.setScreen(new ResultsScreen(parent, ResultsScreen.SOURCE_SERVER));
        } else {
            mc.setScreen(new CriticScreen(parent));
        }
    }

    public static void openRating(Screen parent) {
        Minecraft.getInstance().setScreen(new CriticScreen(parent));
    }
}
