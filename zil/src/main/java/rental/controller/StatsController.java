package rental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
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

    @Autowired
    public StatsController(
            CarRepository carRepository,
            ClientRepository clientRepository,
            RentRepository rentRepository) {
        this.carRepository = carRepository;
        this.clientRepository = clientRepository;
        this.rentRepository = rentRepository;
    }

    @GetMapping("/stats")
    public Map<String, Long> stats() {
        Map<String, Long> out = new LinkedHashMap<>();
        out.put("cars", carRepository.count());
        out.put("clients", clientRepository.count());
        out.put("rents", rentRepository.count());
        return out;
    }
}
