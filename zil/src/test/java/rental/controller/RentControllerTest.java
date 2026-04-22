package rental.controller;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.web.servlet.MockMvc;
import rental.Application;
import rental.model.Car;
import rental.model.Client;
import rental.model.Rent;
import rental.repository.CarRepository;
import rental.repository.ClientRepository;
import rental.repository.RentRepository;
import tools.jackson.databind.ObjectMapper;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(SpringExtension.class)
@SpringBootTest(classes = Application.class)
@AutoConfigureMockMvc
public class RentControllerTest {

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private MockMvc mvc;

    @Autowired
    private RentRepository rentRepository;

    @Autowired
    private CarRepository carRepository;

    @Autowired
    private ClientRepository clientRepository;

    @BeforeEach
    public void init() {
        rentRepository.deleteAll();
        carRepository.deleteAll();
        clientRepository.deleteAll();
    }

    @Test
    public void get_should_returnRent_when_rentExists() throws Exception {
        Car car = carRepository.save(new Car(UUID.randomUUID(), "VIN1", "Toyota", "Black",
                new BigDecimal("50"), "Moscow", "Salon A"));
        Client client = clientRepository.save(new Client(UUID.randomUUID(), "Ivan", "DL1", "+7900"));
        Rent rent = new Rent(UUID.randomUUID(), car.getId(), client.getId(),
                LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 10), new BigDecimal("500"));
        rent = rentRepository.save(rent);
        String expectedJson = objectMapper.writeValueAsString(rent);

        mvc.perform(get("/rents/" + rent.getId()).accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().json(expectedJson));
    }

    @Test
    public void get_availability_should_returnTrue_when_carAvailableInCity() throws Exception {
        Car car = carRepository.save(new Car(UUID.randomUUID(), "VIN1", "Toyota Camry", "Black",
                new BigDecimal("50"), "Moscow", "Salon A"));
        Client client = clientRepository.save(new Client(UUID.randomUUID(), "Ivan", "DL1", "+7900"));
        Rent rent = new Rent(UUID.randomUUID(), car.getId(), client.getId(),
                LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 10), new BigDecimal("500"));
        rentRepository.save(rent);

        mvc.perform(get("/rents/availability")
                        .param("model", "Toyota Camry")
                        .param("date", "2026-03-15")
                        .param("city", "Moscow")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().string("true"));
    }

    @Test
    public void get_availability_should_returnFalse_when_carRentedOnDate() throws Exception {
        Car car = carRepository.save(new Car(UUID.randomUUID(), "VIN1", "Toyota Camry", "Black",
                new BigDecimal("50"), "Moscow", "Salon A"));
        Client client = clientRepository.save(new Client(UUID.randomUUID(), "Ivan", "DL1", "+7900"));
        Rent rent = new Rent(UUID.randomUUID(), car.getId(), client.getId(),
                LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 10), new BigDecimal("500"));
        rentRepository.save(rent);

        mvc.perform(get("/rents/availability")
                        .param("model", "Toyota Camry")
                        .param("date", "2026-03-05")
                        .param("city", "Moscow")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().string("false"));
    }

    @Test
    public void get_availability_should_returnFalse_when_noCarWithModelInCity() throws Exception {
        mvc.perform(get("/rents/availability")
                        .param("model", "Toyota Camry")
                        .param("date", "2026-03-15")
                        .param("city", "Moscow")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().string("false"));
    }

    @Test
    public void get_availability_count_withDate_countsOnlyFreeCars() throws Exception {
        Car a = carRepository.save(new Car(UUID.randomUUID(), "V1", "Toyota Camry", "Black",
                new BigDecimal("50"), "Moscow", "S1"));
        Car b = carRepository.save(new Car(UUID.randomUUID(), "V2", "Toyota Camry", "White",
                new BigDecimal("50"), "Moscow", "S1"));
        Client client = clientRepository.save(new Client(UUID.randomUUID(), "Ivan", "DL1", "+7900"));
        rentRepository.save(new Rent(UUID.randomUUID(), a.getId(), client.getId(),
                LocalDate.of(2026, 3, 1), LocalDate.of(2026, 3, 10), new BigDecimal("500")));

        mvc.perform(get("/rents/availability/count")
                        .param("model", "Toyota Camry")
                        .param("city", "Moscow")
                        .param("date", "2026-03-05")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.count").value(1))
                .andExpect(jsonPath("$.date").value("2026-03-05"));

        mvc.perform(get("/rents/availability/count")
                        .param("model", "Toyota Camry")
                        .param("city", "Moscow")
                        .param("date", "2026-03-15")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.count").value(2));
    }

    @Test
    public void get_availability_count_withoutDate_returnsTotalFleet() throws Exception {
        carRepository.save(new Car(UUID.randomUUID(), "V1", "Toyota Camry", "Black",
                new BigDecimal("50"), "Moscow", "S1"));
        carRepository.save(new Car(UUID.randomUUID(), "V2", "Toyota Camry", "White",
                new BigDecimal("50"), "Moscow", "S1"));

        mvc.perform(get("/rents/availability/count")
                        .param("model", "Toyota Camry")
                        .param("city", "Moscow")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.count").value(2))
                .andExpect(jsonPath("$.date").value(nullValue()));
    }
}
