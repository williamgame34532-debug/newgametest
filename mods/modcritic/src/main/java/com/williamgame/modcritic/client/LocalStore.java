package com.williamgame.modcritic.client;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.williamgame.modcritic.Criterion;
import com.williamgame.modcritic.ModCritic;
import com.williamgame.modcritic.RatingEntry;
import net.minecraftforge.fml.loading.FMLPaths;

import java.io.Reader;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;

/** The local ratings file: config/modcritic/ratings.json (pretty JSON, UTF-8). */
public final class LocalStore {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().disableHtmlEscaping().create();
    public static final double MAX_WEIGHT = 5.0;

    /** JSON layout of ratings.json. */
    public static class FileData {
        public int version = 1;
        public double[] weights;
        public LinkedHashMap<String, RatingEntry> ratings = new LinkedHashMap<>();
    }

    private static FileData data;

    private LocalStore() {
    }

    public static Path dir() {
        return FMLPaths.CONFIGDIR.get().resolve(ModCritic.MODID);
    }

    public static Path file() {
        return dir().resolve("ratings.json");
    }

    public static FileData get() {
        if (data == null) load();
        return data;
    }

    public static Map<String, RatingEntry> ratings() {
        return get().ratings;
    }

    public static RatingEntry rating(String modId) {
        return get().ratings.get(modId);
    }

    public static double[] weights() {
        return get().weights;
    }

    public static void load() {
        FileData loaded = null;
        Path f = file();
        if (Files.exists(f)) {
            try (Reader r = Files.newBufferedReader(f, StandardCharsets.UTF_8)) {
                loaded = GSON.fromJson(r, FileData.class);
            } catch (Exception ex) {
                ModCritic.LOGGER.warn("Mod Critic: could not read {}, keeping a backup and starting fresh", f, ex);
                try {
                    Files.copy(f, dir().resolve("ratings.json.broken"), StandardCopyOption.REPLACE_EXISTING);
                } catch (Exception ignored) {
                }
            }
        }
        if (loaded == null) loaded = new FileData();
        if (loaded.ratings == null) loaded.ratings = new LinkedHashMap<>();
        LinkedHashMap<String, RatingEntry> clean = new LinkedHashMap<>();
        for (Map.Entry<String, RatingEntry> e : loaded.ratings.entrySet()) {
            if (e.getValue() == null || e.getKey() == null || e.getKey().isEmpty()) continue;
            RatingEntry r = e.getValue();
            r.modId = e.getKey();
            clean.put(e.getKey(), r.sanitize());
        }
        loaded.ratings = clean;
        loaded.weights = sanitizeWeights(loaded.weights);
        data = loaded;
    }

    public static double[] sanitizeWeights(double[] w) {
        double[] out = new double[Criterion.COUNT];
        Arrays.fill(out, 1.0);
        if (w != null) {
            for (int i = 0; i < Math.min(w.length, out.length); i++) {
                double v = w[i];
                if (Double.isNaN(v)) v = 1.0;
                out[i] = Math.max(0, Math.min(MAX_WEIGHT, v));
            }
        }
        return out;
    }

    public static boolean save() {
        FileData d = get();
        try {
            Files.createDirectories(dir());
            Path tmp = dir().resolve("ratings.json.tmp");
            try (Writer w = Files.newBufferedWriter(tmp, StandardCharsets.UTF_8)) {
                GSON.toJson(d, w);
            }
            try {
                Files.move(tmp, file(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
            } catch (Exception atomicFailed) {
                Files.move(tmp, file(), StandardCopyOption.REPLACE_EXISTING);
            }
            return true;
        } catch (Exception ex) {
            ModCritic.LOGGER.error("Mod Critic: could not save {}", file(), ex);
            return false;
        }
    }

    public static void put(RatingEntry e) {
        get().ratings.put(e.modId, e);
    }

    public static void remove(String modId) {
        get().ratings.remove(modId);
    }

    public static void setWeights(double[] w) {
        get().weights = sanitizeWeights(w);
    }
}
