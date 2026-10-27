package net.minecraftforge.api.distmarker;
public enum Dist { CLIENT, DEDICATED_SERVER; public boolean isClient() { return true; } public boolean isDedicatedServer() { return false; } }
