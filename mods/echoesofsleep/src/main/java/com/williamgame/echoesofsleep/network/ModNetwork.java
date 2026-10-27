package com.williamgame.echoesofsleep.network;

import com.williamgame.echoesofsleep.EchoesOfSleep;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.network.ChannelBuilder;
import net.minecraftforge.network.NetworkDirection;
import net.minecraftforge.network.PacketDistributor;
import net.minecraftforge.network.SimpleChannel;

public class ModNetwork {
    public static final SimpleChannel CHANNEL = ChannelBuilder.named(EchoesOfSleep.id("main"))
            .networkProtocolVersion(1)
            .simpleChannel();

    public static void register() {
        CHANNEL.messageBuilder(DistortionSyncPacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(DistortionSyncPacket::encode).decoder(DistortionSyncPacket::decode)
                .consumerMainThread(DistortionSyncPacket::handle).add();
        CHANNEL.messageBuilder(FxPacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(FxPacket::encode).decoder(FxPacket::decode)
                .consumerMainThread(FxPacket::handle).add();
    }

    public static void sendTo(ServerPlayer player, Object msg) {
        CHANNEL.send(msg, PacketDistributor.PLAYER.with(player));
    }

    /** Sends to every player currently in the given dimension. */
    public static void sendToLevel(ServerLevel level, Object msg) {
        for (ServerPlayer p : level.players()) {
            sendTo(p, msg);
        }
    }
}
