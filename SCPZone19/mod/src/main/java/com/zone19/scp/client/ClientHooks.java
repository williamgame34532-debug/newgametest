package com.zone19.scp.client;

import com.zone19.scp.client.screen.DocumentScreen;
import net.minecraft.client.Minecraft;

/** Entry points called from common code through DistExecutor. */
public final class ClientHooks {
    public static void openDocument(String scp) {
        Minecraft.getInstance().setScreen(new DocumentScreen(null, scp));
    }

    private ClientHooks() {
    }
}
