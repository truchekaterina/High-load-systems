package rental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import rental.model.Car;
import rental.observability.ObservabilityService;
import rental.service.CarService;

import java.util.List;

@RestController
public class CarController {

    private final CarService carService;
    private final ObservabilityService observabilityService;

    @Autowired
    public CarController(CarService carService, ObservabilityService observabilityService) {
        this.carService = carService;
        this.observabilityService = observabilityService;
    }

    @GetMapping("/cars")
    public List<Car> getCars() {
        return observabilityService.timed("web.CarController.getCars", carService::getAllCars);
    }

    @GetMapping("/cars/{id}")
    public Car getCarById(@PathVariable String id) {
        return observabilityService.timed("web.CarController.getCarById", () -> carService.getCarById(id));
    }

    @DeleteMapping("/cars/{id}")
    public void deleteCar(@PathVariable String id) {
        observabilityService.runTimed("web.CarController.deleteCar", () -> carService.deleteCar(id));
    }

    @PostMapping("/cars")
    public Car saveCar(@RequestBody Car car) {
        return observabilityService.timed("web.CarController.saveCar", () -> carService.saveCar(car));
    }

    @PutMapping("/cars/{id}")
    public Car updateCar(@PathVariable String id, @RequestBody Car car) {
        return observabilityService.timed("web.CarController.updateCar", () -> carService.updateCar(id, car));
    }
}
