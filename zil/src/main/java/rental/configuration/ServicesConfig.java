package rental.configuration;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import rental.observability.ObservabilityService;
import rental.repository.CarRepository;
import rental.repository.ClientRepository;
import rental.repository.RentRepository;
import rental.service.CarService;
import rental.service.ClientService;
import rental.service.RentService;

@Configuration
public class ServicesConfig {

    @Bean
    CarService carService(CarRepository carRepository, ObservabilityService observabilityService) {
        return new CarService(carRepository, observabilityService);
    }

    @Bean
    ClientService clientService(ClientRepository clientRepository, ObservabilityService observabilityService) {
        return new ClientService(clientRepository, observabilityService);
    }

    @Bean
    RentService rentService(
            RentRepository rentRepository,
            CarRepository carRepository,
            ObservabilityService observabilityService) {
        return new RentService(rentRepository, carRepository, observabilityService);
    }
}
