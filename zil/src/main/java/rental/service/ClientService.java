package rental.service;

import org.springframework.util.ObjectUtils;
import rental.exception.EntityException;
import rental.exception.EntityMessages;
import rental.model.Client;
import rental.observability.ObservabilityService;
import rental.repository.ClientRepository;

import java.util.List;
import java.util.UUID;

import static java.lang.String.format;

public class ClientService {

    private final ClientRepository clientRepository;
    private final ObservabilityService observabilityService;

    public ClientService(ClientRepository clientRepository, ObservabilityService observabilityService) {
        this.clientRepository = clientRepository;
        this.observabilityService = observabilityService;
    }

    public List<Client> getAllClients() {
        return observabilityService.timed("db.client.findAll", clientRepository::findAll);
    }

    public Client getClientById(String id) {
        UUID uuid = UUID.fromString(id);
        return observabilityService.timed(
                "db.client.findById",
                () -> clientRepository
                        .findById(uuid)
                        .orElseThrow(() -> new EntityException(format(EntityMessages.CLIENT_NOT_FOUND_MSG, uuid))));
    }

    public Client saveClient(Client client) {
        if (!ObjectUtils.isEmpty(client.getId())) {
            boolean exists = observabilityService.timed(
                    "db.client.existsById", () -> clientRepository.existsById(client.getId()));
            if (exists) {
                throw new EntityException(format(EntityMessages.CLIENT_EXISTS_MSG, client.getId()));
            }
        }
        return observabilityService.timed("db.client.save", () -> clientRepository.save(client));
    }

    public void deleteClient(String id) {
        UUID uuid = UUID.fromString(id);
        boolean exists =
                observabilityService.timed("db.client.existsById", () -> clientRepository.existsById(uuid));
        if (!exists) {
            throw new EntityException(format(EntityMessages.CLIENT_NOT_FOUND_MSG, uuid));
        }
        observabilityService.runTimed("db.client.deleteById", () -> clientRepository.deleteById(uuid));
    }

    public Client updateClient(String id, Client client) {
        UUID uuid = UUID.fromString(id);
        Client existing = observabilityService.timed(
                "db.client.findById",
                () -> clientRepository
                        .findById(uuid)
                        .orElseThrow(() -> new EntityException(format(EntityMessages.CLIENT_NOT_FOUND_MSG, uuid))));
        existing.setFullName(client.getFullName());
        existing.setDriverLicense(client.getDriverLicense());
        existing.setPhone(client.getPhone());
        return observabilityService.timed("db.client.save", () -> clientRepository.save(existing));
    }
}
