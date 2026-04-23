package rental;

import java.util.Locale;

/**
 * Режим очистки для LAB5: полная БД либо подмножество таблиц с учётом внешних ключей.
 * <p>
 * Параметр query {@code clear}: {@code all|rents|cars|clients} (имена таблиц/сущностей); в обработчке
 * сначала превращается в этот enum, чтобы сервис не сравнивал строки везде
 * и чтобы опечатка в параметре сразу давала 400, а не «тихо» full wipe.
 */
public enum ClearTarget {
    /** Все таблицы: rents → cars → clients */
    ALL,
    /** Только аренды (машины и клиенты остаются). */
    RENTS,
    /**
     * Аренды + машины. Клиенты остаются; порядок: сначала rents (FK на cars), потом cars.
     */
    CARS,
    /**
     * Аренды + клиенты. Машины остаются; порядок: сначала rents (FK на clients), потом clients.
     */
    CLIENTS;

    /**
     * Парсит {@code @RequestParam("clear")}: пусто → {@link #ALL};
     * иначе одно из четырёх заранее оговорённых слов. Любое другое — исключение
     * (дальше {@code DevController} отдаст {@code 400 Bad Request}).
     */
    public static ClearTarget fromQuery(String raw) {
        if (raw == null || raw.isBlank()) {
            // POST /dev/clear без query — «как clear=all»
            return ALL;
        }
        String s = raw.trim().toLowerCase(Locale.ROOT);
        return switch (s) {
            case "all" -> ALL;
            case "rents" -> RENTS;
            case "cars" -> CARS;
            case "clients" -> CLIENTS;
            default -> throw new IllegalArgumentException(
                    "clear must be all, rents, cars, or clients, got: " + raw);
        };
    }
}
