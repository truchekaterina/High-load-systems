package rental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import rental.model.Client;
import rental.observability.ObservabilityService;
import rental.service.ClientService;

import java.util.List;

@RestController
public class ClientController {

    private final ClientService clientService;
    private final ObservabilityService observabilityService;

    @Autowired
    public ClientController(ClientService clientService, ObservabilityService observabilityService) {
        this.clientService = clientService;
        this.observabilityService = observabilityService;
    }

    @GetMapping("/clients")
    public List<Client> getClients() {
        return observabilityService.timed("web.ClientController.getClients", clientService::getAllClients);
    }

    @GetMapping("/clients/{id}")
    public Client getClientById(@PathVariable String id) {
        return observabilityService.timed("web.ClientController.getClientById", () -> clientService.getClientById(id));
    }

    @DeleteMapping("/clients/{id}")
    public void deleteClient(@PathVariable String id) {
        observabilityService.runTimed("web.ClientController.deleteClient", () -> clientService.deleteClient(id));
    }

    @PostMapping("/clients")
    public Client saveClient(@RequestBody Client client) {
        return observabilityService.timed("web.ClientController.saveClient", () -> clientService.saveClient(client));
    }

    @PutMapping("/clients/{id}")
    public Client updateClient(@PathVariable String id, @RequestBody Client client) {
        return observabilityService.timed(
                "web.ClientController.updateClient", () -> clientService.updateClient(id, client));
    }
}
