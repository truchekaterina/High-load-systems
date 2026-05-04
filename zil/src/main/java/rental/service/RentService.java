package rental.service;

import org.springframework.util.ObjectUtils;
import rental.dto.AvailableCarsCountResponse;
import rental.exception.EntityException;
import rental.exception.EntityMessages;
import rental.model.Rent;
import rental.observability.ObservabilityService;
import rental.repository.CarRepository;
import rental.repository.RentRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static java.lang.String.format;

public class RentService {

    private final RentRepository rentRepository;
    private final CarRepository carRepository;
    private final ObservabilityService observabilityService;

    public RentService(
            RentRepository rentRepository,
            CarRepository carRepository,
            ObservabilityService observabilityService) {
        this.rentRepository = rentRepository;
        this.carRepository = carRepository;
        this.observabilityService = observabilityService;
    }

    public List<Rent> getAllRents() {
        return observabilityService.timed("db.rent.findAll", rentRepository::findAll);
    }

    public Rent getRentById(String id) {
        UUID uuid = UUID.fromString(id);
        return observabilityService.timed(
                "db.rent.findById",
                () -> rentRepository
                        .findById(uuid)
                        .orElseThrow(() -> new EntityException(format(EntityMessages.RENT_NOT_FOUND_MSG, uuid))));
    }

    public Rent saveRent(Rent rent) {
        if (!ObjectUtils.isEmpty(rent.getId())) {
            boolean exists =
                    observabilityService.timed("db.rent.existsById", () -> rentRepository.existsById(rent.getId()));
            if (exists) {
                throw new EntityException(format(EntityMessages.RENT_EXISTS_MSG, rent.getId()));
            }
        }
        return observabilityService.timed("db.rent.save", () -> rentRepository.save(rent));
    }

    public void deleteRent(String id) {
        UUID uuid = UUID.fromString(id);
        boolean exists =
                observabilityService.timed("db.rent.existsById", () -> rentRepository.existsById(uuid));
        if (!exists) {
            throw new EntityException(format(EntityMessages.RENT_NOT_FOUND_MSG, uuid));
        }
        observabilityService.runTimed("db.rent.deleteById", () -> rentRepository.deleteById(uuid));
    }

    public Rent updateRent(String id, Rent rent) {
        UUID uuid = UUID.fromString(id);
        Rent existing = observabilityService.timed(
                "db.rent.findById",
                () -> rentRepository
                        .findById(uuid)
                        .orElseThrow(() -> new EntityException(format(EntityMessages.RENT_NOT_FOUND_MSG, uuid))));
        existing.setCarId(rent.getCarId());
        existing.setClientId(rent.getClientId());
        existing.setStartDate(rent.getStartDate());
        existing.setEndDate(rent.getEndDate());
        existing.setTotalCost(rent.getTotalCost());
        return observabilityService.timed("db.rent.save", () -> rentRepository.save(existing));
    }

    public boolean isCarAvailable(String model, LocalDate date, String city) {
        long n = observabilityService.timed(
                "db.car.countAvailableByModelCityOnDate",
                () -> carRepository.countAvailableByModelCityOnDate(model, city, date));
        return n > 0;
    }

    public AvailableCarsCountResponse countAvailableCars(String model, String city, LocalDate date) {
        if (date == null) {
            long total = observabilityService.timed(
                    "db.car.countByModelAndCity", () -> carRepository.countByModelAndCity(model, city));
            return new AvailableCarsCountResponse(model, city, null, total);
        }
        long free = observabilityService.timed(
                "db.car.countAvailableByModelCityOnDate",
                () -> carRepository.countAvailableByModelCityOnDate(model, city, date));
        return new AvailableCarsCountResponse(model, city, date, free);
    }
}
