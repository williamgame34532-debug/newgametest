package com.zone19.scp.client;

import net.minecraft.client.KeyMapping;
import org.lwjgl.glfw.GLFW;

public final class Keys {
    public static final String CATEGORY = "key.categories.scpzone19";
    public static final KeyMapping TERMINAL = new KeyMapping("key.scpzone19.terminal", GLFW.GLFW_KEY_J, CATEGORY);
    public static final KeyMapping BLINK = new KeyMapping("key.scpzone19.blink", GLFW.GLFW_KEY_B, CATEGORY);

    private Keys() {
    }
}
