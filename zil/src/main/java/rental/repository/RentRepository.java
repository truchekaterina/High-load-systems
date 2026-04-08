package rental.repository;

import org.springframework.stereotype.Repository;
import org.springframework.util.ObjectUtils;
import rental.exception.EntityException;
import rental.model.Rent;

import java.util.*;

import static java.lang.String.format;

@Repository
public class RentRepository {

    public static final String RENT_NOT_FOUND_MSG = "Rent with ID %s not found";
    public static final String RENT_EXISTS_MSG = "Rent with ID %s already exists";

    private static final Map<UUID, Rent> rents = new HashMap<>();

    public List<Rent> findAll() {
        return new ArrayList<>(rents.values());
    }

    public Rent findById(UUID id) {
        final var rent = rents.get(id);
        if (rent == null) {
            throw new EntityException(format(RENT_NOT_FOUND_MSG, id));
        }
        return rent;
    }

    public void delete(UUID id) {
        final var removed = rents.remove(id);
        if (removed == null) {
            throw new EntityException(format(RENT_NOT_FOUND_MSG, id));
        }
    }

    public Rent save(Rent rent) {
        if (ObjectUtils.isEmpty(rent.getId())) {
            rent.setId(UUID.randomUUID());
        }

        final var existing = rents.get(rent.getId());
        if (existing != null) {
            throw new EntityException(format(RENT_EXISTS_MSG, rent.getId()));
        }

        rents.put(rent.getId(), rent);
        return rent;
    }

    public Rent put(Rent rent) {
        final var existing = rents.get(rent.getId());
        if (existing == null) {
            throw new EntityException(format(RENT_NOT_FOUND_MSG, rent.getId()));
        }

        rents.remove(rent.getId());
        rents.put(rent.getId(), rent);
        return rent;
    }

    public void clear() {
        rents.clear();
    }
}
