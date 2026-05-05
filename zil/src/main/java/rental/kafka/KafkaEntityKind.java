package rental.kafka;

import java.util.Locale;

enum KafkaEntityKind {
    CLIENT,
    CAR;

    static KafkaEntityKind fromMessage(String raw) {
        if (raw == null || raw.isBlank()) {
            throw new IllegalArgumentException("entity must not be blank");
        }
        String u = raw.trim().toUpperCase(Locale.ROOT);
        if ("USER".equals(u)) {
            return CLIENT;
        }
        return KafkaEntityKind.valueOf(u);
    }
}
