package rental.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import org.springframework.lang.NonNull;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "rents")
public class Rent {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id;

    /** Ссылка на {@link Car} без JPA-связи — тот же JSON, что в LAB1. */
    @Column(name = "car_id", nullable = false)
    private UUID carId;

    @Column(name = "client_id", nullable = false)
    private UUID clientId;

    @Column(nullable = false)
    private LocalDate startDate;

    @Column(nullable = false)
    private LocalDate endDate;

    @Column(nullable = false, precision = 19, scale = 2)
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

    @PrePersist
    void generateIdIfAbsent() {
        if (id == null) {
            id = UUID.randomUUID();
        }
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
