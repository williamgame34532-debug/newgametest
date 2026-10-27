package com.williamgame.hideandhunt.game;

import com.williamgame.hideandhunt.HideAndHunt;
import com.williamgame.hideandhunt.ModRegistry;
import com.williamgame.hideandhunt.block.TeamPadBlock;
import com.williamgame.hideandhunt.network.HHNetwork;
import com.williamgame.hideandhunt.network.RandomizerPacket;
import com.williamgame.hideandhunt.network.ResultsPacket;
import com.williamgame.hideandhunt.network.StatePacket;
import com.williamgame.hideandhunt.network.TabletDataPacket;
import net.minecraft.ChatFormatting;
import net.minecraft.core.BlockPos;
import net.minecraft.core.particles.DustParticleOptions;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.Tag;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.ClickEvent;
import net.minecraft.network.chat.HoverEvent;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerBossEvent;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.BossEvent;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.damagesource.DamageTypes;
import net.minecraft.world.effect.MobEffectCategory;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.AttributeModifier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.phys.Vec3;
import org.joml.Vector3f;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.util.HashSet;
import java.util.UUID;

/**
 * Server-authoritative game loop: lobby -> countdown -> hiding -> hunting -> results -> lobby.
 * One instance per running server, ticked from {@code ServerTickEvent.Post}.
 */
public final class GameManager {
    private static GameManager instance;

    public static GameManager get(MinecraftServer server) {
        if (instance == null || instance.server != server) instance = new GameManager(server);
        return instance;
    }

    public static void forget() {
        instance = null;
    }

    public enum JoinVia { PAD, BUTTON, COMMAND, ADMIN }

    /** A player taking part in the current round. */
    public static final class Participant {
        final UUID id;
        String name;
        final Side startSide;
        Side side;
        boolean caught;
        String caughtBy = "";
        long caughtTick = -1;
        int catches;
        int tauntPoints;
        int taunts;
        long lastTaunt = Long.MIN_VALUE / 2;
        boolean online = true;
        SpawnPoint spawn;

        Participant(UUID id, String name, Side side) {
            this.id = id;
            this.name = name;
            this.startSide = side;
            this.side = side;
        }
    }

    private final MinecraftServer server;
    private final Random random = new Random();
    private Phase phase = Phase.LOBBY;
    private int phaseTicks;
    private int phaseTotalTicks;
    private long tick;
    private long huntStartTick;
    private long roundEndTick;
    private final Map<UUID, Participant> participants = new LinkedHashMap<>();
    private ServerBossEvent bossBar;
    private int randomizerLock;
    private boolean startAfterRandomizer;
    private boolean randomizedSinceRound;
    private Map<UUID, Side> pendingReveal;
    private int revealTicks;
    private final Map<UUID, Integer> outside = new HashMap<>();
    private final java.util.Set<UUID> pendingReturn = new java.util.HashSet<>();
    private final Map<UUID, Long> padCooldown = new HashMap<>();
    private boolean glowApplied;
    private boolean needEndCheck;
    private int fireworkBursts;
    private Side winner = Side.NONE;
    /** Solo test round started with /hh start test: no hunters needed, no results, not counted. */
    private boolean testMode;
    private boolean lastHiderAnnounced;
    private ResultsPacket lastResults;
    /** Players looking at spawn/border markers (/hh show), until which tick. */
    private final Map<UUID, Long> showUntil = new HashMap<>();
    /** Players who were refused by a pad and are still standing on it (play the "no" sound only once). */
    private final Set<UUID> padRefused = new HashSet<>();

    private static final ResourceLocation FREEZE_ID = HideAndHunt.id("hunter_freeze");

    private GameManager(MinecraftServer server) {
        this.server = server;
    }

    public ArenaData data() {
        return ArenaData.get(server);
    }

    public GameSettings settings() {
        return data().settings;
    }

    public Phase phase() {
        return phase;
    }

    public ServerLevel arenaLevel() {
        ServerLevel l = server.getLevel(data().dimensionKey());
        return l != null ? l : server.overworld();
    }

    private ServerPlayer player(UUID id) {
        return server.getPlayerList().getPlayer(id);
    }

    private ServerPlayer online(Participant p) {
        return p.online ? player(p.id) : null;
    }

    public boolean isParticipant(ServerPlayer p) {
        return participants.containsKey(p.getUUID());
    }

    public boolean inRound(ServerPlayer p) {
        return phase.inRound() && participants.containsKey(p.getUUID());
    }

    // ================================================================== helpers

    private static MutableComponent tr(String key, Object... args) {
        return Component.translatable("hideandhunt." + key, args);
    }

    private List<ServerPlayer> arenaPlayers() {
        ServerLevel level = arenaLevel();
        List<ServerPlayer> out = new ArrayList<>(level.players());
        for (Participant p : participants.values()) {
            ServerPlayer sp = online(p);
            if (sp != null && !out.contains(sp)) out.add(sp);
        }
        return out;
    }

    private void broadcastArena(Component msg) {
        for (ServerPlayer p : arenaPlayers()) p.sendSystemMessage(msg);
    }

    private static Component prefix() {
        return Component.literal("[").withStyle(ChatFormatting.DARK_GRAY)
                .append(Component.translatable("hideandhunt.short").withStyle(ChatFormatting.GOLD))
                .append(Component.literal("] ").withStyle(ChatFormatting.DARK_GRAY));
    }

    private void announce(Component msg) {
        broadcastArena(Component.empty().append(prefix()).append(msg));
    }

    public static Component prefixed(Component msg) {
        return Component.empty().append(prefix()).append(msg);
    }

    /** Players in the lobby that can take part (arena dimension, not in spectator mode, not opted out). */
    public List<ServerPlayer> lobbyCandidates() {
        ArenaData d = data();
        List<ServerPlayer> out = new ArrayList<>();
        for (ServerPlayer p : arenaLevel().players()) {
            if (p.isSpectator()) continue;
            if (d.sideOf(p.getUUID()) == Side.SPECTATOR) continue;
            out.add(p);
        }
        return out;
    }

    private int countLobby(Side side) {
        ArenaData d = data();
        int n = 0;
        for (ServerPlayer p : lobbyCandidates()) if (d.sideOf(p.getUUID()) == side) n++;
        return n;
    }

    /** Number of hunters for {@code n} players, honouring ratio and limits. */
    public int hunterCount(int n) {
        GameSettings s = settings();
        int ratio = Math.max(1, s.getInt(GameSettings.HUNTER_RATIO));
        int h = Math.max(1, n / ratio);
        int maxH = s.getInt(GameSettings.MAX_HUNTERS);
        if (maxH > 0) h = Math.min(h, maxH);
        int maxHid = s.getInt(GameSettings.MAX_HIDERS);
        if (maxHid > 0 && n - h > maxHid) h = maxH > 0 ? Math.min(maxH, n - maxHid) : n - maxHid;
        return Math.max(1, Math.min(h, n - 1));
    }

    private void teleport(ServerPlayer p, SpawnPoint sp) {
        if (sp == null) return;
        p.stopRiding();
        p.teleportTo(arenaLevel(), sp.x(), sp.y(), sp.z(), sp.yaw(), sp.pitch());
        p.setDeltaMovement(Vec3.ZERO);
        p.resetFallDistance();
    }

    private SpawnPoint pickSpawn(List<SpawnPoint> list, int index) {
        if (list.isEmpty()) return data().lobby;
        return list.get(Math.floorMod(index, list.size()));
    }

    private SpawnPoint spawnOf(Participant part) {
        ArenaData d = data();
        if (part.side == Side.SPECTATOR) return d.spectator != null ? d.spectator : part.spawn;
        if (part.side == Side.HUNTER && part.startSide != Side.HUNTER) {
            // infected hider: send them to a hunter spawn if they need a respawn
            return d.hunterSpawns.isEmpty() ? part.spawn : d.hunterSpawns.get(random.nextInt(d.hunterSpawns.size()));
        }
        return part.spawn;
    }

    private int aliveHiders() {
        int n = 0;
        for (Participant p : participants.values()) if (p.side == Side.HIDER && !p.caught) n++;
        return n;
    }

    private int hidersTotal() {
        int n = 0;
        for (Participant p : participants.values()) if (p.startSide == Side.HIDER) n++;
        return n;
    }

    private int huntersCount(boolean onlineOnly) {
        int n = 0;
        for (Participant p : participants.values()) if (p.side == Side.HUNTER && (!onlineOnly || p.online)) n++;
        return n;
    }

    private int caughtCount() {
        int n = 0;
        for (Participant p : participants.values()) if (p.startSide == Side.HIDER && p.caught) n++;
        return n;
    }

    private int secondsLeft() {
        return (phaseTicks + 19) / 20;
    }

    private static String clock(int seconds) {
        return String.format(java.util.Locale.ROOT, "%d:%02d", seconds / 60, seconds % 60);
    }

    // ================================================================== joining

    public Component joinMessageFor(GameSettings.JoinMode mode) {
        return switch (mode) {
            case RANDOM -> tr("msg.join_random");
            case ADMIN -> tr("msg.join_admin");
            default -> tr("msg.join_pads");
        };
    }

    /** Tries to put a player on a side. Returns true on success (or if already on that side). */
    public boolean join(ServerPlayer p, Side side, JoinVia via, boolean quietIfSame) {
        return join(p, side, via, quietIfSame, false);
    }

    private void refuse(ServerPlayer p, Component msg, boolean quiet) {
        Fx.actionBar(p, msg);
        if (!quiet) Fx.sound(p, SoundEvents.VILLAGER_NO, 0.8F, 1.0F);
    }

