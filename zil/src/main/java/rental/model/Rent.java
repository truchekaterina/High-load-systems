package rental.model;

import org.springframework.lang.NonNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public class Rent {

    @NonNull
    private UUID id;
    @NonNull
    private UUID carId;
    @NonNull
    private UUID clientId;
    @NonNull
    private LocalDate startDate;
    @NonNull
    private LocalDate endDate;
    @NonNull
    private BigDecimal totalCost;

    public Rent(@NonNull UUID id, @NonNull UUID carId, @NonNull UUID clientId,
                @NonNull LocalDate startDate, @NonNull LocalDate endDate, @NonNull BigDecimal totalCost) {
        this.id = id;
        this.carId = carId;
        this.clientId = clientId;
        this.startDate = startDate;
        this.endDate = endDate;
        this.totalCost = totalCost;
    }

    public Rent() {
    }

    @NonNull
    public UUID getId() {
        return id;
    }

    public void setId(@NonNull UUID id) {
        this.id = id;
    }

    @NonNull
    public UUID getCarId() {
        return carId;
    }

    public void setCarId(@NonNull UUID carId) {
        this.carId = carId;
    }

    @NonNull
    public UUID getClientId() {
        return clientId;
    }

    public void setClientId(@NonNull UUID clientId) {
        this.clientId = clientId;
    }

    @NonNull
    public LocalDate getStartDate() {
        return startDate;
    }

    public void setStartDate(@NonNull LocalDate startDate) {
        this.startDate = startDate;
    }

    @NonNull
    public LocalDate getEndDate() {
        return endDate;
    }

    public void setEndDate(@NonNull LocalDate endDate) {
        this.endDate = endDate;
    }

    @NonNull
    public BigDecimal getTotalCost() {
        return totalCost;
    }

    public void setTotalCost(@NonNull BigDecimal totalCost) {
        this.totalCost = totalCost;
    }

    @Override
    public String toString() {
        return "Rent{" +
                "id=" + id +
                ", carId=" + carId +
                ", clientId=" + clientId +
                ", startDate=" + startDate +
                ", endDate=" + endDate +
                ", totalCost=" + totalCost +
                '}';
    }
}
