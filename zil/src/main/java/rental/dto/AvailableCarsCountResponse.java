package rental.dto;

import java.time.LocalDate;

/**
 * Ответ на запрос «сколько машин данной модели в городе».
 * Если {@code date} задана — {@code count} = свободны в этот день (нет пересечения с арендой).
 * Если {@code date == null} — {@code count} = всего таких машин в городе (весь парк по модели).
 */
public record AvailableCarsCountResponse(String model, String city, LocalDate date, long count) {
}
