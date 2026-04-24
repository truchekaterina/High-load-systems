package rental.service;

import org.springframework.util.ObjectUtils;
import rental.dto.AvailableCarsCountResponse;
import rental.exception.EntityException;
import rental.exception.EntityMessages;
import rental.model.Rent;
import rental.repository.CarRepository;
import rental.repository.RentRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static java.lang.String.format;

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
        UUID uuid = UUID.fromString(id);
        return rentRepository.findById(uuid)
                .orElseThrow(() -> new EntityException(format(EntityMessages.RENT_NOT_FOUND_MSG, uuid)));
    }

    public Rent saveRent(Rent rent) {
        if (!ObjectUtils.isEmpty(rent.getId()) && rentRepository.existsById(rent.getId())) {
            throw new EntityException(format(EntityMessages.RENT_EXISTS_MSG, rent.getId()));
        }
        return rentRepository.save(rent);
    }

    public void deleteRent(String id) {
        UUID uuid = UUID.fromString(id);
        if (!rentRepository.existsById(uuid)) {
            throw new EntityException(format(EntityMessages.RENT_NOT_FOUND_MSG, uuid));
        }
        rentRepository.deleteById(uuid);
    }

    public Rent updateRent(String id, Rent rent) {
        UUID uuid = UUID.fromString(id);
        Rent existing = rentRepository.findById(uuid)
                .orElseThrow(() -> new EntityException(format(EntityMessages.RENT_NOT_FOUND_MSG, uuid)));
        existing.setCarId(rent.getCarId());
        existing.setClientId(rent.getClientId());
        existing.setStartDate(rent.getStartDate());
        existing.setEndDate(rent.getEndDate());
        existing.setTotalCost(rent.getTotalCost());
        return rentRepository.save(existing);
    }

    public boolean isCarAvailable(String model, LocalDate date, String city) {
        return carRepository.countAvailableByModelCityOnDate(model, city, date) > 0;
    }

    public AvailableCarsCountResponse countAvailableCars(String model, String city, LocalDate date) {
        if (date == null) {
            long total = carRepository.countByModelAndCity(model, city);
            return new AvailableCarsCountResponse(model, city, null, total);
        }
        long free = carRepository.countAvailableByModelCityOnDate(model, city, date);
        return new AvailableCarsCountResponse(model, city, date, free);
    }
}
