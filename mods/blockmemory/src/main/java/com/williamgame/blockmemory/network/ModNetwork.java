package com.williamgame.blockmemory.network;

import com.williamgame.blockmemory.BlockMemory;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.network.ChannelBuilder;
import net.minecraftforge.network.NetworkDirection;
import net.minecraftforge.network.PacketDistributor;
import net.minecraftforge.network.SimpleChannel;

public class ModNetwork {
    public static final SimpleChannel CHANNEL = ChannelBuilder.named(BlockMemory.id("main"))
            .networkProtocolVersion(1)
            .simpleChannel();

    public static void register() {
        CHANNEL.messageBuilder(CodexSyncPacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(CodexSyncPacket::encode).decoder(CodexSyncPacket::decode)
                .consumerMainThread(CodexSyncPacket::handle).add();
        CHANNEL.messageBuilder(GhostReplayPacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(GhostReplayPacket::encode).decoder(GhostReplayPacket::decode)
                .consumerMainThread(GhostReplayPacket::handle).add();
        CHANNEL.messageBuilder(LensPacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(LensPacket::encode).decoder(LensPacket::decode)
                .consumerMainThread(LensPacket::handle).add();
        CHANNEL.messageBuilder(CodexClaimPacket.class, NetworkDirection.PLAY_TO_SERVER)
                .encoder(CodexClaimPacket::encode).decoder(CodexClaimPacket::decode)
                .consumerMainThread(CodexClaimPacket::handle).add();
    }

    public static void sendTo(ServerPlayer player, Object msg) {
        CHANNEL.send(msg, PacketDistributor.PLAYER.with(player));
    }

    public static void sendToServer(Object msg) {
        CHANNEL.send(msg, PacketDistributor.SERVER.noArg());
    }
}
