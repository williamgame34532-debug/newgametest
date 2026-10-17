package com.zone19.scp.network;

import net.minecraft.core.BlockPos;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.DistExecutor;
import net.minecraftforge.network.NetworkEvent;
import org.jetbrains.annotations.Nullable;

import java.util.function.Supplier;

/** Full story state for the HUD and the terminal. chapter 0 = not started. */
public record StorySyncPacket(int chapter, int step, int progress, int required, String objective,
                              boolean finished, @Nullable BlockPos waypoint) {
    public void encode(FriendlyByteBuf buf) {
        buf.writeVarInt(chapter);
        buf.writeVarInt(step);
        buf.writeVarInt(progress);
        buf.writeVarInt(required);
        buf.writeUtf(objective);
        buf.writeBoolean(finished);
        buf.writeBoolean(waypoint != null);
        if (waypoint != null) buf.writeBlockPos(waypoint);
    }

    public static StorySyncPacket decode(FriendlyByteBuf buf) {
        int chapter = buf.readVarInt();
        int step = buf.readVarInt();
        int progress = buf.readVarInt();
        int required = buf.readVarInt();
        String objective = buf.readUtf();
        boolean finished = buf.readBoolean();
        BlockPos wp = buf.readBoolean() ? buf.readBlockPos() : null;
        return new StorySyncPacket(chapter, step, progress, required, objective, finished, wp);
    }

    public static void handle(StorySyncPacket msg, Supplier<NetworkEvent.Context> ctx) {
        ctx.get().enqueueWork(() -> DistExecutor.unsafeRunWhenOn(Dist.CLIENT,
                () -> () -> com.zone19.scp.client.ClientPacketHandler.story(msg)));
        ctx.get().setPacketHandled(true);
    }
}
