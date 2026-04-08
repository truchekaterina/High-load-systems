package rental.repository;

import org.springframework.stereotype.Repository;
import org.springframework.util.ObjectUtils;
import rental.exception.EntityException;
import rental.model.Client;

import java.util.*;

import static java.lang.String.format;

@Repository
public class ClientRepository {

    public static final String CLIENT_NOT_FOUND_MSG = "Client with ID %s not found";
    public static final String CLIENT_EXISTS_MSG = "Client with ID %s already exists";

    private static final Map<UUID, Client> clients = new HashMap<>();

    public List<Client> findAll() {
        return new ArrayList<>(clients.values());
    }

    public Client findById(UUID id) {
        final var client = clients.get(id);
        if (client == null) {
            throw new EntityException(format(CLIENT_NOT_FOUND_MSG, id));
        }
        return client;
    }

    public void delete(UUID id) {
        final var removed = clients.remove(id);
        if (removed == null) {
            throw new EntityException(format(CLIENT_NOT_FOUND_MSG, id));
        }
    }

    public Client save(Client client) {
        if (ObjectUtils.isEmpty(client.getId())) {
            client.setId(UUID.randomUUID());
        }

        final var existing = clients.get(client.getId());
        if (existing != null) {
            throw new EntityException(format(CLIENT_EXISTS_MSG, client.getId()));
        }

        clients.put(client.getId(), client);
        return client;
    }

    public Client put(Client client) {
        final var existing = clients.get(client.getId());
        if (existing == null) {
            throw new EntityException(format(CLIENT_NOT_FOUND_MSG, client.getId()));
        }

        clients.remove(client.getId());
        clients.put(client.getId(), client);
        return client;
    }

    public void clear() {
        clients.clear();
    }
}
