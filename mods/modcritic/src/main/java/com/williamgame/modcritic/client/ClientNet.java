package com.williamgame.modcritic.client;

import com.williamgame.modcritic.RatingEntry;
import com.williamgame.modcritic.network.CriticNetwork;
import com.williamgame.modcritic.network.RequestResultsPacket;
import com.williamgame.modcritic.network.SubmitRatingPacket;
import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.ClientPacketListener;

/** Client -> server sending, guarded so nothing is ever sent to a server without the mod. */
public final class ClientNet {
    private ClientNet() {
    }

    public static boolean inWorld() {
        return Minecraft.getInstance().getConnection() != null;
    }

    /** True when connected to a server (or the integrated server) that has Mod Critic. */
    public static boolean serverHasMod() {
        ClientPacketListener listener = Minecraft.getInstance().getConnection();
        return listener != null && CriticNetwork.isPresent(listener.getConnection());
    }

    public static boolean submit(RatingEntry e) {
        if (!serverHasMod()) return false;
        CriticNetwork.sendToServer(new SubmitRatingPacket(e.copy(), false));
        return true;
    }

    public static boolean remove(String modId, String modName) {
        if (!serverHasMod()) return false;
        CriticNetwork.sendToServer(new SubmitRatingPacket(new RatingEntry(modId, modName), true));
        return true;
    }

    public static int submitAll() {
        if (!serverHasMod()) return 0;
        int n = 0;
        for (RatingEntry e : LocalStore.ratings().values()) {
            CriticNetwork.sendToServer(new SubmitRatingPacket(e.copy(), false));
            n++;
        }
        return n;
    }

    public static boolean requestResults() {
        if (!serverHasMod()) return false;
        CriticNetwork.sendToServer(new RequestResultsPacket(0));
        return true;
    }
}
