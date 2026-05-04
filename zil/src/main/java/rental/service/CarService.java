package rental.service;

import org.springframework.util.ObjectUtils;
import rental.exception.EntityException;
import rental.exception.EntityMessages;
import rental.model.Car;
import rental.observability.ObservabilityService;
import rental.repository.CarRepository;

import java.util.List;
import java.util.UUID;

import static java.lang.String.format;

public class CarService {

    private final CarRepository carRepository;
    private final ObservabilityService observabilityService;

    public CarService(CarRepository carRepository, ObservabilityService observabilityService) {
        this.carRepository = carRepository;
        this.observabilityService = observabilityService;
    }

    public List<Car> getAllCars() {
        return observabilityService.timed("db.car.findAll", carRepository::findAll);
    }

    public Car getCarById(String id) {
        UUID uuid = UUID.fromString(id);
        return observabilityService.timed(
                "db.car.findById",
                () -> carRepository
                        .findById(uuid)
                        .orElseThrow(() -> new EntityException(format(EntityMessages.CAR_NOT_FOUND_MSG, uuid))));
    }

    public Car saveCar(Car car) {
        if (!ObjectUtils.isEmpty(car.getId())) {
            boolean exists = observabilityService.timed(
                    "db.car.existsById", () -> carRepository.existsById(car.getId()));
            if (exists) {
                throw new EntityException(format(EntityMessages.CAR_EXISTS_MSG, car.getId()));
            }
        }
        return observabilityService.timed("db.car.save", () -> carRepository.save(car));
    }

    public void deleteCar(String id) {
        UUID uuid = UUID.fromString(id);
        boolean exists = observabilityService.timed("db.car.existsById", () -> carRepository.existsById(uuid));
        if (!exists) {
            throw new EntityException(format(EntityMessages.CAR_NOT_FOUND_MSG, uuid));
        }
        observabilityService.runTimed("db.car.deleteById", () -> carRepository.deleteById(uuid));
    }

    public Car updateCar(String id, Car car) {
        UUID uuid = UUID.fromString(id);
        Car existing = observabilityService.timed(
                "db.car.findById",
                () -> carRepository
                        .findById(uuid)
                        .orElseThrow(() -> new EntityException(format(EntityMessages.CAR_NOT_FOUND_MSG, uuid))));
        existing.setVin(car.getVin());
        existing.setModel(car.getModel());
        existing.setColor(car.getColor());
        existing.setRentalCostPerDay(car.getRentalCostPerDay());
        existing.setCity(car.getCity());
        existing.setSalonName(car.getSalonName());
        return observabilityService.timed("db.car.save", () -> carRepository.save(existing));
    }
}
