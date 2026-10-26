package com.williamgame.apiprobe;

import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.network.ChannelBuilder;
import net.minecraftforge.network.NetworkDirection;
import net.minecraftforge.network.PacketDistributor;
import net.minecraftforge.network.SimpleChannel;

public class ProbeNetwork {
    public static final SimpleChannel CHANNEL = ChannelBuilder.named(ApiProbe.id("main"))
            .networkProtocolVersion(1)
            .simpleChannel();

    public static void register() {
        CHANNEL.messageBuilder(ProbeSyncPacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(ProbeSyncPacket::encode).decoder(ProbeSyncPacket::decode)
                .consumerMainThread(ProbeSyncPacket::handle).add();
        CHANNEL.messageBuilder(ProbeActionPacket.class, NetworkDirection.PLAY_TO_SERVER)
                .encoder(ProbeActionPacket::encode).decoder(ProbeActionPacket::decode)
                .consumerMainThread(ProbeActionPacket::handle).add();
    }

    public static void sendTo(ServerPlayer player, Object msg) {
        CHANNEL.send(msg, PacketDistributor.PLAYER.with(player));
    }

    public static void sendToAll(Object msg) {
        CHANNEL.send(msg, PacketDistributor.ALL.noArg());
    }

    public static void sendToServer(Object msg) {
        CHANNEL.send(msg, PacketDistributor.SERVER.noArg());
    }
}
