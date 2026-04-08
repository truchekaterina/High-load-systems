package rental.service;

import rental.model.Client;
import rental.repository.ClientRepository;

import java.util.List;
import java.util.UUID;

public class ClientService {

    private final ClientRepository clientRepository;

    public ClientService(ClientRepository clientRepository) {
        this.clientRepository = clientRepository;
    }

    public List<Client> getAllClients() {
        return clientRepository.findAll();
    }

    public Client getClientById(String id) {
        return clientRepository.findById(UUID.fromString(id));
    }

    public Client saveClient(Client client) {
        return clientRepository.save(client);
    }

    public void deleteClient(String id) {
        clientRepository.delete(UUID.fromString(id));
    }

    public Client updateClient(String id, Client client) {
        client.setId(UUID.fromString(id));
        return clientRepository.put(client);
    }
}
