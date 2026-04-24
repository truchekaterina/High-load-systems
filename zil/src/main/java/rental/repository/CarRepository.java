package rental.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import rental.model.Car;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public interface CarRepository extends JpaRepository<Car, UUID> {

    List<Car> findByModelAndCity(String model, String city);

    long countByModelAndCity(String model, String city);

    /**
     * Сколько машин данной модели в городе <strong>свободны</strong> в календарный день {@code date}
     * (то же условие «занятости», что в {@link RentRepository#countOverlappingRentOnDate}).
     */
    @Query("SELECT COUNT(c) FROM Car c WHERE c.model = :model AND c.city = :city AND NOT EXISTS ("
            + "SELECT 1 FROM Rent r WHERE r.carId = c.id AND r.startDate <= :date AND r.endDate >= :date)")
    long countAvailableByModelCityOnDate(
            @Param("model") String model,
            @Param("city") String city,
            @Param("date") LocalDate date);
}
