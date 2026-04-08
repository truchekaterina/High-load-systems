package rental.configuration;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import rental.repository.CarRepository;
import rental.repository.ClientRepository;
import rental.repository.RentRepository;
import rental.service.CarService;
import rental.service.ClientService;
import rental.service.RentService;

@Configuration
public class ServicesConfig {

    @Bean
    CarService carService(CarRepository carRepository) {
        return new CarService(carRepository);
    }

    @Bean
    ClientService clientService(ClientRepository clientRepository) {
        return new ClientService(clientRepository);
    }

    @Bean
    RentService rentService(RentRepository rentRepository, CarRepository carRepository) {
        return new RentService(rentRepository, carRepository);
    }
}
