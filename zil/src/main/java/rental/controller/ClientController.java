package rental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import rental.model.Client;
import rental.service.ClientService;

import java.util.List;

@RestController
public class ClientController {

    private final ClientService clientService;

    @Autowired
    public ClientController(ClientService clientService) {
        this.clientService = clientService;
    }

    @GetMapping("/clients")
    public List<Client> getClients() {
        return clientService.getAllClients();
    }

    @GetMapping("/clients/{id}")
    public Client getClientById(@PathVariable String id) {
        return clientService.getClientById(id);
    }

    @DeleteMapping("/clients/{id}")
    public void deleteClient(@PathVariable String id) {
        clientService.deleteClient(id);
    }

    @PostMapping("/clients")
    public Client saveClient(@RequestBody Client client) {
        return clientService.saveClient(client);
    }

    @PutMapping("/clients/{id}")
    public Client updateClient(@PathVariable String id, @RequestBody Client client) {
        return clientService.updateClient(id, client);
    }
}
