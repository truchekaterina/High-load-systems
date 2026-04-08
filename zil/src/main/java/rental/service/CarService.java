package rental.service;

import rental.model.Car;
import rental.repository.CarRepository;

import java.util.List;
import java.util.UUID;

public class CarService {

    private final CarRepository carRepository;

    public CarService(CarRepository carRepository) {
        this.carRepository = carRepository;
    }

    public List<Car> getAllCars() {
        return carRepository.findAll();
    }

    public Car getCarById(String id) {
        return carRepository.findById(UUID.fromString(id));
    }

    public Car saveCar(Car car) {
        return carRepository.save(car);
    }

    public void deleteCar(String id) {
        carRepository.delete(UUID.fromString(id));
    }

    public Car updateCar(String id, Car car) {
        car.setId(UUID.fromString(id));
        return carRepository.put(car);
    }
}
