package com.williamgame.blockmemory.codex;

import net.minecraft.network.chat.Component;

/** Static description of the 24 story fragments (4 chapters x 6). Text lives in the lang files. */
public final class Fragments {
    public static final int CHAPTERS = 4;
    public static final int PER_CHAPTER = 6;
    public static final int TOTAL = CHAPTERS * PER_CHAPTER;
    public static final int ALL_MASK = (1 << TOTAL) - 1;

    private Fragments() {
    }

    public static boolean valid(int index) {
        return index >= 0 && index < TOTAL;
    }

    public static int chapterOf(int index) {
        return index / PER_CHAPTER;
    }

    public static int numberInChapter(int index) {
        return index % PER_CHAPTER + 1;
    }

    public static int chapterMask(int chapter) {
        return ((1 << PER_CHAPTER) - 1) << (chapter * PER_CHAPTER);
    }

    public static boolean chapterComplete(int fragments, int chapter) {
        int m = chapterMask(chapter);
        return (fragments & m) == m;
    }

    public static int countInChapter(int fragments, int chapter) {
        return Integer.bitCount(fragments & chapterMask(chapter));
    }

    public static String roman(int chapter) {
        return switch (chapter) {
            case 0 -> "I";
            case 1 -> "II";
            case 2 -> "III";
            default -> "IV";
        };
    }

    public static Component title(int index) {
        return Component.translatable("blockmemory.fragment." + (index + 1) + ".title");
    }

    public static Component text(int index) {
        return Component.translatable("blockmemory.fragment." + (index + 1) + ".text");
    }

    public static Component chapterTitle(int chapter) {
        return Component.translatable("blockmemory.chapter." + (chapter + 1) + ".title");
    }

    public static Component chapterSubtitle(int chapter) {
        return Component.translatable("blockmemory.chapter." + (chapter + 1) + ".subtitle");
    }

    public static Component chapterReward(int chapter) {
        return Component.translatable("blockmemory.chapter." + (chapter + 1) + ".reward");
    }

    /** "II-3" style label. */
    public static String label(int index) {
        return roman(chapterOf(index)) + "-" + numberInChapter(index);
    }
}
