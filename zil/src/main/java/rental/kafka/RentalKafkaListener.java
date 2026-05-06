package rental.kafka;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;
import rental.kafka.dto.KafkaInboundCommand;

import java.util.List;

@Component
public class RentalKafkaListener {

    private static final Logger log = LoggerFactory.getLogger(RentalKafkaListener.class);

    private final ObjectMapper objectMapper;
    private final KafkaRentalCommandRouter commandRouter;

    public RentalKafkaListener(ObjectMapper objectMapper, KafkaRentalCommandRouter commandRouter) {
        this.objectMapper = objectMapper;
        this.commandRouter = commandRouter;
    }

    /**
     * {@code concurrency} — число потоков; не превышайте число партиций топика (см. LAB12/LAB13).
     * LAB13: batch listener — партия строк JSON из одного poll; ошибка в одном сообщении не отменяет
     * остальные (логируем и идём дальше — политика зафиксирована для отчёта).
     */
    @KafkaListener(
            topics = "${app.kafka.topic}",
            groupId = "${spring.kafka.consumer.group-id}",
            containerFactory = "kafkaListenerContainerFactory",
            concurrency = "${app.kafka.listener.concurrency}")
    public void consume(List<String> messages) {
        if (messages == null || messages.isEmpty()) {
            return;
        }
        log.trace("Kafka batch size={}", messages.size());
        for (String message : messages) {
            processOne(message);
        }
    }

    private void processOne(String message) {
        try {
            KafkaInboundCommand command = objectMapper.readValue(message, KafkaInboundCommand.class);
            commandRouter.dispatch(command.entity(), command.operation(), command.payload());
            log.debug("Processed Kafka message entity={} operation={}", command.entity(), command.operation());
        } catch (JacksonException ex) {
            log.error("Invalid JSON in Kafka message: {}", message, ex);
        } catch (Exception ex) {
            log.error("Failed to handle Kafka message: {}", message, ex);
        }
    }
}
