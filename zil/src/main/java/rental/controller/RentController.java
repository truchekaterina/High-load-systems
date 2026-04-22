package rental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;
import rental.dto.AvailableCarsCountResponse;
import rental.model.Rent;
import rental.service.RentService;

import java.time.LocalDate;
import java.util.List;

@RestController
public class RentController {

    private final RentService rentService;

    @Autowired
    public RentController(RentService rentService) {
        this.rentService = rentService;
    }

    @GetMapping("/rents")
    public List<Rent> getRents() {
        return rentService.getAllRents();
    }

    @GetMapping("/rents/availability")
    public boolean isCarAvailable(
            @RequestParam String model,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
            @RequestParam String city) {
        return rentService.isCarAvailable(model, date, city);
    }

    /**
     * Счётчик машин по модели и городу: с датой — сколько свободны в этот день; без даты — сколько всего в парке.
     */
    @GetMapping("/rents/availability/count")
    public AvailableCarsCountResponse countAvailableCars(
            @RequestParam String model,
            @RequestParam String city,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return rentService.countAvailableCars(model, city, date);
    }

    @GetMapping("/rents/{id}")
    public Rent getRentById(@PathVariable String id) {
        return rentService.getRentById(id);
    }

    @DeleteMapping("/rents/{id}")
    public void deleteRent(@PathVariable String id) {
        rentService.deleteRent(id);
    }

    @PostMapping("/rents")
    public Rent saveRent(@RequestBody Rent rent) {
        return rentService.saveRent(rent);
    }

    @PutMapping("/rents/{id}")
    public Rent updateRent(@PathVariable String id, @RequestBody Rent rent) {
        return rentService.updateRent(id, rent);
    }
}
