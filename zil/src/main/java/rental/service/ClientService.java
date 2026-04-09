package rental.service;

import org.springframework.util.ObjectUtils;
import rental.exception.EntityException;
import rental.exception.EntityMessages;
import rental.model.Client;
import rental.repository.ClientRepository;

import java.util.List;
import java.util.UUID;

import static java.lang.String.format;

public class ClientService {

    private final ClientRepository clientRepository;

    public ClientService(ClientRepository clientRepository) {
        this.clientRepository = clientRepository;
    }

    public List<Client> getAllClients() {
        return clientRepository.findAll();
    }

    public Client getClientById(String id) {
        UUID uuid = UUID.fromString(id);
        return clientRepository.findById(uuid)
                .orElseThrow(() -> new EntityException(format(EntityMessages.CLIENT_NOT_FOUND_MSG, uuid)));
    }

    public Client saveClient(Client client) {
        if (!ObjectUtils.isEmpty(client.getId()) && clientRepository.existsById(client.getId())) {
            throw new EntityException(format(EntityMessages.CLIENT_EXISTS_MSG, client.getId()));
        }
        return clientRepository.save(client);
    }

    public void deleteClient(String id) {
        UUID uuid = UUID.fromString(id);
        if (!clientRepository.existsById(uuid)) {
            throw new EntityException(format(EntityMessages.CLIENT_NOT_FOUND_MSG, uuid));
        }
        clientRepository.deleteById(uuid);
    }

    public Client updateClient(String id, Client client) {
        UUID uuid = UUID.fromString(id);
        Client existing = clientRepository.findById(uuid)
                .orElseThrow(() -> new EntityException(format(EntityMessages.CLIENT_NOT_FOUND_MSG, uuid)));
        existing.setFullName(client.getFullName());
        existing.setDriverLicense(client.getDriverLicense());
        existing.setPhone(client.getPhone());
        return clientRepository.save(existing);
    }
}
