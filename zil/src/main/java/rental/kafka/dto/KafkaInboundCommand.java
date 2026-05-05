package rental.kafka.dto;

import tools.jackson.databind.JsonNode;

/**
 * Сообщение LAB12: тип сущности, операция и payload (объект или строка id).
 */
public record KafkaInboundCommand(String entity, String operation, JsonNode payload) {}
