package rental.service;

import rental.model.Car;
import rental.model.Rent;
import rental.repository.CarRepository;
import rental.repository.RentRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public class RentService {

    private final RentRepository rentRepository;
    private final CarRepository carRepository;

    public RentService(RentRepository rentRepository, CarRepository carRepository) {
        this.rentRepository = rentRepository;
        this.carRepository = carRepository;
    }

    public List<Rent> getAllRents() {
        return rentRepository.findAll();
    }

    public Rent getRentById(String id) {
        return rentRepository.findById(UUID.fromString(id));
    }

    public Rent saveRent(Rent rent) {
        return rentRepository.save(rent);
    }

    public void deleteRent(String id) {
        rentRepository.delete(UUID.fromString(id));
    }

    public Rent updateRent(String id, Rent rent) {
        rent.setId(UUID.fromString(id));
        return rentRepository.put(rent);
    }

    public boolean isCarAvailable(String model, LocalDate date, String city) {
        List<Car> carsInCity = carRepository.findByModelAndCity(model, city);
        if (carsInCity.isEmpty()) {
            return false;
        }
        return carsInCity.stream().anyMatch(car ->
                rentRepository.findAll().stream()
                        .filter(r -> r.getCarId().equals(car.getId()))
                        .noneMatch(r -> !date.isBefore(r.getStartDate()) && !date.isAfter(r.getEndDate()))
        );
    }
}
