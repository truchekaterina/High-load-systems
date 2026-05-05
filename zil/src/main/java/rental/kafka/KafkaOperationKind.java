package rental.kafka;

import java.util.Locale;

enum KafkaOperationKind {
    POST,
    DEL;

    static KafkaOperationKind fromMessage(String raw) {
        if (raw == null || raw.isBlank()) {
            throw new IllegalArgumentException("operation must not be blank");
        }
        return KafkaOperationKind.valueOf(raw.trim().toUpperCase(Locale.ROOT));
    }
}
