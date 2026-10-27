package com.williamgame.hideandhunt.network;

import com.williamgame.hideandhunt.HideAndHunt;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.network.ChannelBuilder;
import net.minecraftforge.network.NetworkDirection;
import net.minecraftforge.network.PacketDistributor;
import net.minecraftforge.network.SimpleChannel;

public final class HHNetwork {
    private HHNetwork() {}

    public static final SimpleChannel CHANNEL = ChannelBuilder.named(HideAndHunt.id("main"))
            .networkProtocolVersion(1)
            .simpleChannel();

    public static void register() {
        CHANNEL.messageBuilder(StatePacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(StatePacket::encode).decoder(StatePacket::decode)
                .consumerMainThread(StatePacket::handle).add();
        CHANNEL.messageBuilder(RandomizerPacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(RandomizerPacket::encode).decoder(RandomizerPacket::decode)
                .consumerMainThread(RandomizerPacket::handle).add();
        CHANNEL.messageBuilder(ResultsPacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(ResultsPacket::encode).decoder(ResultsPacket::decode)
                .consumerMainThread(ResultsPacket::handle).add();
        CHANNEL.messageBuilder(TabletDataPacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(TabletDataPacket::encode).decoder(TabletDataPacket::decode)
                .consumerMainThread(TabletDataPacket::handle).add();
        CHANNEL.messageBuilder(TabletActionPacket.class, NetworkDirection.PLAY_TO_SERVER)
                .encoder(TabletActionPacket::encode).decoder(TabletActionPacket::decode)
                .consumerMainThread(TabletActionPacket::handle).add();
        CHANNEL.messageBuilder(TauntPacket.class, NetworkDirection.PLAY_TO_SERVER)
                .encoder(TauntPacket::encode).decoder(TauntPacket::decode)
                .consumerMainThread(TauntPacket::handle).add();
    }

    public static void sendTo(ServerPlayer player, Object msg) {
        CHANNEL.send(msg, PacketDistributor.PLAYER.with(player));
    }

    public static void sendToServer(Object msg) {
        CHANNEL.send(msg, PacketDistributor.SERVER.noArg());
    }
}
