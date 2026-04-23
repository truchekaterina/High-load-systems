package rental.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import rental.repository.CarRepository;
import rental.repository.ClientRepository;
import rental.repository.RentRepository;

/**
 * LAB5: сброс всех бизнес-таблиц для сценария «очистка → заливка тестовых данных → нагрузка (k6)».
 * <p>
 * Сначала удаляем {@code rents}: строки ссылаются на {@code cars} и {@code clients}. Потом родительские
 * таблицы — иначе СУБД вернёт ошибку нарушения внешнего ключа.
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
     * Удаляет все строки в одной транзакции: аренды → машины → клиенты.
     */
    @Transactional
    public void clearAllData() {
        rentRepository.deleteAll();
        carRepository.deleteAll();
        clientRepository.deleteAll();
    }
}
