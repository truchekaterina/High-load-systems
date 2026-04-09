package rental.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import rental.model.Rent;

import java.time.LocalDate;
import java.util.UUID;

public interface RentRepository extends JpaRepository<Rent, UUID> {

    /**
     * Количество аренд машины, в интервале которых попадает {@code date} (включительно).
     */
    @Query("SELECT COUNT(r) FROM Rent r WHERE r.carId = :carId AND r.startDate <= :date AND r.endDate >= :date")
    long countOverlappingRentOnDate(@Param("carId") UUID carId, @Param("date") LocalDate date);
}
