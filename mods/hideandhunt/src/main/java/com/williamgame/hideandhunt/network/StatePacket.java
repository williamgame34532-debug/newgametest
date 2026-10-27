package com.williamgame.hideandhunt.network;

import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

/** Periodic HUD state for one player. */
public record StatePacket(boolean visible, int phase, int side, boolean alive, int secondsLeft, int phaseTotal,
                          int hidersAlive, int hidersTotal, int hunters, int lobbyHiders, int lobbyHunters,
                          int lobbyNone, String arena, boolean infection, int tauntCooldown, boolean taunts,
                          int joinMode) {

    public static StatePacket hidden() {
        return new StatePacket(false, 0, 0, false, 0, 0, 0, 0, 0, 0, 0, 0, "", false, 0, false, 0);
    }

    public static void encode(StatePacket m, FriendlyByteBuf buf) {
        buf.writeBoolean(m.visible);
        buf.writeVarInt(m.phase);
        buf.writeVarInt(m.side);
        buf.writeBoolean(m.alive);
        buf.writeVarInt(m.secondsLeft);
        buf.writeVarInt(m.phaseTotal);
        buf.writeVarInt(m.hidersAlive);
        buf.writeVarInt(m.hidersTotal);
        buf.writeVarInt(m.hunters);
        buf.writeVarInt(m.lobbyHiders);
        buf.writeVarInt(m.lobbyHunters);
        buf.writeVarInt(m.lobbyNone);
        buf.writeUtf(m.arena, 64);
        buf.writeBoolean(m.infection);
        buf.writeVarInt(m.tauntCooldown);
        buf.writeBoolean(m.taunts);
        buf.writeVarInt(m.joinMode);
    }

    public static StatePacket decode(FriendlyByteBuf buf) {
        return new StatePacket(buf.readBoolean(), buf.readVarInt(), buf.readVarInt(), buf.readBoolean(), buf.readVarInt(),
                buf.readVarInt(), buf.readVarInt(), buf.readVarInt(), buf.readVarInt(), buf.readVarInt(), buf.readVarInt(),
                buf.readVarInt(), buf.readUtf(64), buf.readBoolean(), buf.readVarInt(), buf.readBoolean(), buf.readVarInt());
    }

    public static void handle(StatePacket m, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.hideandhunt.client.ClientHooks.onState(m);
            }
        });
        ctx.setPacketHandled(true);
    }
}
