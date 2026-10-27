package com.williamgame.hideandhunt.game;

import it.unimi.dsi.fastutil.ints.IntArrayList;
import net.minecraft.core.component.DataComponents;
import net.minecraft.network.chat.Component;
import net.minecraft.network.protocol.game.ClientboundSetActionBarTextPacket;
import net.minecraft.network.protocol.game.ClientboundSetSubtitleTextPacket;
import net.minecraft.network.protocol.game.ClientboundSetTitleTextPacket;
import net.minecraft.network.protocol.game.ClientboundSetTitlesAnimationPacket;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.entity.projectile.FireworkRocketEntity;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.component.FireworkExplosion;
import net.minecraft.world.item.component.Fireworks;

import java.util.List;

/** Small helpers for titles, action bar messages, sounds and fireworks. Server side only. */
public final class Fx {
    private Fx() {}

    public static void title(ServerPlayer p, Component title, Component subtitle, int fadeIn, int stay, int fadeOut) {
        p.connection.send(new ClientboundSetTitlesAnimationPacket(fadeIn, stay, fadeOut));
        p.connection.send(new ClientboundSetSubtitleTextPacket(subtitle == null ? Component.empty() : subtitle));
        p.connection.send(new ClientboundSetTitleTextPacket(title));
    }

    public static void actionBar(ServerPlayer p, Component msg) {
        p.connection.send(new ClientboundSetActionBarTextPacket(msg));
    }

    public static void sound(ServerPlayer p, SoundEvent sound, float volume, float pitch) {
        p.playNotifySound(sound, SoundSource.MASTER, volume, pitch);
    }

    public static void firework(ServerLevel level, double x, double y, double z, int color, int fade, int shapeIndex, int flight) {
        ItemStack rocket = new ItemStack(Items.FIREWORK_ROCKET);
        IntArrayList colors = new IntArrayList();
        colors.add(color);
        colors.add(0xFFFFFF);
        IntArrayList fades = new IntArrayList();
        fades.add(fade);
        FireworkExplosion.Shape[] shapes = FireworkExplosion.Shape.values();
        FireworkExplosion.Shape shape = shapes[Math.floorMod(shapeIndex, shapes.length)];
        rocket.set(DataComponents.FIREWORKS, new Fireworks(flight, List.of(new FireworkExplosion(shape, colors, fades, true, true))));
        FireworkRocketEntity e = new FireworkRocketEntity(level, x, y, z, rocket);
        level.addFreshEntity(e);
    }
}