    /** @param quietRefusal don't play the refusal sound (pads repeat the attempt while the player stands on them) */
    public boolean join(ServerPlayer p, Side side, JoinVia via, boolean quietIfSame, boolean quietRefusal) {
        ArenaData d = data();
        Side current = d.sideOf(p.getUUID());
        if (current == side) {
            if (!quietIfSame) Fx.actionBar(p, tr("msg.already_side", side.displayName()));
            return true;
        }
        if (phase != Phase.LOBBY) {
            refuse(p, tr("msg.game_running").withStyle(ChatFormatting.RED), quietRefusal);
            return false;
        }
        if (randomizerLock > 0) {
            refuse(p, tr("msg.randomizer_busy").withStyle(ChatFormatting.GOLD), quietRefusal);
            return false;
        }
        GameSettings.JoinMode mode = d.settings.joinMode();
        if (via != JoinVia.ADMIN && mode == GameSettings.JoinMode.ADMIN) {
            refuse(p, joinMessageFor(mode).copy().withStyle(ChatFormatting.YELLOW), quietRefusal);
            return false;
        }
        if (via != JoinVia.ADMIN && side != Side.NONE && side != Side.SPECTATOR) {
            boolean allowed = switch (mode) {
                case FREE -> true;
                case PADS -> via == JoinVia.PAD || via == JoinVia.BUTTON;
                case RANDOM, ADMIN -> false;
            };
            if (!allowed) {
                refuse(p, joinMessageFor(mode).copy().withStyle(ChatFormatting.YELLOW), quietRefusal);
                return false;
            }
            int max = d.settings.getInt(side == Side.HIDER ? GameSettings.MAX_HIDERS : GameSettings.MAX_HUNTERS);
            int count = countLobby(side);
            if (max > 0 && count >= max) {
                refuse(p, tr("msg.side_full", side.pluralName(), max).withStyle(ChatFormatting.RED), quietRefusal);
                return false;
            }
            if (side == Side.HUNTER && d.settings.getBool(GameSettings.BALANCE_CHECK)) {
                int n = Math.max(2, lobbyCandidates().size());
                int fair = Math.max(1, (n + d.settings.getInt(GameSettings.HUNTER_RATIO) - 1) / Math.max(1, d.settings.getInt(GameSettings.HUNTER_RATIO)));
                if (count >= fair) {
                    refuse(p, tr("msg.side_unbalanced", side.pluralName()).withStyle(ChatFormatting.RED), quietRefusal);
                    return false;
                }
            }
        }
        d.setSide(p.getUUID(), side);
        d.rememberName(p.getUUID(), p.getGameProfile().getName());
        TeamDisplay.assign(server, d, p.getUUID(), p.getScoreboardName(), side);
        if (side == Side.NONE) {
            Fx.actionBar(p, tr("msg.left_side").withStyle(ChatFormatting.GRAY));
            Fx.sound(p, SoundEvents.UI_BUTTON_CLICK.value(), 0.6F, 0.8F);
        } else {
            if (side == Side.SPECTATOR) {
                Fx.actionBar(p, tr("msg.joined_spectator").withStyle(ChatFormatting.GRAY));
            } else {
                int hid = countLobby(Side.HIDER), hun = countLobby(Side.HUNTER);
                Side other = side == Side.HIDER ? Side.HUNTER : Side.HIDER;
                Fx.actionBar(p, tr("msg.joined", side.pluralName().withStyle(ChatFormatting.BOLD), side == Side.HIDER ? hid : hun,
                        other.pluralName(), side == Side.HIDER ? hun : hid));
            }
            Fx.sound(p, ModRegistry.SND_JOIN.get(), 1.0F, side == Side.HUNTER ? 0.8F : 1.2F);
            arenaLevel().sendParticles(ParticleTypes.HAPPY_VILLAGER, p.getX(), p.getY() + 1.0, p.getZ(), 12, 0.4, 0.6, 0.4, 0.0);
        }
        syncAll();
        return true;
    }

    public Component adminSetSide(UUID id, String name, Side side) {
        if (phase != Phase.LOBBY) return tr("msg.game_running").withStyle(ChatFormatting.RED);
        if (randomizerLock > 0) return tr("msg.randomizer_busy");
        ArenaData d = data();
        d.setSide(id, side);
        d.rememberName(id, name);
        ServerPlayer p = player(id);
        if (p != null) {
            TeamDisplay.assign(server, d, id, p.getScoreboardName(), side);
            Fx.actionBar(p, tr("msg.assigned", side.displayName()));
        }
        syncAll();
        return null;
    }

    public void resetTeams() {
        ArenaData d = data();
        for (UUID id : new ArrayList<>(d.sides.keySet())) {
            ServerPlayer p = player(id);
            if (p != null && !inRound(p)) TeamDisplay.assign(server, d, id, p.getScoreboardName(), Side.NONE);
        }
        d.sides.clear();
        d.setDirty();
        TeamDisplay.removeEmptyTeams(server);
        randomizedSinceRound = false;
        syncAll();
    }

    private void scanPads() {
        Set<UUID> onPad = new HashSet<>();
        for (ServerPlayer p : server.getPlayerList().getPlayers()) {
            if (p.isSpectator()) continue;
            Level level = p.level();
            BlockPos pos = p.blockPosition();
            Block b = level.getBlockState(pos).getBlock();
            if (!(b instanceof TeamPadBlock)) {
                b = level.getBlockState(pos.below()).getBlock();
                if (!(b instanceof TeamPadBlock)) continue;
            }
            TeamPadBlock pad = (TeamPadBlock) b;
            onPad.add(p.getUUID());
            Long cd = padCooldown.get(p.getUUID());
            if (cd != null && cd > tick) continue;
            if (pad.type == TeamPadBlock.PadType.LOBBY) {
                if (inRound(p) && phase != Phase.ENDING) continue;
                SpawnPoint lobby = data().lobby;
                padCooldown.put(p.getUUID(), tick + 40);
                if (lobby == null) {
                    Fx.actionBar(p, tr("msg.no_lobby").withStyle(ChatFormatting.RED));
                } else {
                    teleport(p, lobby);
                    Fx.sound(p, SoundEvents.ENDERMAN_TELEPORT, 0.7F, 1.2F);
                }
                continue;
            }
            if (isParticipant(p)) continue;
            Side side = pad.type == TeamPadBlock.PadType.HIDER ? Side.HIDER : Side.HUNTER;
            if (data().sideOf(p.getUUID()) == side) continue;
            boolean ok = join(p, side, JoinVia.PAD, true, padRefused.contains(p.getUUID()));
            if (!ok) padRefused.add(p.getUUID());
            padCooldown.put(p.getUUID(), tick + (ok ? 10 : 40));
        }
        padRefused.retainAll(onPad);
    }

    // ================================================================== randomizer

    public Component randomize(ServerPlayer by) {
        if (phase != Phase.LOBBY) return tr("msg.game_running");
        if (randomizerLock > 0) return tr("msg.randomizer_busy");
        ArenaData d = data();
        List<ServerPlayer> cands = lobbyCandidates();
        if (cands.size() < 2) return tr("msg.randomizer_need", 2, cands.size());
        Collections.shuffle(cands, random);
        int h = hunterCount(cands.size());
        int maxHid = d.settings.getInt(GameSettings.MAX_HIDERS);
        List<String> names = new ArrayList<>();
        List<Integer> sides = new ArrayList<>();
        pendingReveal = new LinkedHashMap<>();
        for (int i = 0; i < cands.size(); i++) {
            ServerPlayer p = cands.get(i);
            Side s = i < h ? Side.HUNTER : Side.HIDER;
            if (s == Side.HIDER && maxHid > 0 && (i - h) >= maxHid) s = Side.SPECTATOR;
            // the result stays secret (no team colours / HUD change) until the reels stop: see revealRandomizer()
            d.rememberName(p.getUUID(), p.getGameProfile().getName());
            pendingReveal.put(p.getUUID(), s);
        }
        // the list shown on screen is sorted by name so it doesn't give the result away
        List<ServerPlayer> shown = new ArrayList<>(cands);
        shown.sort((a, b) -> a.getGameProfile().getName().compareToIgnoreCase(b.getGameProfile().getName()));
        for (ServerPlayer p : shown) {
            names.add(p.getGameProfile().getName());
            sides.add(pendingReveal.get(p.getUUID()).ordinal());
        }
        int duration = 100;
        RandomizerPacket pkt = new RandomizerPacket(names, sides, duration);
        for (ServerPlayer p : arenaPlayers()) HHNetwork.sendTo(p, pkt);
        randomizerLock = duration + 20;
        revealTicks = duration;
        randomizedSinceRound = true;
        announce(tr("msg.randomizing", by == null ? Component.literal("Server") : by.getDisplayName()).withStyle(ChatFormatting.GOLD));
        return null;
    }

    private void revealRandomizer() {
        if (pendingReveal == null) return;
        List<String> hiders = new ArrayList<>(), hunters = new ArrayList<>();
        ArenaData d = data();
        for (Map.Entry<UUID, Side> e : pendingReveal.entrySet()) {
            ServerPlayer p = player(e.getKey());
            String n = d.names.getOrDefault(e.getKey(), "?");
            d.setSide(e.getKey(), e.getValue());
            if (p != null) TeamDisplay.assign(server, d, e.getKey(), p.getScoreboardName(), e.getValue());
            if (e.getValue() == Side.HIDER) hiders.add(n);
            else if (e.getValue() == Side.HUNTER) hunters.add(n);
            if (p == null) continue;
            Fx.title(p, tr("title.you_are", e.getValue().displayName().withStyle(ChatFormatting.BOLD)),
                    tr(e.getValue() == Side.HUNTER ? "title.you_are.hunter_sub" : e.getValue() == Side.HIDER ? "title.you_are.hider_sub" : "title.you_are.spect_sub"),
                    5, 50, 15);
        }
        announce(tr("msg.randomized", Component.literal(String.join(", ", hiders)).withStyle(ChatFormatting.GREEN),
                Component.literal(String.join(", ", hunters)).withStyle(ChatFormatting.RED)));
        pendingReveal = null;
        syncAll();
    }

    // ================================================================== start

    /** Returns null if the start was accepted (or deferred), otherwise an error message. */
    public Component tryStart(ServerPlayer by) {
        return tryStart(by, false);
    }

