package rental.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import rental.model.Client;

import java.util.UUID;

public interface ClientRepository extends JpaRepository<Client, UUID> {
}
