package rental.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import rental.ClearTarget;
import rental.repository.CarRepository;
import rental.repository.ClientRepository;
import rental.repository.RentRepository;

/**
 * LAB5: сброс бизнес-таблиц (полный или по сущности) с соблюдением внешних ключей.
 * <p>
 * Таблица {@code rents} ссылается на {@code cars} и {@code clients}, поэтому при удалении машин
 * или клиентов сначала удаляются аренды.
 */
@Service
public class DevDataService {

    private final RentRepository rentRepository;
    private final CarRepository carRepository;
    private final ClientRepository clientRepository;

    @Autowired
    public DevDataService(
            RentRepository rentRepository,
            CarRepository carRepository,
            ClientRepository clientRepository) {
        this.rentRepository = rentRepository;
        this.carRepository = carRepository;
        this.clientRepository = clientRepository;
    }

    /**
     * Полная очистка: аренды → машины → клиенты.
     */
    @Transactional
    public void clearAllData() {
        clearByTarget(ClearTarget.ALL);
    }

    /**
     * Очистка по режиму ТЗ: только часть таблиц, с каскадом только там, где нужен FK.
     * <ul>
     *   <li>{@code ALL} — как {@link #clearAllData()}</li>
     *   <li>{@code RENTS} — только {@code rents}</li>
     *   <li>{@code CARS} — {@code rents}, затем {@code cars}</li>
     *   <li>{@code CLIENTS} — {@code rents}, затем {@code clients}</li>
     * </ul>
     */
    @Transactional
    public void clearByTarget(ClearTarget target) {
        switch (target) {
            case ALL -> {
                // FK: rents → cars, rents → clients — сначала сносим ссылки, потом родители
                rentRepository.deleteAll();
                carRepository.deleteAll();
                clientRepository.deleteAll();
            }
            case RENTS -> rentRepository.deleteAll();
            case CARS -> {
                // нельзя удалить car, пока на неё ссылается rent
                rentRepository.deleteAll();
                carRepository.deleteAll();
            }
            case CLIENTS -> {
                // нельзя удалить client, пока на неё ссылается rent
                rentRepository.deleteAll();
                clientRepository.deleteAll();
            }
        }
    }
}