    /** @param test solo test round: only {@code by} plays, as a hider; nothing is counted. */
    public Component tryStart(ServerPlayer by, boolean test) {
        if (phase != Phase.LOBBY) return tr("msg.already_running");
        ArenaData d = data();
        GameSettings s = d.settings;
        if (d.hiderSpawns.isEmpty()) return tr("msg.need_hider_spawn");
        if (d.hunterSpawns.isEmpty()) return tr("msg.need_hunter_spawn");
        if (test) {
            if (by == null) return tr("msg.test_need_player");
            if (randomizerLock > 0) return tr("msg.randomizer_busy");
            participants.clear();
            participants.put(by.getUUID(), new Participant(by.getUUID(), by.getGameProfile().getName(), Side.HIDER));
            TeamDisplay.assign(server, d, by.getUUID(), by.getScoreboardName(), Side.HIDER);
            testMode = true;
            lastHiderAnnounced = false;
            phase = Phase.COUNTDOWN;
            phaseTotalTicks = phaseTicks = Math.min(5, s.getInt(GameSettings.COUNTDOWN)) * 20;
            announce(tr("msg.test_starting", by.getDisplayName()).withStyle(ChatFormatting.AQUA));
            syncAll();
            return null;
        }
        testMode = false;
        if (randomizerLock > 0) {
            startAfterRandomizer = true;
            announce(tr("msg.start_after_randomizer").withStyle(ChatFormatting.YELLOW));
            return null;
        }
        if (s.joinMode() == GameSettings.JoinMode.RANDOM && !randomizedSinceRound) {
            Component err = randomize(by);
            if (err != null) return err;
            startAfterRandomizer = true;
            return null;
        }
        List<ServerPlayer> hiders = new ArrayList<>(), hunters = new ArrayList<>(), none = new ArrayList<>();
        for (ServerPlayer p : lobbyCandidates()) {
            Side side = d.sideOf(p.getUUID());
            if (side == Side.HIDER) hiders.add(p);
            else if (side == Side.HUNTER) hunters.add(p);
            else none.add(p);
        }
        if (s.getBool(GameSettings.AUTO_ASSIGN) && !none.isEmpty()) {
            Collections.shuffle(none, random);
            int target = hunterCount(hiders.size() + hunters.size() + none.size());
            for (ServerPlayer p : none) {
                if (hunters.size() < target) hunters.add(p);
                else hiders.add(p);
            }
        }
        boolean balance = s.getBool(GameSettings.AUTO_BALANCE);
        if (balance) {
            if (hunters.isEmpty() && hiders.size() >= 2) hunters.add(hiders.remove(random.nextInt(hiders.size())));
            if (hiders.isEmpty() && hunters.size() >= 2) hiders.add(hunters.remove(random.nextInt(hunters.size())));
        }
        int maxHid = s.getInt(GameSettings.MAX_HIDERS), maxHun = s.getInt(GameSettings.MAX_HUNTERS);
        if (maxHid > 0 && hiders.size() > maxHid) {
            if (!balance) return tr("msg.too_many", Side.HIDER.pluralName(), maxHid);
            Collections.shuffle(hiders, random);
            while (hiders.size() > maxHid) {
                ServerPlayer p = hiders.remove(hiders.size() - 1);
                if (maxHun == 0 || hunters.size() < maxHun) hunters.add(p);
            }
        }
        if (maxHun > 0 && hunters.size() > maxHun) {
            if (!balance) return tr("msg.too_many", Side.HUNTER.pluralName(), maxHun);
            Collections.shuffle(hunters, random);
            while (hunters.size() > maxHun) {
                ServerPlayer p = hunters.remove(hunters.size() - 1);
                if (maxHid == 0 || hiders.size() < maxHid) hiders.add(p);
            }
        }
        int total = hiders.size() + hunters.size();
        int min = s.getInt(GameSettings.MIN_PLAYERS);
        if (total < min) return tr("msg.need_players", min, total);
        if (hiders.isEmpty()) return tr("msg.need_side", Side.HIDER.displayName());
        if (hunters.isEmpty()) return tr("msg.need_side", Side.HUNTER.displayName());

        participants.clear();
        for (ServerPlayer p : hiders) addParticipant(p, Side.HIDER);
        for (ServerPlayer p : hunters) addParticipant(p, Side.HUNTER);
        randomizedSinceRound = false;
        lastHiderAnnounced = false;
        phase = Phase.COUNTDOWN;
        phaseTotalTicks = phaseTicks = s.getInt(GameSettings.COUNTDOWN) * 20;
        announce(tr("msg.starting", s.getInt(GameSettings.COUNTDOWN), hiders.size(), hunters.size()).withStyle(ChatFormatting.GOLD));
        syncAll();
        return null;
    }

    private void addParticipant(ServerPlayer p, Side side) {
        ArenaData d = data();
        d.setSide(p.getUUID(), side);
        d.rememberName(p.getUUID(), p.getGameProfile().getName());
        TeamDisplay.assign(server, d, p.getUUID(), p.getScoreboardName(), side);
        participants.put(p.getUUID(), new Participant(p.getUUID(), p.getGameProfile().getName(), side));
    }

    private void tickCountdown() {
        // drop players that left the arena dimension or went spectator
        participants.values().removeIf(part -> {
            ServerPlayer p = player(part.id);
            return p == null || p.isSpectator() || p.level() != arenaLevel();
        });
        int hid = 0, hun = 0;
        for (Participant part : participants.values()) {
            if (part.side == Side.HIDER) hid++;
            else hun++;
        }
        boolean notEnough = testMode ? hid == 0 : (hid == 0 || hun == 0 || hid + hun < settings().getInt(GameSettings.MIN_PLAYERS));
        if (notEnough) {
            testMode = false;
            announce(tr("msg.start_cancelled").withStyle(ChatFormatting.RED));
            participants.clear();
            phase = Phase.LOBBY;
            syncAll();
            return;
        }
        if (phaseTicks % 20 == 0) {
            int secs = phaseTicks / 20;
            if (secs > 0 && (secs <= 5 || secs == phaseTotalTicks / 20 || secs % 10 == 0)) {
                ChatFormatting color = secs <= 3 ? ChatFormatting.RED : secs <= 5 ? ChatFormatting.GOLD : ChatFormatting.YELLOW;
                for (ServerPlayer p : arenaPlayers()) {
                    Fx.title(p, Component.literal(String.valueOf(secs)).withStyle(color, ChatFormatting.BOLD),
                            tr("title.round_starts"), 0, 25, 5);
                    Fx.sound(p, ModRegistry.SND_COUNTDOWN.get(), 1.0F, 0.8F + (5 - Math.min(5, secs)) * 0.1F);
                }
            }
        }
        if (--phaseTicks <= 0) beginHiding();
    }

    // ================================================================== hiding

    private void beginHiding() {
        ArenaData d = data();
        GameSettings s = d.settings;
        if (!testMode) d.roundsPlayed++;
        TeamDisplay.ensureTeams(server, s);
        List<SpawnPoint> hs = new ArrayList<>(d.hiderSpawns), ks = new ArrayList<>(d.hunterSpawns);
        Collections.shuffle(hs, random);
        Collections.shuffle(ks, random);
        int hi = 0, ki = 0;
        for (Participant part : participants.values()) {
            part.spawn = part.startSide == Side.HUNTER ? pickSpawn(ks, ki++) : pickSpawn(hs, hi++);
            ServerPlayer p = player(part.id);
            if (p == null) {
                part.online = false;
                continue;
            }
            prepare(p, part);
        }
        bossBar = new ServerBossEvent(tr("boss.hiding", clock(s.getInt(GameSettings.HIDE_TIME))), BossEvent.BossBarColor.GREEN, BossEvent.BossBarOverlay.NOTCHED_10);
        for (ServerPlayer p : arenaPlayers()) bossBar.addPlayer(p);
        if (s.getBool(GameSettings.SIDEBAR)) TeamDisplay.showSidebar(server, d);
        phase = Phase.HIDING;
        phaseTotalTicks = phaseTicks = s.getInt(GameSettings.HIDE_TIME) * 20;
        int hiders = aliveHiders();
        for (Participant part : participants.values()) {
            ServerPlayer p = online(part);
            if (p == null) continue;
            if (part.side == Side.HUNTER) {
                Fx.title(p, tr("title.wait").withStyle(ChatFormatting.RED, ChatFormatting.BOLD), tr("title.wait_sub", s.getInt(GameSettings.HIDE_TIME)), 5, 60, 10);
            } else {
                Fx.title(p, tr("title.hide").withStyle(ChatFormatting.GREEN, ChatFormatting.BOLD), tr("title.hide_sub", s.getInt(GameSettings.HIDE_TIME)), 5, 60, 10);
            }
            Fx.sound(p, ModRegistry.SND_HIDE_START.get(), 1.0F, 1.0F);
        }
        announce(tr("msg.hiding_started", hiders, huntersCount(false), s.getInt(GameSettings.HIDE_TIME)).withStyle(ChatFormatting.GREEN));
        d.setDirty();
        syncAll();
    }

    /** Saves the player's state and equips them for their side. */
    private void prepare(ServerPlayer p, Participant part) {
        ArenaData d = data();
        GameSettings s = d.settings;
        // close any open screen first: the cursor stack and the 2x2 crafting grid are not part of the
        // inventory, so they must go back into it before the snapshot is taken (or they'd be wiped)
        p.closeContainer();
        if (!d.snapshots.containsKey(part.id)) {
            CompoundTag snap = PlayerSnapshot.capture(p);
            snap.putBoolean("keepInv", s.getBool(GameSettings.KEEP_INVENTORY));
            d.snapshots.put(part.id, snap);
            d.setDirty();
        }
        // the snapshot decides, so changing keep_inventory mid-round can never wipe an unsaved inventory
        boolean wipe = inventorySandboxed(part.id);
        p.stopRiding();
        p.removeAllEffects();
        p.setHealth(p.getMaxHealth());
        p.getFoodData().setFoodLevel(20);
        p.getFoodData().setSaturation(5.0F);
        p.clearFire();
        p.resetFallDistance();
        p.setGlowingTag(false);
        if (part.side == Side.SPECTATOR) {
            p.setGameMode(GameType.SPECTATOR);
        } else {
            p.setGameMode(s.getBool(GameSettings.ADVENTURE) ? GameType.ADVENTURE : GameType.SURVIVAL);
            if (wipe) {
                p.getInventory().clearContent();
                giveKit(p, part.side);
            }
        }
        TeamDisplay.assign(server, d, part.id, p.getScoreboardName(), part.side);
        teleport(p, spawnOf(part));
        if (part.side == Side.HUNTER) {
            if (phase == Phase.HIDING || phase == Phase.COUNTDOWN) applyHunterHold(p, true);
            else applyHunterSpeed(p);
        }
    }

