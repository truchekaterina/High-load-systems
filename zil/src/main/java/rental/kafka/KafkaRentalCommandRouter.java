package rental.kafka;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import rental.model.Car;
import rental.model.Client;
import rental.service.CarService;
import rental.service.ClientService;

@Service
public class KafkaRentalCommandRouter {

    private static final Logger log = LoggerFactory.getLogger(KafkaRentalCommandRouter.class);

    private final ObjectMapper objectMapper;
    private final ClientService clientService;
    private final CarService carService;

    public KafkaRentalCommandRouter(
            ObjectMapper objectMapper, ClientService clientService, CarService carService) {
        this.objectMapper = objectMapper;
        this.clientService = clientService;
        this.carService = carService;
    }

    /**
     * Маршрутизация по паре (entity, operation) в доменные сервисы.
     */
    public void dispatch(String entity, String operation, JsonNode payload) {
        KafkaEntityKind kind = KafkaEntityKind.fromMessage(entity);
        KafkaOperationKind op = KafkaOperationKind.fromMessage(operation);
        log.info("Kafka command: entity={}, operation={}", kind, op);
        switch (kind) {
            case CLIENT -> dispatchClient(op, payload);
            case CAR -> dispatchCar(op, payload);
        }
    }

    private void dispatchClient(KafkaOperationKind op, JsonNode payload) {
        switch (op) {
            case POST -> {
                JsonNode body = requirePayloadNode(payload);
                Client client = objectMapper.treeToValue(body, Client.class);
                clientService.saveClient(client);
            }
            case DEL -> clientService.deleteClient(extractId(payload));
        }
    }

    private void dispatchCar(KafkaOperationKind op, JsonNode payload) {
        switch (op) {
            case POST -> {
                JsonNode body = requirePayloadNode(payload);
                Car car = objectMapper.treeToValue(body, Car.class);
                carService.saveCar(car);
            }
            case DEL -> carService.deleteCar(extractId(payload));
        }
    }

    private static JsonNode requirePayloadNode(JsonNode payload) {
        if (payload == null || payload.isNull()) {
            throw new IllegalArgumentException("payload is required for POST");
        }
        return payload;
    }

    /** Текстовый UUID, либо объект с полем {@code id}. */
    private static String extractId(JsonNode payload) {
        if (payload == null || payload.isNull()) {
            throw new IllegalArgumentException("payload is required for DEL");
        }
        if (payload.isTextual()) {
            return payload.asText().trim();
        }
        if (payload.isObject() && payload.hasNonNull("id")) {
            return payload.get("id").asText().trim();
        }
        throw new IllegalArgumentException("DEL payload must be textual id or object with \"id\"");
    }
}
