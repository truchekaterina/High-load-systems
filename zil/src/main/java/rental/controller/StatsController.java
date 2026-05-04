package rental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import rental.observability.ObservabilityService;
import rental.repository.CarRepository;
import rental.repository.ClientRepository;
import rental.repository.RentRepository;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class StatsController {

    private final CarRepository carRepository;
    private final ClientRepository clientRepository;
    private final RentRepository rentRepository;
    private final ObservabilityService observabilityService;

    @Autowired
    public StatsController(
            CarRepository carRepository,
            ClientRepository clientRepository,
            RentRepository rentRepository,
            ObservabilityService observabilityService) {
        this.carRepository = carRepository;
        this.clientRepository = clientRepository;
        this.rentRepository = rentRepository;
        this.observabilityService = observabilityService;
    }

    @GetMapping("/stats")
    public Map<String, Long> stats() {
        return observabilityService.timed("web.StatsController.stats", () -> {
            Map<String, Long> out = new LinkedHashMap<>();
            out.put(
                    "cars",
                    observabilityService.timed("db.stats.countCars", carRepository::count));
            out.put(
                    "clients",
                    observabilityService.timed("db.stats.countClients", clientRepository::count));
            out.put(
                    "rents",
                    observabilityService.timed("db.stats.countRents", rentRepository::count));
            return out;
        });
    }
}
