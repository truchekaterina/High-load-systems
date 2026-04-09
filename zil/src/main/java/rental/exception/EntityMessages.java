package rental.exception;

/**
 * Сообщения об ошибках сущностей (раньше жили в классах репозиториев на HashMap).
 */
public final class EntityMessages {

    private EntityMessages() {
    }

    public static final String CAR_NOT_FOUND_MSG = "Car with ID %s not found";
    public static final String CAR_EXISTS_MSG = "Car with ID %s already exists";

    public static final String CLIENT_NOT_FOUND_MSG = "Client with ID %s not found";
    public static final String CLIENT_EXISTS_MSG = "Client with ID %s already exists";

    public static final String RENT_NOT_FOUND_MSG = "Rent with ID %s not found";
    public static final String RENT_EXISTS_MSG = "Rent with ID %s already exists";
}
