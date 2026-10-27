package com.williamgame.blockmemory.network;

import net.minecraft.core.BlockPos;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraftforge.event.network.CustomPayloadEvent;
import net.minecraftforge.fml.loading.FMLEnvironment;

import java.util.ArrayList;
import java.util.List;

/** Server -> client: recently changed blocks around a player wearing the Echo Lens. */
public record LensPacket(List<Mark> marks) {
    /** action: HistoryAction ordinal; ageFraction 0..255 (0 = just now, 255 = edge of the lens window). */
    public record Mark(BlockPos pos, int action, int ageFraction) {
    }

    public static final int MAX = 512;

    public static void encode(LensPacket msg, FriendlyByteBuf buf) {
        int n = Math.min(MAX, msg.marks.size());
        buf.writeVarInt(n);
        for (int i = 0; i < n; i++) {
            Mark m = msg.marks.get(i);
            buf.writeBlockPos(m.pos);
            buf.writeByte(m.action);
            buf.writeByte(m.ageFraction);
        }
    }

    public static LensPacket decode(FriendlyByteBuf buf) {
        int n = Math.min(MAX, buf.readVarInt());
        List<Mark> list = new ArrayList<>(n);
        for (int i = 0; i < n; i++) {
            list.add(new Mark(buf.readBlockPos(), buf.readUnsignedByte(), buf.readUnsignedByte()));
        }
        return new LensPacket(list);
    }

    public static void handle(LensPacket msg, CustomPayloadEvent.Context ctx) {
        ctx.enqueueWork(() -> {
            if (FMLEnvironment.dist.isClient()) {
                com.williamgame.blockmemory.client.ClientHooks.onLens(msg.marks);
            }
        });
        ctx.setPacketHandled(true);
    }
}
