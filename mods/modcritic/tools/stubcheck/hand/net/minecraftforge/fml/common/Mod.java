package net.minecraftforge.fml.common;
import java.lang.annotation.*;
@Retention(RetentionPolicy.RUNTIME) @Target(ElementType.TYPE)
public @interface Mod {
    String value();
    @Retention(RetentionPolicy.RUNTIME) @Target(ElementType.TYPE)
    @interface EventBusSubscriber {
        net.minecraftforge.api.distmarker.Dist[] value() default { net.minecraftforge.api.distmarker.Dist.CLIENT, net.minecraftforge.api.distmarker.Dist.DEDICATED_SERVER };
        String modid() default "";
        Bus bus() default Bus.FORGE;
        enum Bus { FORGE, MOD }
    }
}
