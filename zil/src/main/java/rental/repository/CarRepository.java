package rental.repository;

import org.springframework.stereotype.Repository;
import org.springframework.util.ObjectUtils;
import rental.exception.EntityException;
import rental.model.Car;

import java.util.*;

import static java.lang.String.format;

@Repository
public class CarRepository {

    public static final String CAR_NOT_FOUND_MSG = "Car with ID %s not found";
    public static final String CAR_EXISTS_MSG = "Car with ID %s already exists";

    private static final Map<UUID, Car> cars = new HashMap<>();

    public List<Car> findAll() {
        return new ArrayList<>(cars.values());
    }

    public List<Car> findByModelAndCity(String model, String city) {
        return cars.values().stream()
                .filter(c -> c.getModel().equals(model) && c.getCity().equals(city))
                .toList();
    }

    public Car findById(UUID id) {
        final var car = cars.get(id);
        if (car == null) {
            throw new EntityException(format(CAR_NOT_FOUND_MSG, id));
        }
        return car;
    }

    public void delete(UUID id) {
        final var removed = cars.remove(id);
        if (removed == null) {
            throw new EntityException(format(CAR_NOT_FOUND_MSG, id));
        }
    }

    public Car save(Car car) {
        if (ObjectUtils.isEmpty(car.getId())) {
            car.setId(UUID.randomUUID());
        }

        final var existing = cars.get(car.getId());
        if (existing != null) {
            throw new EntityException(format(CAR_EXISTS_MSG, car.getId()));
        }

        cars.put(car.getId(), car);
        return car;
    }

    public Car put(Car car) {
        final var existing = cars.get(car.getId());
        if (existing == null) {
            throw new EntityException(format(CAR_NOT_FOUND_MSG, car.getId()));
        }

        cars.remove(car.getId());
        cars.put(car.getId(), car);
        return car;
    }

    public void clear() {
        cars.clear();
    }
}
