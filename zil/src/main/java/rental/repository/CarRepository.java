package rental.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import rental.model.Car;

import java.util.List;
import java.util.UUID;

public interface CarRepository extends JpaRepository<Car, UUID> {

    List<Car> findByModelAndCity(String model, String city);
}
