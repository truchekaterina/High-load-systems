package rental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import rental.model.Car;
import rental.service.CarService;

import java.util.List;

@RestController
public class CarController {

    private final CarService carService;

    @Autowired
    public CarController(CarService carService) {
        this.carService = carService;
    }

    @GetMapping("/cars")
    public List<Car> getCars() {
        return carService.getAllCars();
    }

    @GetMapping("/cars/{id}")
    public Car getCarById(@PathVariable String id) {
        return carService.getCarById(id);
    }

    @DeleteMapping("/cars/{id}")
    public void deleteCar(@PathVariable String id) {
        carService.deleteCar(id);
    }

    @PostMapping("/cars")
    public Car saveCar(@RequestBody Car car) {
        return carService.saveCar(car);
    }

    @PutMapping("/cars/{id}")
    public Car updateCar(@PathVariable String id, @RequestBody Car car) {
        return carService.updateCar(id, car);
    }
}
