package com.mojang.brigadier.arguments;
public class IntegerArgumentType implements ArgumentType<Integer> { public static IntegerArgumentType integer(int a, int b) { return null; } public static int getInteger(com.mojang.brigadier.context.CommandContext<?> c, String n) { return 0; } }
