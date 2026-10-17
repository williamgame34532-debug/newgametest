package com.zone19.scp.network;

import com.zone19.scp.Zone19Mod;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.network.NetworkDirection;
import net.minecraftforge.network.NetworkRegistry;
import net.minecraftforge.network.PacketDistributor;
import net.minecraftforge.network.simple.SimpleChannel;

import java.util.Optional;

public final class Net {
    private static final String PROTOCOL = "1";
    public static final SimpleChannel CHANNEL = NetworkRegistry.newSimpleChannel(Zone19Mod.id("main"),
            () -> PROTOCOL, PROTOCOL::equals, PROTOCOL::equals);

    public static void register() {
        int id = 0;
        CHANNEL.registerMessage(id++, StorySyncPacket.class, StorySyncPacket::encode, StorySyncPacket::decode,
                StorySyncPacket::handle, Optional.of(NetworkDirection.PLAY_TO_CLIENT));
        CHANNEL.registerMessage(id++, StoryEventPacket.class, StoryEventPacket::encode, StoryEventPacket::decode,
                StoryEventPacket::handle, Optional.of(NetworkDirection.PLAY_TO_CLIENT));
        CHANNEL.registerMessage(id++, BlinkPacket.class, BlinkPacket::encode, BlinkPacket::decode,
                BlinkPacket::handle, Optional.of(NetworkDirection.PLAY_TO_CLIENT));
        CHANNEL.registerMessage(id++, SkinSyncPacket.class, SkinSyncPacket::encode, SkinSyncPacket::decode,
                SkinSyncPacket::handle, Optional.of(NetworkDirection.PLAY_TO_CLIENT));
        CHANNEL.registerMessage(id++, SkinSelectPacket.class, SkinSelectPacket::encode, SkinSelectPacket::decode,
                SkinSelectPacket::handle, Optional.of(NetworkDirection.PLAY_TO_SERVER));
        CHANNEL.registerMessage(id++, BlinkNowPacket.class, BlinkNowPacket::encode, BlinkNowPacket::decode,
                BlinkNowPacket::handle, Optional.of(NetworkDirection.PLAY_TO_SERVER));
    }

    public static void toPlayer(ServerPlayer player, Object msg) {
        CHANNEL.send(PacketDistributor.PLAYER.with(() -> player), msg);
    }

    public static void toAll(Object msg) {
        CHANNEL.send(PacketDistributor.ALL.noArg(), msg);
    }

    public static void toServer(Object msg) {
        CHANNEL.sendToServer(msg);
    }

    private Net() {
    }
}
