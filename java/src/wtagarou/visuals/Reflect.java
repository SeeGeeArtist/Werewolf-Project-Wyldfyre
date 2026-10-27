package wtagarou.visuals;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.concurrent.ConcurrentHashMap;

/** Access only fields/methods evidenced in the pinned B42.20.2 reference.
 * No game classes are shipped. Failure is reported, not mistaken for success. */
public final class Reflect {
    private static final ClassValue<ConcurrentHashMap<String,Field>> FIELDS =
            new ClassValue<>() {
                protected ConcurrentHashMap<String,Field> computeValue(Class<?> type) {
                    return new ConcurrentHashMap<>();
                }
            };
    private static final ClassValue<ConcurrentHashMap<String,Method>> METHODS =
            new ClassValue<>() {
                protected ConcurrentHashMap<String,Method> computeValue(Class<?> type) {
                    return new ConcurrentHashMap<>();
                }
            };
    public static Field field(Class<?> type, String name) throws ReflectiveOperationException {
        Field cached=FIELDS.get(type).get(name);
        if (cached != null) return cached;
        for (Class<?> c = type; c != null; c = c.getSuperclass()) {
            try {
                Field f = c.getDeclaredField(name);
                f.setAccessible(true);
                FIELDS.get(type).put(name,f);
                return f;
            } catch (NoSuchFieldException ignored) {}
        }
        throw new NoSuchFieldException(type.getName() + "." + name);
    }
    public static Object get(Object target, String name) throws ReflectiveOperationException {
        return field(target.getClass(), name).get(target);
    }
    public static void set(Object target, String name, Object value) throws ReflectiveOperationException {
        field(target.getClass(), name).set(target, value);
    }
    public static Object call(Object target, String name) throws ReflectiveOperationException {
        Method method=METHODS.get(target.getClass()).get(name);
        if(method==null) {
            method=target.getClass().getMethod(name);
            METHODS.get(target.getClass()).put(name,method);
        }
        return method.invoke(target);
    }
    public static Object call(Object target, String name, Class<?>[] types, Object... values)
            throws ReflectiveOperationException {
        StringBuilder key=new StringBuilder(name).append('(');
        for (Class<?> t : types) key.append(t.getName()).append(',');
        Method method=METHODS.get(target.getClass()).get(key.toString());
        if(method==null) {
            method=target.getClass().getMethod(name,types);
            METHODS.get(target.getClass()).put(key.toString(),method);
        }
        return method.invoke(target,values);
    }
    public static Object call(Object target, String name, Class<?> type, Object value)
            throws ReflectiveOperationException {
        String key=name+"("+type.getName()+")";
        Method method=METHODS.get(target.getClass()).get(key);
        if(method==null) {
            method=target.getClass().getMethod(name,type);
            METHODS.get(target.getClass()).put(key,method);
        }
        return method.invoke(target,value);
    }
}
