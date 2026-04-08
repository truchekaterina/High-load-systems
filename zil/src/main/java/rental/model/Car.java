package rental.model;

import org.springframework.lang.NonNull;

import java.math.BigDecimal;
import java.util.UUID;

public class Car {

    @NonNull
    private UUID id;
    @NonNull
    private String vin;
    @NonNull
    private String model;
    @NonNull
    private String color;
    @NonNull
    private BigDecimal rentalCostPerDay;
    @NonNull
    private String city;
    @NonNull
    private String salonName;

    public Car(@NonNull UUID id, @NonNull String vin, @NonNull String model, @NonNull String color,
               @NonNull BigDecimal rentalCostPerDay, @NonNull String city, @NonNull String salonName) {
        this.id = id;
        this.vin = vin;
        this.model = model;
        this.color = color;
        this.rentalCostPerDay = rentalCostPerDay;
        this.city = city;
        this.salonName = salonName;
    }

    public Car() {
    }

    @NonNull
    public UUID getId() {
        return id;
    }

    public void setId(@NonNull UUID id) {
        this.id = id;
    }

    @NonNull
    public String getVin() {
        return vin;
    }

    public void setVin(@NonNull String vin) {
        this.vin = vin;
    }

    @NonNull
    public String getModel() {
        return model;
    }

    public void setModel(@NonNull String model) {
        this.model = model;
    }

    @NonNull
    public String getColor() {
        return color;
    }

    public void setColor(@NonNull String color) {
        this.color = color;
    }

    @NonNull
    public BigDecimal getRentalCostPerDay() {
        return rentalCostPerDay;
    }

    public void setRentalCostPerDay(@NonNull BigDecimal rentalCostPerDay) {
        this.rentalCostPerDay = rentalCostPerDay;
    }

    @NonNull
    public String getCity() {
        return city;
    }

    public void setCity(@NonNull String city) {
        this.city = city;
    }

    @NonNull
    public String getSalonName() {
        return salonName;
    }

    public void setSalonName(@NonNull String salonName) {
        this.salonName = salonName;
    }

    @Override
    public String toString() {
        return "Car{" +
                "id=" + id +
                ", vin='" + vin + '\'' +
                ", model='" + model + '\'' +
                ", color='" + color + '\'' +
                ", rentalCostPerDay=" + rentalCostPerDay +
                ", city='" + city + '\'' +
                ", salonName='" + salonName + '\'' +
                '}';
    }
}
