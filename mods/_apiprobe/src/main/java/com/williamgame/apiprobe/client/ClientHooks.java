package com.williamgame.apiprobe.client;

import net.minecraft.client.Minecraft;

public class ClientHooks {
    public static int value;

    public static void onSync(int v, String text) {
        value = v;
        Minecraft.getInstance().setScreen(new ProbeScreen());
    }
}
