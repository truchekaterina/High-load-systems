package rental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;
import rental.dto.AvailableCarsCountResponse;
import rental.model.Rent;
import rental.observability.ObservabilityService;
import rental.service.RentService;

import java.time.LocalDate;
import java.util.List;

@RestController
public class RentController {

    private final RentService rentService;
    private final ObservabilityService observabilityService;

    @Autowired
    public RentController(RentService rentService, ObservabilityService observabilityService) {
        this.rentService = rentService;
        this.observabilityService = observabilityService;
    }

    @GetMapping("/rents")
    public List<Rent> getRents() {
        return observabilityService.timed("web.RentController.getRents", rentService::getAllRents);
    }

    @GetMapping("/rents/availability")
    public boolean isCarAvailable(
            @RequestParam String model,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam String city) {
        return observabilityService.timed(
                "web.RentController.isCarAvailable", () -> rentService.isCarAvailable(model, date, city));
    }

    /**
     * Счётчик машин по модели и городу: с датой — сколько свободны в этот день; без даты — сколько всего в парке.
     */
    @GetMapping("/rents/availability/count")
    public AvailableCarsCountResponse countAvailableCars(
            @RequestParam String model,
            @RequestParam String city,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return observabilityService.timed(
                "web.RentController.countAvailableCars",
                () -> rentService.countAvailableCars(model, city, date));
    }

    @GetMapping("/rents/{id}")
    public Rent getRentById(@PathVariable String id) {
        return observabilityService.timed("web.RentController.getRentById", () -> rentService.getRentById(id));
    }

    @DeleteMapping("/rents/{id}")
    public void deleteRent(@PathVariable String id) {
        observabilityService.runTimed("web.RentController.deleteRent", () -> rentService.deleteRent(id));
    }

    @PostMapping("/rents")
    public Rent saveRent(@RequestBody Rent rent) {
        return observabilityService.timed("web.RentController.saveRent", () -> rentService.saveRent(rent));
    }

    @PutMapping("/rents/{id}")
    public Rent updateRent(@PathVariable String id, @RequestBody Rent rent) {
        return observabilityService.timed("web.RentController.updateRent", () -> rentService.updateRent(id, rent));
    }
}
