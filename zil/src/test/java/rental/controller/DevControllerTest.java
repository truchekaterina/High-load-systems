package rental.controller;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.web.servlet.MockMvc;
import rental.Application;
import rental.model.Car;
import rental.model.Client;
import rental.model.Rent;
import rental.repository.CarRepository;
import rental.repository.ClientRepository;
import rental.repository.RentRepository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(SpringExtension.class)
@SpringBootTest(classes = Application.class)
@AutoConfigureMockMvc
class DevControllerTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private RentRepository rentRepository;

    @Autowired
    private CarRepository carRepository;

    @Autowired
    private ClientRepository clientRepository;

    @BeforeEach
    void clean() {
        rentRepository.deleteAll();
        carRepository.deleteAll();
        clientRepository.deleteAll();
    }

    @Test
    void clear_all_removes_everything() throws Exception {
        seedOneChain();

        mvc.perform(post("/dev/clear").param("clear", "all"))
                .andExpect(status().isNoContent());

        assertThat(rentRepository.count()).isZero();
        assertThat(carRepository.count()).isZero();
        assertThat(clientRepository.count()).isZero();
    }

    @Test
    void clear_rents_only_removes_rents() throws Exception {
        seedOneChain();
        long carsBefore = carRepository.count();
        long clientsBefore = clientRepository.count();
        assertThat(rentRepository.count()).isEqualTo(1L);

        mvc.perform(post("/dev/clear").param("clear", "rents"))
                .andExpect(status().isNoContent());

        assertThat(rentRepository.count()).isZero();
        assertThat(carRepository.count()).isEqualTo(carsBefore);
        assertThat(clientRepository.count()).isEqualTo(clientsBefore);
    }

    @Test
    void clear_cars_removes_rents_and_cars() throws Exception {
        seedOneChain();

        mvc.perform(post("/dev/clear").param("clear", "cars"))
                .andExpect(status().isNoContent());

        assertThat(rentRepository.count()).isZero();
        assertThat(carRepository.count()).isZero();
        assertThat(clientRepository.count()).isEqualTo(1L);
    }

    @Test
    void clear_clients_removes_rents_and_clients() throws Exception {
        seedOneChain();

        mvc.perform(post("/dev/clear").param("clear", "clients"))
                .andExpect(status().isNoContent());

        assertThat(rentRepository.count()).isZero();
        assertThat(clientRepository.count()).isZero();
        assertThat(carRepository.count()).isEqualTo(1L);
    }

    @Test
    void clear_default_param_is_all() throws Exception {
        seedOneChain();

        mvc.perform(post("/dev/clear"))
                .andExpect(status().isNoContent());

        assertThat(rentRepository.count()).isZero();
        assertThat(carRepository.count()).isZero();
        assertThat(clientRepository.count()).isZero();
    }

    @Test
    void clear_unknown_clear_param_is_bad_request() throws Exception {
        mvc.perform(post("/dev/clear").param("clear", "nope"))
                .andExpect(status().isBadRequest());
    }

    private void seedOneChain() {
        Car car = carRepository.save(
                new Car(UUID.randomUUID(), "VIN1234567890123X", "M", "Black",
                        new BigDecimal("50"), "Moscow", "S"));
        Client client = clientRepository.save(
                new Client(UUID.randomUUID(), "Ivan", "DL1", "+7900"));
        rentRepository.save(
                new Rent(UUID.randomUUID(), car.getId(), client.getId(),
                        LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 10), new BigDecimal("500")));
    }
}
