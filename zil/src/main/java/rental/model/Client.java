package rental.model;

import org.springframework.lang.NonNull;

import java.util.UUID;

public class Client {

    @NonNull
    private UUID id;
    @NonNull
    private String fullName;
    @NonNull
    private String driverLicense;
    @NonNull
    private String phone;

    public Client(@NonNull UUID id, @NonNull String fullName, @NonNull String driverLicense, @NonNull String phone) {
        this.id = id;
        this.fullName = fullName;
        this.driverLicense = driverLicense;
        this.phone = phone;
    }

    public Client() {
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
