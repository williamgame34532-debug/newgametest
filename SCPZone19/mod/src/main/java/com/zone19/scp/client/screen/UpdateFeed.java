package com.zone19.scp.client.screen;

import java.util.List;

/** The update panel cards. Text lives in the lang files: update.scpzone19.<id>.{tag,title,1..n}. */
public final class UpdateFeed {
    public record Entry(String id, int color, int lines) {
        public String key(String part) {
            return "update.scpzone19." + id + "." + part;
        }
    }

    public static final List<Entry> ENTRIES = List.of(
            new Entry("release", ScpStyle.RED, 3),
            new Entry("story", ScpStyle.AMBER, 4),
            new Entry("facility", 0xFF6FA8DC, 4),
            new Entry("scps", 0xFFB04BD6, 4),
            new Entry("arsenal", 0xFF9AA0A6, 4),
            new Entry("personnel", ScpStyle.GREEN, 3),
            new Entry("multiplayer", 0xFF3FB6B0, 3),
            new Entry("interface", 0xFFE07A1F, 4)
    );

    private UpdateFeed() {
    }
}
