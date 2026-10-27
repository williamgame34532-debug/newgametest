package net.minecraftforge.eventbus.api;
public interface IEventBus { void register(Object o); <T extends Event> void addListener(java.util.function.Consumer<T> c); boolean post(Event e); }
