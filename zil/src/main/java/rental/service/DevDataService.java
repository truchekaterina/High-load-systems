package rental.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import rental.repository.CarRepository;
import rental.repository.ClientRepository;
import rental.repository.RentRepository;

/**
 * Служебные операции для учебы / dev (сброс данных). Не использовать в production API без защиты.
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
     * Удаляет все строки: сначала аренды (FK на cars/clients), затем машины и клиенты.
     */
    @Transactional
    public void clearAllData() {
        rentRepository.deleteAll();
        carRepository.deleteAll();
        clientRepository.deleteAll();
    }
}
