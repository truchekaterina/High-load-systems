package rental.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import org.springframework.lang.NonNull;

import java.util.UUID;

@Entity
@Table(name = "clients")
public class Client {

    @Id
    @Column(nullable = false, updatable = false)
    private UUID id;

    @Column(nullable = false)
    private String fullName;

    @Column(nullable = false)
    private String driverLicense;

    @Column(nullable = false)
    private String phone;

    public Client(@NonNull UUID id, @NonNull String fullName, @NonNull String driverLicense, @NonNull String phone) {
        this.id = id;
        this.fullName = fullName;
        this.driverLicense = driverLicense;
        this.phone = phone;
    }

    public Client() {
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
    public String getFullName() {
        return fullName;
    }

    public void setFullName(@NonNull String fullName) {
        this.fullName = fullName;
    }

    @NonNull
    public String getDriverLicense() {
        return driverLicense;
    }

    public void setDriverLicense(@NonNull String driverLicense) {
        this.driverLicense = driverLicense;
    }

    @NonNull
    public String getPhone() {
        return phone;
    }

    public void setPhone(@NonNull String phone) {
        this.phone = phone;
    }

    @Override
    public String toString() {
        return "Client{" +
                "id=" + id +
                ", fullName='" + fullName + '\'' +
                ", driverLicense='" + driverLicense + '\'' +
                ", phone='" + phone + '\'' +
                '}';
    }
}
