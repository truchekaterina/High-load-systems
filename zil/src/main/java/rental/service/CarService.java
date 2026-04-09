package rental.service;

import org.springframework.util.ObjectUtils;
import rental.exception.EntityException;
import rental.exception.EntityMessages;
import rental.model.Car;
import rental.repository.CarRepository;

import java.util.List;
import java.util.UUID;

import static java.lang.String.format;

public class CarService {

    private final CarRepository carRepository;

    public CarService(CarRepository carRepository) {
        this.carRepository = carRepository;
    }

    public List<Car> getAllCars() {
        return carRepository.findAll();
    }

    public Car getCarById(String id) {
        UUID uuid = UUID.fromString(id);
        return carRepository.findById(uuid)
                .orElseThrow(() -> new EntityException(format(EntityMessages.CAR_NOT_FOUND_MSG, uuid)));
    }

    public Car saveCar(Car car) {
        if (!ObjectUtils.isEmpty(car.getId()) && carRepository.existsById(car.getId())) {
            throw new EntityException(format(EntityMessages.CAR_EXISTS_MSG, car.getId()));
        }
        return carRepository.save(car);
    }

    public void deleteCar(String id) {
        UUID uuid = UUID.fromString(id);
        if (!carRepository.existsById(uuid)) {
            throw new EntityException(format(EntityMessages.CAR_NOT_FOUND_MSG, uuid));
        }
        carRepository.deleteById(uuid);
    }

    public Car updateCar(String id, Car car) {
        UUID uuid = UUID.fromString(id);
        Car existing = carRepository.findById(uuid)
                .orElseThrow(() -> new EntityException(format(EntityMessages.CAR_NOT_FOUND_MSG, uuid)));
        existing.setVin(car.getVin());
        existing.setModel(car.getModel());
        existing.setColor(car.getColor());
        existing.setRentalCostPerDay(car.getRentalCostPerDay());
        existing.setCity(car.getCity());
        existing.setSalonName(car.getSalonName());
        return carRepository.save(existing);
    }
}