    /**
     * True if this player's inventory was saved at round start and will be replaced by the snapshot at the end,
     * i.e. it may be cleared / refilled with kits during the round without losing anything.
     */
    public boolean inventorySandboxed(UUID id) {
        CompoundTag snap = data().snapshots.get(id);
        return snap != null && !snap.getBoolean("keepInv");
    }

    private void giveKit(ServerPlayer p, Side side) {
        ListTag kit = data().kit(side);
        Inventory inv = p.getInventory();
        for (int i = 0; i < kit.size(); i++) {
            CompoundTag c = kit.getCompound(i);
            ItemStack st = ItemStack.parseOptional(p.registryAccess(), c.getCompound("item"));
            if (st.isEmpty()) continue;
            int slot = c.getInt("slot");
            if (slot >= 0 && slot < inv.getContainerSize() && inv.getItem(slot).isEmpty()) inv.setItem(slot, st);
            else inv.add(st);
        }
        inv.setChanged();
    }

    public int captureKit(ServerPlayer p, Side side) {
        ListTag kit = new ListTag();
        Inventory inv = p.getInventory();
        for (int i = 0; i < inv.getContainerSize(); i++) {
            ItemStack st = inv.getItem(i);
            if (st.isEmpty() || st.is(ModRegistry.TABLET.get())) continue;
            CompoundTag c = new CompoundTag();
            c.putInt("slot", i);
            c.put("item", st.save(p.registryAccess()));
            kit.add(c);
        }
        data().setKit(side, kit);
        return kit.size();
    }

    private void applyHunterHold(ServerPlayer p, boolean initial) {
        GameSettings s = settings();
        if (s.getBool(GameSettings.BLIND_HUNTERS)) {
            p.addEffect(new MobEffectInstance(MobEffects.BLINDNESS, 60, 0, false, false, true));
            p.addEffect(new MobEffectInstance(MobEffects.DARKNESS, 60, 0, false, false, false));
        }
        setFrozen(p, s.getBool(GameSettings.FREEZE_HUNTERS));
    }

    /**
     * Freezes a player with transient attribute modifiers (speed and jump x0), which the client predicts smoothly,
     * unlike teleporting. Transient modifiers are never saved, so a crash can't leave anyone frozen.
     */
    public static void setFrozen(ServerPlayer p, boolean frozen) {
        AttributeInstance[] attrs = {p.getAttribute(Attributes.MOVEMENT_SPEED), p.getAttribute(Attributes.JUMP_STRENGTH)};
        for (AttributeInstance a : attrs) {
            if (a == null) continue;
            if (frozen) {
                if (!a.hasModifier(FREEZE_ID)) {
                    a.addTransientModifier(new AttributeModifier(FREEZE_ID, -1.0, AttributeModifier.Operation.ADD_MULTIPLIED_TOTAL));
                }
            } else {
                a.removeModifier(FREEZE_ID);
            }
        }
    }

    private void applyHunterSpeed(ServerPlayer p) {
        setFrozen(p, false);
        p.removeEffect(MobEffects.BLINDNESS);
        p.removeEffect(MobEffects.DARKNESS);
        p.removeEffect(MobEffects.MOVEMENT_SLOWDOWN);
        int speed = settings().getInt(GameSettings.HUNTER_SPEED);
        if (speed > 0) {
            p.addEffect(new MobEffectInstance(MobEffects.MOVEMENT_SPEED, MobEffectInstance.INFINITE_DURATION, speed - 1, false, false, true));
        }
    }

    private void tickHiding() {
        GameSettings s = settings();
        boolean freeze = s.getBool(GameSettings.FREEZE_HUNTERS);
        ServerLevel level = arenaLevel();
        for (Participant part : participants.values()) {
            if (part.side != Side.HUNTER) continue;
            ServerPlayer p = online(part);
            if (p == null || part.spawn == null || p.level() != level) continue;
            // fallback only: the attribute freeze normally keeps them still (knock-back, water currents...)
            if (freeze && part.spawn.distSqr(p.getX(), p.getY(), p.getZ()) > 1.0) {
                p.connection.teleport(part.spawn.x(), part.spawn.y(), part.spawn.z(), p.getYRot(), p.getXRot());
            }
            if (tick % 20 == 0) applyHunterHold(p, false);
        }
        if (tick % 20 == 0) {
            int secs = secondsLeft();
            updateBoss(tr("boss.hiding", clock(secs)), BossEvent.BossBarColor.GREEN);
            if (secs <= 5 && secs > 0) {
                for (Participant part : participants.values()) {
                    ServerPlayer p = online(part);
                    if (p == null) continue;
                    if (part.side == Side.HUNTER) {
                        Fx.title(p, Component.literal(String.valueOf(secs)).withStyle(ChatFormatting.RED, ChatFormatting.BOLD), tr("title.release_in"), 0, 25, 5);
                    }
                    Fx.sound(p, ModRegistry.SND_COUNTDOWN.get(), 0.8F, 1.0F + (5 - secs) * 0.08F);
                }
            } else if (secs == 10 || secs == 30) {
                for (Participant part : participants.values()) {
                    ServerPlayer p = online(part);
                    if (p != null && part.side == Side.HIDER) Fx.actionBar(p, tr("msg.hide_left", secs).withStyle(ChatFormatting.YELLOW));
                }
            }
            perSecondRoundChecks();
            if (phase != Phase.HIDING) return;
        }
        if (--phaseTicks <= 0) beginHunting();
    }

    private void updateBoss(Component name, BossEvent.BossBarColor color) {
        if (bossBar == null) return;
        bossBar.setName(name);
        bossBar.setColor(color);
        bossBar.setProgress(phaseTotalTicks <= 0 ? 0F : Math.max(0F, Math.min(1F, phaseTicks / (float) phaseTotalTicks)));
    }

    // ================================================================== hunting

