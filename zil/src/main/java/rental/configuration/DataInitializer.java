package rental.configuration;

import rental.model.Car;
import rental.model.Client;
import rental.model.Rent;
import rental.repository.CarRepository;
import rental.repository.ClientRepository;
import rental.repository.RentRepository;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Заполняет репозитории тестовыми данными при запуске приложения.
 */
@Component
public class DataInitializer implements ApplicationRunner {

    public static final UUID CAR_1_ID = UUID.fromString("550e8400-e29b-41d4-a716-446655440001");
    public static final UUID CAR_2_ID = UUID.fromString("550e8400-e29b-41d4-a716-446655440002");
    public static final UUID CAR_3_ID = UUID.fromString("550e8400-e29b-41d4-a716-446655440003");
    public static final UUID CAR_4_ID = UUID.fromString("550e8400-e29b-41d4-a716-446655440004");

    public static final UUID CLIENT_1_ID = UUID.fromString("6ba7b810-9dad-11d1-80b4-00c04fd430c1");
    public static final UUID CLIENT_2_ID = UUID.fromString("6ba7b810-9dad-11d1-80b4-00c04fd430c2");
    public static final UUID CLIENT_3_ID = UUID.fromString("6ba7b810-9dad-11d1-80b4-00c04fd430c3");
    public static final UUID CLIENT_4_ID = UUID.fromString("6ba7b810-9dad-11d1-80b4-00c04fd430c4");

    public static final UUID RENT_1_ID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef1234567890");
    public static final UUID RENT_2_ID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef1234567891");
    public static final UUID RENT_3_ID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef1234567892");
    public static final UUID RENT_4_ID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef1234567893");

    private final CarRepository carRepository;
    private final ClientRepository clientRepository;
    private final RentRepository rentRepository;

    public DataInitializer(CarRepository carRepository, ClientRepository clientRepository, RentRepository rentRepository) {
        this.carRepository = carRepository;
        this.clientRepository = clientRepository;
        this.rentRepository = rentRepository;
    }

    @Override
    public void run(ApplicationArguments args) {
        initCars();
        initClients();
        initRents();
    }

    private void initCars() {
        carRepository.save(new Car(CAR_1_ID, "WVWZZZ3CZWE123456", "Toyota Camry", "Black",
                new BigDecimal("50.00"), "Moscow", "Salon A"));
        carRepository.save(new Car(CAR_2_ID, "1HGBH41JXMN109186", "Honda Accord", "White",
                new BigDecimal("45.50"), "Moscow", "Salon B"));
        carRepository.save(new Car(CAR_3_ID, "JM1BL1S58A1234567", "Mazda 6", "Red",
                new BigDecimal("55.00"), "SPB", "Salon North"));
        carRepository.save(new Car(CAR_4_ID, "WBA3B1C50EK123456", "BMW 320", "Blue",
                new BigDecimal("80.00"), "Moscow", "Premium Salon"));
    }

    private void initClients() {
        clientRepository.save(new Client(CLIENT_1_ID, "Иван Иванов", "DL123456", "+79001234567"));
        clientRepository.save(new Client(CLIENT_2_ID, "Мария Петрова", "DL789012", "+79009876543"));
        clientRepository.save(new Client(CLIENT_3_ID, "Алексей Сидоров", "DL345678", "+79005551234"));
        clientRepository.save(new Client(CLIENT_4_ID, "Елена Козлова", "DL901234", "+79003334455"));
    }

    private void initRents() {
        rentRepository.save(new Rent(RENT_1_ID, CAR_1_ID, CLIENT_1_ID,
                LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 10), new BigDecimal("500")));
        rentRepository.save(new Rent(RENT_2_ID, CAR_1_ID, CLIENT_2_ID,
                LocalDate.of(2026, 3, 15), LocalDate.of(2026, 3, 20), new BigDecimal("350")));
        rentRepository.save(new Rent(RENT_3_ID, CAR_2_ID, CLIENT_1_ID,
                LocalDate.of(2026, 4, 1), LocalDate.of(2026, 4, 7), new BigDecimal("600")));
        rentRepository.save(new Rent(RENT_4_ID, CAR_3_ID, CLIENT_3_ID,
                LocalDate.of(2026, 5, 10), LocalDate.of(2026, 5, 15), new BigDecimal("450")));
    }
}
