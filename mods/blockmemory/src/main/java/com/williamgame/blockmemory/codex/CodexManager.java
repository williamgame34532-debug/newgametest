package com.williamgame.blockmemory.codex;

import com.williamgame.blockmemory.ModRegistry;
import com.williamgame.blockmemory.network.CodexSyncPacket;
import com.williamgame.blockmemory.network.ModNetwork;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.RandomSource;
import net.minecraft.world.item.ItemStack;

import java.util.ArrayList;
import java.util.List;

/** Server-side codex logic: unlocking fragments, chapter rewards and syncing to the owning client. */
public final class CodexManager {
    private CodexManager() {
    }

    public static CodexData.Progress progress(ServerPlayer player) {
        return CodexData.get(player.server).get(player.getUUID());
    }

    public static void sync(ServerPlayer player) {
        sync(player, -1, -1);
    }

    public static void sync(ServerPlayer player, int newly, int completedChapter) {
        CodexData.Progress p = progress(player);
        ModNetwork.sendTo(player, new CodexSyncPacket(p.fragments, p.claimed, newly, completedChapter));
    }

    public static boolean knows(ServerPlayer player, int index) {
        return Fragments.valid(index) && (progress(player).fragments & (1 << index)) != 0;
    }

    /** Unlocks a fragment. Returns false if it was already known. */
    public static boolean unlock(ServerPlayer player, int index) {
        if (!Fragments.valid(index)) return false;
        CodexData data = CodexData.get(player.server);
        CodexData.Progress p = data.get(player.getUUID());
        if ((p.fragments & (1 << index)) != 0) return false;
        p.fragments |= 1 << index;
        data.changed();
        int chapter = Fragments.chapterOf(index);
        boolean complete = Fragments.chapterComplete(p.fragments, chapter);
        sync(player, index, complete ? chapter : -1);

        player.serverLevel().playSound(null, player.blockPosition(), ModRegistry.SOUND_FRAGMENT_UNLOCK.get(), SoundSource.PLAYERS, 0.9F, 1.0F);
        player.serverLevel().sendParticles(ParticleTypes.ENCHANT, player.getX(), player.getY() + 1.6, player.getZ(), 40, 0.5, 0.6, 0.5, 1.0);
        player.sendSystemMessage(Component.translatable("blockmemory.codex.unlocked",
                Component.literal(Fragments.label(index)).withStyle(ChatFormatting.AQUA),
                Fragments.title(index).copy().withStyle(ChatFormatting.ITALIC, ChatFormatting.GOLD)));
        if (complete) {
            player.serverLevel().playSound(null, player.blockPosition(), ModRegistry.SOUND_CHAPTER_COMPLETE.get(), SoundSource.PLAYERS, 1.0F, 1.0F);
            player.sendSystemMessage(Component.translatable("blockmemory.codex.chapter_complete",
                    Fragments.chapterTitle(chapter).copy().withStyle(ChatFormatting.GOLD)).withStyle(ChatFormatting.LIGHT_PURPLE));
        }
        return true;
    }

    public static void setAll(ServerPlayer player, int fragments, int claimed) {
        CodexData data = CodexData.get(player.server);
        CodexData.Progress p = data.get(player.getUUID());
        p.fragments = fragments & Fragments.ALL_MASK;
        p.claimed = claimed;
        data.changed();
        sync(player);
    }

    /** Picks a fragment the player does not know yet, favouring the earliest unfinished chapter. -1 if all known. */
    public static int pickMissing(ServerPlayer player, RandomSource random) {
        int known = progress(player).fragments;
        List<Integer> missing = new ArrayList<>();
        for (int i = 0; i < Fragments.TOTAL; i++) if ((known & (1 << i)) == 0) missing.add(i);
        if (missing.isEmpty()) return -1;
        if (random.nextFloat() < 0.7F) {
            int firstChapter = Fragments.chapterOf(missing.get(0));
            List<Integer> early = new ArrayList<>();
            for (int i : missing) if (Fragments.chapterOf(i) == firstChapter) early.add(i);
            return early.get(random.nextInt(early.size()));
        }
        return missing.get(random.nextInt(missing.size()));
    }

    public static List<ItemStack> rewards(int chapter) {
        List<ItemStack> list = new ArrayList<>();
        switch (chapter) {
            case 0 -> list.add(new ItemStack(ModRegistry.RECALL_CHARM.get()));
            case 1 -> {
                list.add(new ItemStack(ModRegistry.ARCHIVIST_HOOD.get()));
                list.add(new ItemStack(ModRegistry.ARCHIVIST_ROBE.get()));
            }
            case 2 -> {
                list.add(new ItemStack(ModRegistry.ARCHIVIST_LEGGINGS.get()));
                list.add(new ItemStack(ModRegistry.ARCHIVIST_SANDALS.get()));
            }
            default -> list.add(new ItemStack(ModRegistry.RESTORATION_TOME.get()));
        }
        return list;
    }

    public static void claim(ServerPlayer player, int chapter) {
        if (chapter < 0 || chapter >= Fragments.CHAPTERS) return;
        CodexData data = CodexData.get(player.server);
        CodexData.Progress p = data.get(player.getUUID());
        if (!Fragments.chapterComplete(p.fragments, chapter)) {
            player.displayClientMessage(Component.translatable("blockmemory.codex.not_complete").withStyle(ChatFormatting.RED), true);
            return;
        }
        if ((p.claimed & (1 << chapter)) != 0) {
            player.displayClientMessage(Component.translatable("blockmemory.codex.already_claimed").withStyle(ChatFormatting.GRAY), true);
            return;
        }
        p.claimed |= 1 << chapter;
        data.changed();
        for (ItemStack stack : rewards(chapter)) {
            if (!player.getInventory().add(stack)) {
                player.drop(stack, false);
            }
        }
        player.giveExperiencePoints(50 + 50 * chapter);
        player.serverLevel().playSound(null, player.blockPosition(), ModRegistry.SOUND_CHAPTER_COMPLETE.get(), SoundSource.PLAYERS, 1.0F, 1.2F);
        player.serverLevel().sendParticles(ParticleTypes.TOTEM_OF_UNDYING, player.getX(), player.getY() + 1.0, player.getZ(), 60, 0.6, 0.8, 0.6, 0.4);
        player.sendSystemMessage(Component.translatable("blockmemory.codex.claimed",
                Fragments.chapterReward(chapter).copy().withStyle(ChatFormatting.GOLD)).withStyle(ChatFormatting.GREEN));
        sync(player);
    }
}