    private void beginHunting() {
        GameSettings s = settings();
        phase = Phase.HUNTING;
        phaseTotalTicks = phaseTicks = s.getInt(GameSettings.HUNT_TIME) * 20;
        huntStartTick = tick;
        glowApplied = false;
        int hiders = aliveHiders();
        for (Participant part : participants.values()) {
            ServerPlayer p = online(part);
            if (p == null) continue;
            if (part.side == Side.HUNTER) {
                applyHunterSpeed(p);
                Fx.title(p, tr("title.hunt").withStyle(ChatFormatting.RED, ChatFormatting.BOLD), tr("title.hunt_sub", hiders), 3, 50, 12);
            } else if (part.side == Side.HIDER) {
                Fx.title(p, tr("title.released").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD), tr("title.released_sub"), 3, 50, 12);
            }
            Fx.sound(p, ModRegistry.SND_HUNT_START.get(), 1.0F, 1.0F);
        }
        announce(tr("msg.hunt_started", clock(s.getInt(GameSettings.HUNT_TIME))).withStyle(ChatFormatting.RED));
        updateBoss(tr("boss.hunting", clock(secondsLeft()), hiders), BossEvent.BossBarColor.RED);
        syncAll();
    }

    private void tickHunting() {
        GameSettings s = settings();
        if (tick % 20 == 0) {
            int secs = secondsLeft();
            int alive = aliveHiders();
            updateBoss(tr("boss.hunting", clock(secs), alive), secs <= 30 ? BossEvent.BossBarColor.YELLOW : BossEvent.BossBarColor.RED);
            int glow = s.getInt(GameSettings.GLOW_LAST);
            if (glow > 0 && secs <= glow && !glowApplied) {
                glowApplied = true;
                for (Participant part : participants.values()) {
                    ServerPlayer p = online(part);
                    if (p != null && part.side == Side.HIDER && !part.caught) {
                        p.addEffect(new MobEffectInstance(MobEffects.GLOWING, MobEffectInstance.INFINITE_DURATION, 0, false, false, true));
                    }
                }
                announce(tr("msg.glowing").withStyle(ChatFormatting.YELLOW));
            }
            int hint = s.getInt(GameSettings.HINT_INTERVAL);
            long elapsed = (tick - huntStartTick) / 20;
            if (hint > 0 && elapsed > 0 && elapsed % hint == 0) {
                ServerLevel level = arenaLevel();
                for (Participant part : participants.values()) {
                    ServerPlayer p = online(part);
                    if (p == null || part.side != Side.HIDER || part.caught) continue;
                    p.level().playSound(null, p.getX(), p.getY(), p.getZ(), ModRegistry.SND_HINT.get(), SoundSource.PLAYERS, 2.0F, 1.0F);
                    if (p.level() == level) level.sendParticles(ParticleTypes.NOTE, p.getX(), p.getY() + 2.2, p.getZ(), 3, 0.3, 0.2, 0.3, 1.0);
                    Fx.actionBar(p, tr("msg.hint_ping").withStyle(ChatFormatting.LIGHT_PURPLE));
                }
            }
            if (secs == 60 || secs == 30 || secs == 10) {
                for (Participant part : participants.values()) {
                    ServerPlayer p = online(part);
                    if (p != null) {
                        Fx.actionBar(p, tr("msg.time_left", clock(secs)).withStyle(ChatFormatting.GOLD));
                        Fx.sound(p, SoundEvents.NOTE_BLOCK_BELL.value(), 0.7F, 1.0F);
                    }
                }
            }
            perSecondRoundChecks();
            if (phase != Phase.HUNTING) return;
        }
        if (needEndCheck) {
            needEndCheck = false;
            if (checkEnd()) return;
        }
        if (--phaseTicks <= 0) endRound(Side.HIDER, tr("msg.reason_time"));
    }

    /** Ends the round if a side has nobody left. Returns true if the round ended. */
    private boolean checkEnd() {
        if (phase != Phase.HIDING && phase != Phase.HUNTING) return false;
        if (aliveHiders() == 0) {
            endRound(Side.HUNTER, tr("msg.reason_all_caught"));
            return true;
        }
        if (!testMode && huntersCount(true) == 0) {
            endRound(Side.HIDER, tr("msg.reason_no_hunters"));
            return true;
        }
        checkLastHider();
        return false;
    }

    /** "Last hider!" moment: announcement, title for everybody and (optionally) the last one starts glowing. */
    private void checkLastHider() {
        if (phase != Phase.HUNTING || testMode || lastHiderAnnounced || hidersTotal() < 2 || aliveHiders() != 1) return;
        lastHiderAnnounced = true;
        Participant last = null;
        for (Participant part : participants.values()) if (part.side == Side.HIDER && !part.caught) last = part;
        if (last == null) return;
        ServerPlayer lp = online(last);
        boolean glow = settings().getBool(GameSettings.LAST_HIDER_GLOW);
        if (lp != null && glow) {
            lp.addEffect(new MobEffectInstance(MobEffects.GLOWING, MobEffectInstance.INFINITE_DURATION, 0, false, false, true));
        }
        for (Participant part : participants.values()) {
            ServerPlayer p = online(part);
            if (p == null) continue;
            Fx.title(p, tr("title.last_hider").withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD),
                    Component.literal(last.name).withStyle(ChatFormatting.GREEN), 3, 40, 10);
            Fx.sound(p, SoundEvents.NOTE_BLOCK_PLING.value(), 1.0F, 0.7F);
        }
        announce(tr(glow ? "msg.last_hider_glow" : "msg.last_hider", last.name).withStyle(ChatFormatting.GOLD));
    }

    private void perSecondRoundChecks() {
        ArenaData d = data();
        GameSettings s = d.settings;
        int grace = s.getInt(GameSettings.BOUNDARY_GRACE);
        ServerLevel level = arenaLevel();
        for (Participant part : participants.values()) {
            ServerPlayer p = online(part);
            if (p == null) continue;
            if (p.level() != level) {
                pendingReturn.add(part.id);
                continue;
            }
            if (part.side != Side.SPECTATOR) {
                p.getFoodData().setFoodLevel(20);
            }
            if (d.hasBounds() && !d.insideBounds(p.getX(), p.getY(), p.getZ())) {
                int c = outside.merge(part.id, 1, Integer::sum);
                if (c > grace) {
                    outside.remove(part.id);
                    teleport(p, spawnOf(part));
                    Fx.actionBar(p, tr("msg.returned").withStyle(ChatFormatting.RED));
                    Fx.sound(p, SoundEvents.ENDERMAN_TELEPORT, 0.7F, 0.8F);
                } else {
                    Fx.actionBar(p, tr("msg.out_of_bounds", grace - c + 1).withStyle(ChatFormatting.RED, ChatFormatting.BOLD));
                    Fx.sound(p, SoundEvents.NOTE_BLOCK_BASS.value(), 1.0F, 0.6F);
                }
            } else {
                outside.remove(part.id);
            }
        }
        if (s.getBool(GameSettings.SIDEBAR)) {
            TeamDisplay.updateSidebar(server, aliveHiders(), huntersCount(false), secondsLeft(), caughtCount());
        }
        checkEnd();
    }

    // ================================================================== catching

    /** Hunter tags a hider. Returns true if it counted as a catch. */
    public boolean tryCatch(ServerPlayer hunter, ServerPlayer target) {
        if (phase != Phase.HUNTING) return false;
        Participant hp = participants.get(hunter.getUUID());
        Participant tp = participants.get(target.getUUID());
        if (hp == null || tp == null || hp.side != Side.HUNTER || tp.side != Side.HIDER || tp.caught) return false;
        tp.caught = true;
        tp.caughtBy = hp.name;
        tp.caughtTick = tick;
        hp.catches++;
        ServerLevel level = target.serverLevel();
        level.playSound(null, target.getX(), target.getY(), target.getZ(), ModRegistry.SND_CAUGHT.get(), SoundSource.PLAYERS, 1.5F, 1.0F);
        level.sendParticles(ParticleTypes.TOTEM_OF_UNDYING, target.getX(), target.getY() + 1.0, target.getZ(), 30, 0.4, 0.8, 0.4, 0.3);
        level.sendParticles(ParticleTypes.POOF, target.getX(), target.getY() + 0.5, target.getZ(), 15, 0.3, 0.3, 0.3, 0.05);
        Fx.actionBar(hunter, tr("msg.you_caught", target.getDisplayName()).withStyle(ChatFormatting.GOLD));
        Fx.sound(hunter, SoundEvents.EXPERIENCE_ORB_PICKUP, 1.0F, 1.2F);
        eliminate(tp, target);
        int left = aliveHiders();
        announce(tr("msg.caught", target.getDisplayName(), hunter.getDisplayName(), left).withStyle(ChatFormatting.YELLOW));
        checkEnd();
        syncAll();
        return true;
    }

    private void eliminate(Participant part, ServerPlayer p) {
        GameSettings s = settings();
        if (s.infection()) {
            part.side = Side.HUNTER;
            if (p != null) {
                setFrozen(p, false);
                TeamDisplay.assign(server, data(), part.id, p.getScoreboardName(), Side.HUNTER);
                p.removeAllEffects();
                if (inventorySandboxed(part.id)) {
                    p.getInventory().clearContent();
                    giveKit(p, Side.HUNTER);
                }
                applyHunterSpeed(p);
                p.addEffect(new MobEffectInstance(MobEffects.BLINDNESS, 30, 0, false, false, false));
                Fx.title(p, tr("title.infected").withStyle(ChatFormatting.DARK_RED, ChatFormatting.BOLD), tr("title.infected_sub"), 3, 50, 12);
            }
        } else {
            part.side = Side.SPECTATOR;
            if (p != null) {
                setFrozen(p, false);
                TeamDisplay.assign(server, data(), part.id, p.getScoreboardName(), Side.SPECTATOR);
                p.removeAllEffects();
                p.setGameMode(GameType.SPECTATOR);
                SpawnPoint sp = data().spectator;
                if (sp != null) teleport(p, sp);
                Fx.title(p, tr("title.caught").withStyle(ChatFormatting.RED, ChatFormatting.BOLD), tr("title.caught_sub"), 3, 50, 12);
            }
        }
    }

    /** LivingAttackEvent handler for players. Returns true if the damage must be cancelled. */
    public boolean onPlayerAttacked(ServerPlayer target, DamageSource source) {
        if (!phase.inRound()) return false;
        Entity attacker = source.getEntity();
        Participant tp = participants.get(target.getUUID());
        if (attacker instanceof ServerPlayer ap && ap != target) {
            Participant a = participants.get(ap.getUUID());
            if (tp == null && a == null) return false;
            if (a != null && tp != null && tryCatch(ap, target)) return true;
            if (a == null || tp == null) return true; // outsiders can't interfere with the round
            if (phase != Phase.HUNTING) return true;
            return !settings().getBool(GameSettings.FRIENDLY_FIRE);
        }
        if (tp == null) return false;
        if (source.is(DamageTypes.FELL_OUT_OF_WORLD) || source.is(DamageTypes.GENERIC_KILL)) return false;
        if (phase == Phase.ENDING) return true;
        return !settings().getBool(GameSettings.ENV_DAMAGE);
    }

    /** LivingDeathEvent handler. Returns true if the death must be cancelled (player is rescued). */
    public boolean onPlayerDeath(ServerPlayer p, DamageSource source) {
        if (!phase.inRound()) return false;
        Participant part = participants.get(p.getUUID());
        if (part == null) return false;
        p.setHealth(p.getMaxHealth());
        p.clearFire();
        p.resetFallDistance();
        p.setAirSupply(p.getMaxAirSupply());
        // drop harmful effects (poison, wither...) so the rescued player doesn't die again right away
        for (MobEffectInstance e : new ArrayList<>(p.getActiveEffects())) {
            if (e.getEffect().value().getCategory() == MobEffectCategory.HARMFUL) p.removeEffect(e.getEffect());
        }
        Entity killer = source.getEntity();
        if (killer instanceof ServerPlayer kp && tryCatch(kp, p)) {
            if (source.is(DamageTypes.FELL_OUT_OF_WORLD) && !p.isSpectator()) teleport(p, spawnOf(part));
            return true;
        }
        teleport(p, spawnOf(part));
        Fx.actionBar(p, tr("msg.respawned").withStyle(ChatFormatting.GRAY));
        return true;
    }

    // ================================================================== taunts

    public void taunt(ServerPlayer p) {
        Participant part = participants.get(p.getUUID());
        GameSettings s = settings();
        if (phase != Phase.HUNTING || part == null || part.side != Side.HIDER || part.caught) {
            Fx.actionBar(p, tr("msg.taunt_only_hiders").withStyle(ChatFormatting.GRAY));
            return;
        }
        if (!s.getBool(GameSettings.TAUNTS)) {
            Fx.actionBar(p, tr("msg.taunts_disabled").withStyle(ChatFormatting.GRAY));
            return;
        }
        long cd = s.getInt(GameSettings.TAUNT_COOLDOWN) * 20L;
        long wait = part.lastTaunt + cd - tick;
        if (wait > 0) {
            Fx.actionBar(p, tr("msg.taunt_cooldown", (wait + 19) / 20).withStyle(ChatFormatting.GRAY));
            return;
        }
        part.lastTaunt = tick;
        part.taunts++;
        int pts = s.getInt(GameSettings.TAUNT_POINTS);
        part.tauntPoints += pts;
        p.level().playSound(null, p.getX(), p.getY(), p.getZ(), ModRegistry.SND_TAUNT.get(), SoundSource.PLAYERS, 3.0F, 0.9F + random.nextFloat() * 0.25F);
        p.serverLevel().sendParticles(ParticleTypes.NOTE, p.getX(), p.getY() + 2.2, p.getZ(), 8, 0.6, 0.3, 0.6, 1.0);
        Fx.actionBar(p, tr("msg.taunted", pts).withStyle(ChatFormatting.LIGHT_PURPLE));
        syncTo(p);
    }

    // ================================================================== end of round

    private void endRound(Side win, Component reason) {
        ArenaData d = data();
        GameSettings s = d.settings;
        winner = win;
        phase = Phase.ENDING;
        phaseTotalTicks = phaseTicks = s.getInt(GameSettings.RESULTS_TIME) * 20;
        roundEndTick = tick;
        fireworkBursts = 6;
        ResultsPacket results = buildResults();
        updateBoss(tr(win == Side.HIDER ? "boss.hiders_win" : "boss.hunters_win"), win == Side.HIDER ? BossEvent.BossBarColor.GREEN : BossEvent.BossBarColor.RED);
        if (bossBar != null) bossBar.setProgress(1.0F);
        for (Participant part : participants.values()) {
            ServerPlayer p = online(part);
            if (p == null) continue;
            p.removeEffect(MobEffects.GLOWING);
            p.removeEffect(MobEffects.MOVEMENT_SPEED);
            p.removeEffect(MobEffects.BLINDNESS);
            p.removeEffect(MobEffects.DARKNESS);
            p.removeEffect(MobEffects.MOVEMENT_SLOWDOWN);
            setFrozen(p, false);
            boolean won = (part.startSide == win && (win == Side.HUNTER || !part.caught)) || (win == Side.HUNTER && part.side == Side.HUNTER);
            Fx.title(p, tr(won ? "title.victory" : "title.defeat").withStyle(won ? ChatFormatting.GOLD : ChatFormatting.DARK_RED, ChatFormatting.BOLD),
                    tr(win == Side.HIDER ? "title.hiders_win" : "title.hunters_win").withStyle(win.color), 5, 70, 20);
            Fx.sound(p, won ? ModRegistry.SND_VICTORY.get() : ModRegistry.SND_DEFEAT.get(), won ? 1.0F : 0.8F, 1.0F);
        }
        if (testMode) {
            announce(tr("msg.test_over").withStyle(ChatFormatting.AQUA));
            syncAll();
            return;
        }
        lastResults = results;
        Component link = resultsLink();
        for (ServerPlayer p : arenaPlayers()) {
            HHNetwork.sendTo(p, results);
            p.sendSystemMessage(link);
        }
        announce(tr(win == Side.HIDER ? "msg.hiders_win" : "msg.hunters_win").withStyle(win.color, ChatFormatting.BOLD)
                .append(Component.literal(" ")).append(reason.copy().withStyle(ChatFormatting.GRAY)));
        if (!results.bestHider().isEmpty()) announce(tr("msg.best_hider", results.bestHider(), clock(results.bestHiderSec())).withStyle(ChatFormatting.GREEN));
        if (!results.topHunter().isEmpty()) announce(tr("msg.top_hunter", results.topHunter(), results.topHunterCatches()).withStyle(ChatFormatting.RED));
        if (s.getBool(GameSettings.SIDEBAR)) TeamDisplay.updateSidebar(server, aliveHiders(), huntersCount(false), 0, caughtCount());
        syncAll();
    }

    /** Clickable chat line that re-opens the results screen. */
    private static Component resultsLink() {
        return prefixed(tr("msg.results_link").withStyle(style -> style.withColor(ChatFormatting.AQUA).withUnderlined(true)
                .withClickEvent(new ClickEvent(ClickEvent.Action.RUN_COMMAND, "/hh results"))
                .withHoverEvent(new HoverEvent(HoverEvent.Action.SHOW_TEXT, tr("msg.results_link.hover")))));
    }

    /** /hh results: send the last round's results again. */
    public boolean sendLastResults(ServerPlayer p) {
        if (lastResults == null) return false;
        HHNetwork.sendTo(p, lastResults.asReopen());
        return true;
    }

    private int surviveSeconds(Participant p) {
        if (p.startSide != Side.HIDER) return 0;
        long end = p.caught ? p.caughtTick : roundEndTick;
        return (int) Math.max(0, (end - huntStartTick) / 20);
    }

    private ResultsPacket buildResults() {
        List<ResultsPacket.Entry> entries = new ArrayList<>();
        String bestHider = "", topHunter = "", mvp = "";
        int bestSec = -1, topCatches = 0, mvpPts = -1;
        for (Participant p : participants.values()) {
            boolean survived = p.startSide == Side.HIDER && !p.caught;
            int surv = surviveSeconds(p);
            boolean winningHunter = winner == Side.HUNTER && p.side == Side.HUNTER;
            int pts = p.catches * 20 + p.tauntPoints + (p.startSide == Side.HIDER ? surv / 5 : 0) + (survived ? 25 : 0)
                    + (winningHunter ? 25 : 0);
            entries.add(new ResultsPacket.Entry(p.name, p.startSide.ordinal(), p.side.ordinal(), p.catches, surv, p.caughtBy,
                    pts, p.taunts, survived));
            if (p.startSide == Side.HIDER && surv > bestSec) {
                bestSec = surv;
                bestHider = p.name;
            }
            if (p.catches > topCatches) {
                topCatches = p.catches;
                topHunter = p.name;
            }
            if (pts > mvpPts) {
                mvpPts = pts;
                mvp = p.name;
            }
        }
        entries.sort((a, b) -> Integer.compare(b.points(), a.points()));
        return new ResultsPacket(winner.ordinal(), (int) Math.max(0, (roundEndTick - huntStartTick) / 20), settings().infection(),
                entries, bestHider, Math.max(0, bestSec), topHunter, topCatches, mvp, data().name, false);
    }

    private void tickEnding() {
        if (fireworkBursts > 0 && tick % 15 == 0) {
            fireworkBursts--;
            int color = winner == Side.HIDER ? 0x55FF7F : 0xFF4444;
            int fade = winner == Side.HIDER ? 0xFFFF55 : 0xFFAA00;
            for (Participant part : participants.values()) {
                ServerPlayer p = online(part);
                if (p == null || p.isSpectator()) continue;
                boolean won = winner == Side.HUNTER ? part.side == Side.HUNTER : (part.side == Side.HIDER && !part.caught);
                if (!won) continue;
                Fx.firework(p.serverLevel(), p.getX() + random.nextGaussian(), p.getY() + 0.5, p.getZ() + random.nextGaussian(),
                        color, fade, random.nextInt(5), 1 + random.nextInt(2));
            }
        }
        if (bossBar != null) bossBar.setProgress(phaseTotalTicks <= 0 ? 0F : Math.max(0F, phaseTicks / (float) phaseTotalTicks));
        if (--phaseTicks <= 0) finishRound();
    }

    /** Restores everybody, sends them to the lobby and goes back to LOBBY. */
    private void finishRound() {
        ArenaData d = data();
        boolean reset = d.settings.getBool(GameSettings.RESET_TEAMS);
        for (Participant part : participants.values()) {
            ServerPlayer p = player(part.id);
            if (p != null) restorePlayer(p, reset);
        }
        if (reset) {
            for (UUID id : new ArrayList<>(d.sides.keySet())) {
                ServerPlayer p = player(id);
                if (p != null) TeamDisplay.assign(server, d, id, p.getScoreboardName(), Side.NONE);
            }
            d.sides.clear();
        }
        if (bossBar != null) {
            bossBar.removeAllPlayers();
            bossBar = null;
        }
        TeamDisplay.hideSidebar(server, d);
        TeamDisplay.removeEmptyTeams(server);
        participants.clear();
        outside.clear();
        pendingReturn.clear();
        testMode = false;
        phase = Phase.LOBBY;
        phaseTicks = phaseTotalTicks = 0;
        d.setDirty();
        syncAll();
    }

    /** Gives back the pre-round state and teleports to the lobby. */
    private void restorePlayer(ServerPlayer p, boolean resetTeam) {
        ArenaData d = data();
        CompoundTag snap = d.snapshots.remove(p.getUUID());
        setFrozen(p, false);
        if (snap != null) {
            PlayerSnapshot.restore(p, snap, !snap.getBoolean("keepInv"));
        } else {
            p.removeAllEffects();
            if (p.isSpectator()) p.setGameMode(GameType.SURVIVAL);
        }
        Side lobbySide = resetTeam ? Side.NONE : d.sideOf(p.getUUID());
        TeamDisplay.assign(server, d, p.getUUID(), p.getScoreboardName(), lobbySide);
        if (d.lobby != null) teleport(p, d.lobby);
        else if (snap != null) PlayerSnapshot.teleportBack(p, snap);
        d.setDirty();
    }

    /** Stops the game (command / tablet / server stop). Returns false if nothing was running. */
    public boolean stop(Component reason) {
        switch (phase) {
            case LOBBY:
                startAfterRandomizer = false;
                return false;
            case COUNTDOWN:
                participants.clear();
                testMode = false;
                phase = Phase.LOBBY;
                break;
            default:
                finishRound();
                break;
        }
        startAfterRandomizer = false;
        if (reason != null) announce(reason);
        syncAll();
        return true;
    }

    // ================================================================== connection / lifecycle events

    public void onLogin(ServerPlayer p) {
        ArenaData d = data();
        setFrozen(p, false);
        d.rememberName(p.getUUID(), p.getGameProfile().getName());
        Participant part = participants.get(p.getUUID());
        if (part != null && phase.inRound()) {
            part.online = true;
            part.name = p.getGameProfile().getName();
            rejoin(p, part);
        } else if (d.snapshots.containsKey(p.getUUID())) {
            restorePlayer(p, d.settings.getBool(GameSettings.RESET_TEAMS));
            p.sendSystemMessage(prefixed(tr("msg.restored").withStyle(ChatFormatting.GREEN)));
        } else {
            Side side = d.sideOf(p.getUUID());
            TeamDisplay.assign(server, d, p.getUUID(), p.getScoreboardName(), side);
        }
        syncTo(p);
    }

    private void rejoin(ServerPlayer p, Participant part) {
        if (bossBar != null) bossBar.addPlayer(p);
        if (phase == Phase.ENDING) return;
        // eliminated players come back as spectators (classic) or hunters (infection), others as they were
        prepare(p, part);
        p.sendSystemMessage(prefixed(tr("msg.rejoined", part.side.displayName())));
        needEndCheck = true;
    }

    public void onLogout(ServerPlayer p) {
        padCooldown.remove(p.getUUID());
        padRefused.remove(p.getUUID());
        showUntil.remove(p.getUUID());
        outside.remove(p.getUUID());
        pendingReturn.remove(p.getUUID());
        // onlookers in the arena were added to the boss bar too; don't keep stale player references
        if (bossBar != null) bossBar.removePlayer(p);
        Participant part = participants.get(p.getUUID());
        if (part == null) return;
        if (phase == Phase.COUNTDOWN) {
            participants.remove(p.getUUID());
            return;
        }
        if (!phase.inRound()) return;
        part.online = false;
        if ((phase == Phase.HIDING || phase == Phase.HUNTING) && part.side == Side.HIDER && !part.caught) {
            part.caught = true;
            part.caughtBy = "";
            part.caughtTick = tick;
            part.side = settings().infection() ? Side.HUNTER : Side.SPECTATOR;
            announce(tr("msg.hider_left", p.getDisplayName(), aliveHiders()).withStyle(ChatFormatting.GRAY));
        } else {
            announce(tr("msg.player_left", p.getDisplayName()).withStyle(ChatFormatting.GRAY));
        }
        // Give the player their own things back right now, so that the saved player file is clean even if
        // the server stops or the mod is removed before they come back.
        ArenaData d = data();
        setFrozen(p, false);
        CompoundTag snap = d.snapshots.remove(p.getUUID());
        if (snap != null) {
            PlayerSnapshot.restore(p, snap, !snap.getBoolean("keepInv"));
            if (d.lobby != null && p.level() == arenaLevel()) {
                p.teleportTo(d.lobby.x(), d.lobby.y(), d.lobby.z());
            }
            d.setDirty();
        }
        TeamDisplay.assign(server, d, p.getUUID(), p.getScoreboardName(), Side.NONE);
        needEndCheck = true;
    }

    public void onDimensionChange(ServerPlayer p) {
        if (inRound(p) && phase != Phase.ENDING && p.level() != arenaLevel()) pendingReturn.add(p.getUUID());
    }

    public void onRespawn(ServerPlayer p) {
        if (inRound(p)) pendingReturn.add(p.getUUID());
    }

    /** Called on ServerStoppingEvent: restore everybody who is still online. */
    public void onServerStopping() {
        if (phase != Phase.LOBBY) {
            stop(null);
        }
    }

    // ================================================================== main tick

    public void tick() {
        tick++;
        if (tick == 1) {
            // a crash mid-round leaves our sidebar objective (and maybe empty teams) in scoreboard.dat
            TeamDisplay.hideSidebar(server, data());
            TeamDisplay.removeEmptyTeams(server);
        }
        if (randomizerLock > 0) randomizerLock--;
        if (revealTicks > 0 && --revealTicks == 0) revealRandomizer();
        if (startAfterRandomizer && randomizerLock == 0) {
            startAfterRandomizer = false;
            Component err = tryStart(null);
            if (err != null) announce(err.copy().withStyle(ChatFormatting.RED));
        }
        if (!pendingReturn.isEmpty()) {
            for (UUID id : new ArrayList<>(pendingReturn)) {
                Participant part = participants.get(id);
                ServerPlayer p = player(id);
                if (part != null && p != null && phase.inRound()) {
                    if (p.isDeadOrDying()) continue;
                    if (part.side == Side.SPECTATOR) p.setGameMode(GameType.SPECTATOR);
                    teleport(p, spawnOf(part));
                }
                pendingReturn.remove(id);
            }
        }
        switch (phase) {
            case COUNTDOWN -> tickCountdown();
            case HIDING -> tickHiding();
            case HUNTING -> tickHunting();
            case ENDING -> tickEnding();
            default -> {}
        }
        if (needEndCheck && (phase == Phase.HIDING)) {
            needEndCheck = false;
            checkEnd();
        }
        if (tick % 5 == 0) scanPads();
        if (tick % 10 == 0) syncAll();
        if (tick % 10 == 0 && !showUntil.isEmpty()) tickMarkers();
    }

    // ================================================================== map-making markers (/hh show)

    public void show(ServerPlayer p, int seconds) {
        showUntil.put(p.getUUID(), tick + Math.max(1, seconds) * 20L);
        ArenaData d = data();
        if (p.level() != arenaLevel()) {
            Fx.actionBar(p, tr("msg.show_other_dim", d.dimension).withStyle(ChatFormatting.YELLOW));
        }
    }

    private void tickMarkers() {
        ArenaData d = data();
        ServerLevel level = arenaLevel();
        java.util.Iterator<Map.Entry<UUID, Long>> it = showUntil.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<UUID, Long> e = it.next();
            ServerPlayer p = player(e.getKey());
            if (p == null || tick > e.getValue()) {
                it.remove();
                continue;
            }
            if (p.level() != level) continue;
            marker(level, p, d.lobby, new Vector3f(1F, 1F, 1F));
            marker(level, p, d.spectator, new Vector3f(0.6F, 0.6F, 0.65F));
            for (SpawnPoint sp : d.hiderSpawns) marker(level, p, sp, new Vector3f(0.2F, 1F, 0.35F));
            for (SpawnPoint sp : d.hunterSpawns) marker(level, p, sp, new Vector3f(1F, 0.2F, 0.15F));
            if (d.hasBounds()) borderOutline(level, p, d);
        }
    }

    /** A glowing column at the spawn plus three dots showing the view direction. */
    private static void marker(ServerLevel level, ServerPlayer viewer, SpawnPoint sp, Vector3f color) {
        if (sp == null) return;
        DustParticleOptions dust = new DustParticleOptions(color, 1.2F);
        for (int i = 0; i < 6; i++) {
            level.sendParticles(viewer, dust, true, sp.x(), sp.y() + 0.1 + i * 0.4, sp.z(), 1, 0, 0, 0, 0);
        }
        double yaw = Math.toRadians(sp.yaw());
        double dx = -Math.sin(yaw), dz = Math.cos(yaw);
        DustParticleOptions dir = new DustParticleOptions(color, 0.7F);
        for (int i = 1; i <= 3; i++) {
            level.sendParticles(viewer, dir, true, sp.x() + dx * i * 0.35, sp.y() + 1.6, sp.z() + dz * i * 0.35, 1, 0, 0, 0, 0);
        }
    }

    private static void borderOutline(ServerLevel level, ServerPlayer viewer, ArenaData d) {
        double x0 = Math.min(d.cornerA.getX(), d.cornerB.getX()), x1 = Math.max(d.cornerA.getX(), d.cornerB.getX()) + 1;
        double z0 = Math.min(d.cornerA.getZ(), d.cornerB.getZ()), z1 = Math.max(d.cornerA.getZ(), d.cornerB.getZ()) + 1;
        double[] ys;
        if (d.boundsUseHeight()) {
            ys = new double[]{Math.min(d.cornerA.getY(), d.cornerB.getY()), Math.max(d.cornerA.getY(), d.cornerB.getY()) + 1};
        } else {
            ys = new double[]{viewer.getY() + 0.1, viewer.getY() + 2.0}; // "whole height": show it around the viewer
        }
        double perimeter = 2 * ((x1 - x0) + (z1 - z0));
        double step = Math.max(1.0, perimeter / 240.0);
        DustParticleOptions dust = new DustParticleOptions(new Vector3f(1F, 0.75F, 0.1F), 1.0F);
        for (double y : ys) {
            for (double x = x0; x <= x1; x += step) {
                level.sendParticles(viewer, dust, true, x, y, z0, 1, 0, 0, 0, 0);
                level.sendParticles(viewer, dust, true, x, y, z1, 1, 0, 0, 0, 0);
            }
            for (double z = z0; z <= z1; z += step) {
                level.sendParticles(viewer, dust, true, x0, y, z, 1, 0, 0, 0, 0);
                level.sendParticles(viewer, dust, true, x1, y, z, 1, 0, 0, 0, 0);
            }
        }
        if (d.boundsUseHeight()) {
            double[][] corners = {{x0, z0}, {x0, z1}, {x1, z0}, {x1, z1}};
            for (double[] c : corners) {
                for (double y = ys[0]; y <= ys[1]; y += Math.max(1.0, step)) {
                    level.sendParticles(viewer, dust, true, c[0], y, c[1], 1, 0, 0, 0, 0);
                }
            }
        }
    }

    /** /hh removespawn: {@code which} is a 1-based number or "nearest". */
    public Component removeSpawn(ServerPlayer p, Side side, String which) {
        ArenaData d = data();
        List<SpawnPoint> list = side == Side.HUNTER ? d.hunterSpawns : d.hiderSpawns;
        Component label = tr(side == Side.HUNTER ? "spawn.hunters" : "spawn.hiders");
        if (list.isEmpty()) return tr("msg.no_spawn", label);
        int idx = -1;
        if ("nearest".equalsIgnoreCase(which)) {
            if (p == null) return tr("msg.bad_value", "which", which);
            double best = Double.MAX_VALUE;
            for (int i = 0; i < list.size(); i++) {
                double ds = list.get(i).distSqr(p.getX(), p.getY(), p.getZ());
                if (ds < best) {
                    best = ds;
                    idx = i;
                }
            }
        } else {
            try {
                idx = Integer.parseInt(which) - 1;
            } catch (NumberFormatException ignored) {
            }
        }
        if (idx < 0 || idx >= list.size()) return tr("msg.bad_value", "#", which);
        SpawnPoint removed = list.remove(idx);
        d.setDirty();
        return tr("msg.spawn_removed", label, idx + 1, removed.shortString(), list.size());
    }

    /** Border message with the box size; explains the "whole height" rule for flat corners. */
    public static Component boundsMessage(ArenaData d) {
        if (!d.hasBounds()) return tr("msg.bounds_partial");
        return tr(d.boundsUseHeight() ? "msg.bounds_set" : "msg.bounds_set_flat",
                d.cornerA.toShortString(), d.cornerB.toShortString(), d.boundsSizeText());
    }

    // ================================================================== client sync

    public void syncAll() {
        // lobby counts are the same for everybody: compute them once instead of once per player (O(n^2))
        int[] counts = lobbyCounts();
        for (ServerPlayer p : server.getPlayerList().getPlayers()) HHNetwork.sendTo(p, buildState(p, counts));
    }

    public void syncTo(ServerPlayer p) {
        HHNetwork.sendTo(p, buildState(p, null));
    }

    private int[] lobbyCounts() {
        int[] c = new int[3];
        if (phase == Phase.LOBBY || phase == Phase.COUNTDOWN) {
            ArenaData d = data();
            for (ServerPlayer p : lobbyCandidates()) {
                Side s = d.sideOf(p.getUUID());
                c[s == Side.HIDER ? 0 : s == Side.HUNTER ? 1 : 2]++;
            }
        }
        return c;
    }

    private StatePacket buildState(ServerPlayer p, int[] counts) {
        ArenaData d = data();
        Participant part = participants.get(p.getUUID());
        boolean inArena = p.level() == arenaLevel();
        boolean configured = d.lobby != null || !d.hiderSpawns.isEmpty() || !d.hunterSpawns.isEmpty();
        boolean visible = part != null || (inArena && configured) || (inArena && phase != Phase.LOBBY);
        if (!visible) return StatePacket.hidden();
        if (counts == null) counts = lobbyCounts();
        int lh = counts[0], lk = counts[1], ln = counts[2];
        Side side = part != null ? part.side : d.sideOf(p.getUUID());
        int tauntCd = 0;
        if (part != null) {
            long wait = part.lastTaunt + d.settings.getInt(GameSettings.TAUNT_COOLDOWN) * 20L - tick;
            tauntCd = (int) Math.max(0, (wait + 19) / 20);
        }
        return new StatePacket(true, phase.ordinal(), side.ordinal(), part != null && !part.caught, secondsLeft(),
                phaseTotalTicks / 20, aliveHiders(), hidersTotal(), huntersCount(false), lh, lk, ln, d.name,
                d.settings.infection(), tauntCd, d.settings.getBool(GameSettings.TAUNTS), d.settings.joinMode().ordinal());
    }

    // ================================================================== tablet

    public void openTablet(ServerPlayer p) {
        if (!p.hasPermissions(2)) {
            Fx.actionBar(p, tr("msg.no_permission").withStyle(ChatFormatting.RED));
            return;
        }
        HHNetwork.sendTo(p, new TabletDataPacket(buildTabletData(), true));
    }

    public CompoundTag buildTabletData() {
        ArenaData d = data();
        CompoundTag t = new CompoundTag();
        t.putString("name", d.name);
        t.putString("dim", d.dimension);
        t.putInt("phase", phase.ordinal());
        t.putString("lobby", d.lobby == null ? "" : d.lobby.shortString());
        t.putString("spectator", d.spectator == null ? "" : d.spectator.shortString());
        t.putInt("hiderSpawns", d.hiderSpawns.size());
        t.putInt("hunterSpawns", d.hunterSpawns.size());
        t.putString("cornerA", d.cornerA == null ? "" : d.cornerA.toShortString());
        t.putString("cornerB", d.cornerB == null ? "" : d.cornerB.toShortString());
        t.putInt("hiderKit", d.hiderKit.size());
        t.putInt("hunterKit", d.hunterKit.size());
        t.putInt("rounds", d.roundsPlayed);
        t.put("settings", d.settings.save());
        ListTag roster = new ListTag();
        for (ServerPlayer p : server.getPlayerList().getPlayers()) {
            CompoundTag r = new CompoundTag();
            r.putUUID("id", p.getUUID());
            r.putString("name", p.getGameProfile().getName());
            Participant part = participants.get(p.getUUID());
            r.putInt("side", (part != null ? part.side : d.sideOf(p.getUUID())).ordinal());
            r.putBoolean("inArena", p.level() == arenaLevel());
            roster.add(r);
        }
        t.put("roster", roster);
        return t;
    }

    public void handleTabletAction(ServerPlayer p, String action, String key, String value) {
        if (!p.hasPermissions(2)) {
            Fx.actionBar(p, tr("msg.no_permission").withStyle(ChatFormatting.RED));
            return;
        }
        ArenaData d = data();
        Component feedback = null;
        switch (action) {
            case "set" -> {
                if (d.settings.set(key, value)) {
                    d.setDirty();
                    TeamDisplay.ensureTeams(server, d.settings);
                } else {
                    feedback = tr("msg.bad_value", key, value).withStyle(ChatFormatting.RED);
                }
            }
            case "name" -> {
                String n = value.trim();
                if (!n.isEmpty()) {
                    d.name = n.length() > 32 ? n.substring(0, 32) : n;
                    d.setDirty();
                    feedback = tr("msg.renamed", d.name);
                }
            }
            case "spawn" -> feedback = setSpawnHere(p, key);
            case "bounds" -> {
                BlockPos pos = p.blockPosition();
                switch (key) {
                    case "pos1" -> d.cornerA = pos;
                    case "pos2" -> d.cornerB = pos;
                    default -> {
                        d.cornerA = null;
                        d.cornerB = null;
                    }
                }
                d.setDirty();
                feedback = boundsMessage(d);
            }
            case "team" -> {
                Side side = Side.parse(value);
                try {
                    UUID id = UUID.fromString(key);
                    ServerPlayer target = player(id);
                    if (side != null) {
                        Component err = adminSetSide(id, target != null ? target.getGameProfile().getName() : d.names.getOrDefault(id, "?"), side);
                        if (err != null) feedback = err;
                    }
                } catch (IllegalArgumentException ignored) {
                }
            }
            case "game" -> {
                switch (key) {
                    case "start" -> feedback = tryStart(p);
                    case "stop" -> {
                        if (!stop(tr("msg.stopped_by", p.getDisplayName()).withStyle(ChatFormatting.RED))) feedback = tr("msg.not_running");
                    }
                    case "randomize" -> feedback = randomize(p);
                    case "reset_teams" -> {
                        if (phase == Phase.LOBBY) {
                            resetTeams();
                            feedback = tr("msg.teams_reset");
                        } else feedback = tr("msg.game_running");
                    }
                    case "tp_lobby" -> {
                        if (d.lobby != null) teleport(p, d.lobby);
                    }
                    case "show" -> {
                        show(p, 30);
                        feedback = tr("msg.show_on", 30);
                    }
                    case "test" -> feedback = tryStart(p, true);
                    default -> {}
                }
            }
            case "kit" -> {
                Side side = Side.parse(key);
                if (side == Side.HIDER || side == Side.HUNTER) {
                    if ("set".equals(value)) feedback = tr("msg.kit_saved", side.pluralName(), captureKit(p, side));
                    else {
                        d.setKit(side, new ListTag());
                        feedback = tr("msg.kit_cleared", side.pluralName());
                    }
                }
            }
            default -> {}
        }
        if (feedback != null) p.sendSystemMessage(prefixed(feedback));
        HHNetwork.sendTo(p, new TabletDataPacket(buildTabletData(), false));
        syncAll();
    }

    /** which: lobby, spectator, hider_add, hunter_add, hider_set, hunter_set, hider_clear, hunter_clear. */
    public Component setSpawnHere(ServerPlayer p, String which) {
        // snap to the block centre so players don't spawn half inside a wall
        SpawnPoint sp = new SpawnPoint(Math.floor(p.getX()) + 0.5, p.getY(), Math.floor(p.getZ()) + 0.5, p.getYRot(), p.getXRot());
        return setSpawn(p.serverLevel(), sp, which);
    }

    public Component setSpawn(ServerLevel level, SpawnPoint sp, String which) {
        ArenaData d = data();
        String dim = level.dimension().location().toString();
        if (phase != Phase.LOBBY && (which.equals("lobby") || !dim.equals(d.dimension))) {
            // the arena dimension and the lobby are what everybody gets teleported to: don't move them mid-round
            return tr("msg.locked_in_round").withStyle(ChatFormatting.RED);
        }
        Component msg;
        switch (which) {
            case "lobby" -> {
                d.lobby = sp;
                d.dimension = dim;
                msg = tr("msg.spawn_set", tr("spawn.lobby"), sp.shortString());
            }
            case "spectator" -> {
                d.spectator = sp;
                msg = tr("msg.spawn_set", tr("spawn.spectator"), sp.shortString());
            }
            case "hider_set", "hider_add" -> {
                if (which.endsWith("set")) d.hiderSpawns.clear();
                d.hiderSpawns.add(sp);
                if (d.lobby == null) d.dimension = dim;
                msg = tr("msg.spawn_added", tr("spawn.hiders"), sp.shortString(), d.hiderSpawns.size());
            }
            case "hunter_set", "hunter_add" -> {
                if (which.endsWith("set")) d.hunterSpawns.clear();
                d.hunterSpawns.add(sp);
                if (d.lobby == null) d.dimension = dim;
                msg = tr("msg.spawn_added", tr("spawn.hunters"), sp.shortString(), d.hunterSpawns.size());
            }
            case "hider_clear" -> {
                d.hiderSpawns.clear();
                msg = tr("msg.spawns_cleared", tr("spawn.hiders"));
            }
            case "hunter_clear" -> {
                d.hunterSpawns.clear();
                msg = tr("msg.spawns_cleared", tr("spawn.hunters"));
            }
            default -> {
                return tr("msg.bad_value", "spawn", which);
            }
        }
        if (!dim.equals(d.dimension)) {
            msg = msg.copy().append(Component.literal(" ")).append(tr("msg.dim_warning", d.dimension).withStyle(ChatFormatting.RED));
        }
        d.setDirty();
        level.sendParticles(ParticleTypes.END_ROD, sp.x(), sp.y() + 1.0, sp.z(), 20, 0.3, 0.6, 0.3, 0.02);
        return msg;
    }

    // ================================================================== status

    public List<Component> statusLines() {
        ArenaData d = data();
        List<Component> out = new ArrayList<>();
        out.add(Component.literal("══ ").withStyle(ChatFormatting.DARK_GRAY)
                .append(Component.literal(d.name).withStyle(ChatFormatting.GOLD, ChatFormatting.BOLD))
                .append(Component.literal(" ══").withStyle(ChatFormatting.DARK_GRAY)));
        out.add(tr("status.phase", phase.displayName().withStyle(ChatFormatting.YELLOW),
                phase == Phase.LOBBY ? Component.literal("-") : Component.literal(clock(secondsLeft()))));
        out.add(tr("status.mode", tr("choice.mode." + d.settings.getChoice(GameSettings.MODE)).withStyle(ChatFormatting.AQUA),
                tr("choice.join_mode." + d.settings.getChoice(GameSettings.JOIN_MODE)).withStyle(ChatFormatting.AQUA)));
        if (phase.inRound()) {
            out.add(tr("status.round", aliveHiders(), hidersTotal(), huntersCount(false)));
        } else {
            out.add(tr("status.lobby", countLobby(Side.HIDER), countLobby(Side.HUNTER), countLobby(Side.NONE)));
        }
        out.add(tr("status.spawns", d.lobby != null ? "✔" : "✖", d.hiderSpawns.size(), d.hunterSpawns.size(),
                d.spectator != null ? "✔" : "✖", d.hasBounds() ? "✔" : "✖"));
        return out;
    }
}
