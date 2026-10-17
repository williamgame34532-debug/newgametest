package com.zone19.scp.story;

import com.zone19.scp.world.ZoneLayout;
import net.minecraft.core.BlockPos;

import java.util.List;

/**
 * The campaign script: six chapters of one security shift at Site-19.
 * All text lives in the lang files under dlg.scpzone19.* and obj.scpzone19.*.
 */
public final class Chapters {
    public enum StepType { REGION, INTERACT, KILL }

    public record Line(String speaker, String key) {
    }

    public record Step(StepType type, String target, int count, String objective, BlockPos waypoint, List<Line> done) {
    }

    public record Chapter(int number, String music, List<Line> intro, List<Step> steps, List<Line> outro) {
        public String titleKey() {
            return "chapter.scpzone19." + number + ".title";
        }

        public String subtitleKey() {
            return "chapter.scpzone19." + number + ".subtitle";
        }
    }

    public static final String HARRIS = "harris", CASSIE = "cassie", LIN = "lin", VANCE = "vance", MTF = "mtf";

    private static Line l(String speaker, String key) {
        return new Line(speaker, "dlg.scpzone19." + key);
    }

    private static Step region(String region, String obj, Line... done) {
        return new Step(StepType.REGION, region, 1, "obj.scpzone19." + obj, ZoneLayout.regionCenter(region), List.of(done));
    }

    private static Step interact(String kind, int count, String obj, BlockPos wp, Line... done) {
        return new Step(StepType.INTERACT, kind, count, "obj.scpzone19." + obj, wp, List.of(done));
    }

    private static Step kill(String entity, int count, String obj, BlockPos wp, Line... done) {
        return new Step(StepType.KILL, entity, count, "obj.scpzone19." + obj, wp, List.of(done));
    }

    public static final List<Chapter> ALL = List.of(
            new Chapter(1, "intro",
                    List.of(l(HARRIS, "c1.i1"), l(HARRIS, "c1.i2"), l(HARRIS, "c1.i3")),
                    List.of(region("armory", "c1.armory"),
                            interact("armory", 1, "c1.locker", ZoneLayout.ARMORY_LOCKERS[1], l(HARRIS, "c1.kit")),
                            region("lcz_checkpoint", "c1.checkpoint")),
                    List.of(l(HARRIS, "c1.o1"))),
            new Chapter(2, "",
                    List.of(l(CASSIE, "c2.i1"), l(HARRIS, "c2.i2")),
                    List.of(region("control_room", "c2.control", l(LIN, "c2.s1")),
                            interact("control_console", 1, "c2.console", ZoneLayout.CONTROL_CONSOLES[1])),
                    List.of(l(LIN, "c2.o1"), l(LIN, "c2.o2"), l(HARRIS, "c2.o3"))),
            new Chapter(3, "hcz",
                    List.of(l(LIN, "c3.i1"), l(HARRIS, "c3.i2")),
                    List.of(kill("scp049_2", 6, "c3.kill", ZoneLayout.HCZ_HALL.center(), l(HARRIS, "c3.s1")),
                            region("medbay", "c3.medbay", l(VANCE, "c3.s2")),
                            interact("medical", 1, "c3.cabinet", ZoneLayout.MEDICAL_CABINET)),
                    List.of(l(VANCE, "c3.o1"), l(HARRIS, "c3.o2"))),
            new Chapter(4, "",
                    List.of(l(CASSIE, "c4.i1"), l(VANCE, "c4.i2"), l(VANCE, "c4.i3")),
                    List.of(interact("recontain", 3, "c4.terminals", ZoneLayout.RECONTAIN_TERMINALS[0], l(CASSIE, "c4.s1")),
                            region("chamber_173", "c4.chamber")),
                    List.of(l(CASSIE, "c4.o1"), l(HARRIS, "c4.o2"))),
            new Chapter(5, "scp106",
                    List.of(l(LIN, "c5.i1"), l(HARRIS, "c5.i2"), l(HARRIS, "c5.i3")),
                    List.of(interact("generator", 2, "c5.generators", ZoneLayout.GENERATORS_POS[0], l(LIN, "c5.s1")),
                            interact("femur_breaker", 1, "c5.femur", ZoneLayout.FEMUR_BREAKER)),
                    List.of(l(HARRIS, "c5.o1"), l(CASSIE, "c5.o2"))),
            new Chapter(6, "gateb",
                    List.of(l(CASSIE, "c6.i1"), l(HARRIS, "c6.i2"), l(HARRIS, "c6.i3")),
                    List.of(interact("o5_safe", 1, "c6.safe", ZoneLayout.O5_SAFE, l(HARRIS, "c6.s1")),
                            region("gate_exit", "c6.gate")),
                    List.of(l(MTF, "c6.o1"), l(HARRIS, "c6.o2"), l(HARRIS, "c6.o3")))
    );

    public static final int COUNT = ALL.size();

    public static Chapter get(int number) {
        return ALL.get(Math.max(1, Math.min(COUNT, number)) - 1);
    }

    private Chapters() {
    }
}
