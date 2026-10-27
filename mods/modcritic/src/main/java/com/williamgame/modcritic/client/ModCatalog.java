package com.williamgame.modcritic.client;

import com.williamgame.modcritic.ModCritic;
import com.williamgame.modcritic.RatingEntry;
import net.minecraftforge.fml.ModList;
import net.minecraftforge.forgespi.language.IModInfo;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/** Installed mods that can be rated: the pack's four mods first, then everything else by name. */
public final class ModCatalog {
    public record ModInfo(String id, String name, String version, String description, boolean installed, int pin) {
        public boolean pinned() {
            return pin >= 0;
        }
    }

    private static final Set<String> SKIP = Set.of("minecraft", "forge", ModCritic.MODID);
    private static List<ModInfo> cached;

    private ModCatalog() {
    }

    public static List<ModInfo> all() {
        List<ModInfo> list = new ArrayList<>();
        Set<String> seen = new HashSet<>();
        if (cached == null) {
            List<ModInfo> installed = new ArrayList<>();
            try {
                for (IModInfo info : ModList.get().getMods()) {
                    String id = info.getModId();
                    if (SKIP.contains(id)) continue;
                    String name = info.getDisplayName();
                    if (name == null || name.isBlank()) name = id;
                    String version = String.valueOf(info.getVersion());
                    String desc = info.getDescription() == null ? "" : info.getDescription().trim();
                    installed.add(new ModInfo(id, name, version, desc, true, ModCritic.pinIndex(id)));
                }
            } catch (Throwable t) {
                ModCritic.LOGGER.warn("Mod Critic: could not read the mod list", t);
            }
            cached = installed;
        }
        for (ModInfo m : cached) {
            list.add(m);
            seen.add(m.id());
        }
        // Mods rated earlier but no longer installed stay visible so their ratings are not lost.
        for (RatingEntry e : LocalStore.ratings().values()) {
            if (seen.add(e.modId)) {
                list.add(new ModInfo(e.modId, e.modName, "", "", false, ModCritic.pinIndex(e.modId)));
            }
        }
        list.sort(Comparator.comparingInt((ModInfo m) -> m.pin() < 0 ? 99 : m.pin())
                .thenComparing(m -> !m.installed())
                .thenComparing(m -> m.name().toLowerCase(Locale.ROOT)));
        return list;
    }

    public static ModInfo find(String id) {
        for (ModInfo m : all()) {
            if (m.id().equals(id)) return m;
        }
        return null;
    }
}
