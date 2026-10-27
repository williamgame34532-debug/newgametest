package com.williamgame.modcritic.network;

import com.williamgame.modcritic.ModCritic;
import net.minecraft.network.Connection;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.network.ChannelBuilder;
import net.minecraftforge.network.NetworkDirection;
import net.minecraftforge.network.PacketDistributor;
import net.minecraftforge.network.SimpleChannel;

/**
 * Network channel. It is {@code optional()} on both sides: a client with the mod can join
 * vanilla servers / servers without the mod and vice versa. Before sending anything we check
 * {@link #isPresent(Connection)} so packets never go to a side that cannot read them.
 */
public class CriticNetwork {
    public static final int PROTOCOL = 1;

    public static final SimpleChannel CHANNEL = ChannelBuilder.named(ModCritic.id("main"))
            .networkProtocolVersion(PROTOCOL)
            .optional()
            .simpleChannel();

    public static void register() {
        CHANNEL.messageBuilder(SubmitRatingPacket.class, NetworkDirection.PLAY_TO_SERVER)
                .encoder(SubmitRatingPacket::encode).decoder(SubmitRatingPacket::decode)
                .consumerMainThread(SubmitRatingPacket::handle).add();
        CHANNEL.messageBuilder(RequestResultsPacket.class, NetworkDirection.PLAY_TO_SERVER)
                .encoder(RequestResultsPacket::encode).decoder(RequestResultsPacket::decode)
                .consumerMainThread(RequestResultsPacket::handle).add();
        CHANNEL.messageBuilder(ServerResultsPacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(ServerResultsPacket::encode).decoder(ServerResultsPacket::decode)
                .consumerMainThread(ServerResultsPacket::handle).add();
        CHANNEL.messageBuilder(OpenScreenPacket.class, NetworkDirection.PLAY_TO_CLIENT)
                .encoder(OpenScreenPacket::encode).decoder(OpenScreenPacket::decode)
                .consumerMainThread(OpenScreenPacket::handle).add();
    }

    /** True when the other end of this connection has the Mod Critic channel. */
    public static boolean isPresent(Connection connection) {
        try {
            return connection != null && CHANNEL.isRemotePresent(connection);
        } catch (Throwable t) {
            return false;
        }
    }

    public static boolean hasMod(ServerPlayer player) {
        return player != null && player.connection != null && isPresent(player.connection.getConnection());
    }

    /** Sends to a player only if their client has the mod. Returns whether it was sent. */
    public static boolean sendTo(ServerPlayer player, Object msg) {
        if (!hasMod(player)) return false;
        CHANNEL.send(msg, PacketDistributor.PLAYER.with(player));
        return true;
    }

    /** Client -> server. Callers must check presence first (see client.ClientNet). */
    public static void sendToServer(Object msg) {
        CHANNEL.send(msg, PacketDistributor.SERVER.noArg());
    }
}
