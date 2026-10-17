package com.zone19.scp.network;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.DistExecutor;
import net.minecraftforge.network.NetworkEvent;

import java.util.function.Supplier;

/**
 * One-off story beats. Text travels as translation keys so every client reads it in its own language.
 */
public record StoryEventPacket(int type, String a, String b, int ticks) {
    public static final int DIALOGUE = 0, TITLE = 1, MUSIC = 2, OPEN_TERMINAL = 3, ENDING = 4, STOP_MUSIC = 5;

    public static StoryEventPacket dialogue(String speaker, String key, int ticks) {
        return new StoryEventPacket(DIALOGUE, speaker, key, ticks);
    }

    public static StoryEventPacket title(String titleKey, String subtitleKey) {
        return new StoryEventPacket(TITLE, titleKey, subtitleKey, 120);
    }

    public static StoryEventPacket music(String id) {
        return new StoryEventPacket(MUSIC, id, "", 0);
    }

    public static StoryEventPacket openTerminal() {
        return new StoryEventPacket(OPEN_TERMINAL, "", "", 0);
    }

    public static StoryEventPacket ending() {
        return new StoryEventPacket(ENDING, "", "", 0);
    }

    public void encode(FriendlyByteBuf buf) {
        buf.writeVarInt(type);
        buf.writeUtf(a);
        buf.writeUtf(b);
        buf.writeVarInt(ticks);
    }

    public static StoryEventPacket decode(FriendlyByteBuf buf) {
        return new StoryEventPacket(buf.readVarInt(), buf.readUtf(), buf.readUtf(), buf.readVarInt());
    }

    public static void handle(StoryEventPacket msg, Supplier<NetworkEvent.Context> ctx) {
        ctx.get().enqueueWork(() -> DistExecutor.unsafeRunWhenOn(Dist.CLIENT,
                () -> () -> com.zone19.scp.client.ClientPacketHandler.event(msg)));
        ctx.get().setPacketHandled(true);
    }
}
