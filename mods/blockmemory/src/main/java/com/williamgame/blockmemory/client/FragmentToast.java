package com.williamgame.blockmemory.client;

import com.williamgame.blockmemory.codex.Fragments;
import com.williamgame.blockmemory.item.MemoryFragmentItem;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.toasts.Toast;
import net.minecraft.client.gui.components.toasts.ToastComponent;
import net.minecraft.network.chat.Component;
import net.minecraft.util.FormattedCharSequence;
import net.minecraft.world.item.ItemStack;

import java.util.List;

/** "Memory recovered" toast shown when a fragment is unlocked. */
public class FragmentToast implements Toast {
    private final int index;
    private final int completedChapter;
    private final ItemStack icon;

    public FragmentToast(int index, int completedChapter) {
        this.index = index;
        this.completedChapter = completedChapter;
        this.icon = MemoryFragmentItem.identified(index);
    }

    @Override
    public int width() {
        return 180;
    }

    @Override
    public int height() {
        return 36;
    }

    @Override
    public Visibility render(GuiGraphics g, ToastComponent toasts, long time) {
        int w = width(), h = height();
        g.fillGradient(0, 0, w, h, 0xF0231A12, 0xF0120D09);
        g.fill(0, 0, w, 1, 0xFFC9A55A);
        g.fill(0, h - 1, w, h, 0xFF7A5E2E);
        g.fill(0, 0, 1, h, 0xFF7A5E2E);
        g.fill(w - 1, 0, w, h, 0xFF7A5E2E);
        // pulsing glyph glow behind the icon
        float pulse = (float) (0.5 + 0.5 * Math.sin(time / 180.0));
        int a = (int) (60 + 80 * pulse);
        g.fill(6, 8, 26, 28, (a << 24) | 0x6FD3E8);
        g.renderItem(icon, 8, 10);
        Font font = toasts.getMinecraft().font;
        Component header = completedChapter >= 0
                ? Component.translatable("blockmemory.toast.chapter", Fragments.chapterTitle(completedChapter))
                : Component.translatable("blockmemory.toast.title", Fragments.label(index));
        g.drawString(font, header, 32, 7, completedChapter >= 0 ? 0xFFF2D27A : 0xFF9FE6F2, false);
        List<FormattedCharSequence> lines = font.split(Fragments.title(index), w - 38);
        if (!lines.isEmpty()) g.drawString(font, lines.get(0), 32, 19, 0xFFE8DCC4, false);
        return time >= 6000L * toasts.getNotificationDisplayTimeMultiplier() ? Visibility.HIDE : Visibility.SHOW;
    }
}
