package rental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import rental.ClearTarget;
import rental.service.DevDataService;

/**
 * LAB5: HTTP-обёртка для сброса БД в учебном стенде.
 * <p>
 * Скрипт {@code seed.py} перед заливкой вызывает {@code POST /dev/clear} (опционально с {@code ?clear=…}),
 * чтобы не копить дубликаты (VIN, телефоны) и начинать с предсказуемого состояния БД.
 * В production такие эндпоинты не оставляют без защиты.
 */
@RestController
public class DevController {

    private final DevDataService devDataService;

    @Autowired
    public DevController(DevDataService devDataService) {
        this.devDataService = devDataService;
    }

    /**
     * Очистка данных dev-стенда. Query {@code clear} (по умолчанию {@code all}):
     * {@code all} — все таблицы; {@code rents} / {@code cars} / {@code clients} — «корневая» сущность
     * с каскадом по внешним ключам (см. {@link rental.service.DevDataService#clearByTarget(rental.ClearTarget)}).
     * <p>
     * Код ответа 204: тела нет — ожидаемый сценарий «потом смотрите GET /...».
     * Неизвестное значение {@code clear} — 400 с текстом, не 500.
     */
    @PostMapping("/dev/clear")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void clear(
            @RequestParam(name = "clear", defaultValue = "all") String clear) {
        try {
            // строка HTTP → enum в одном месте; ошибка разбора — в try/catch ниже
            devDataService.clearByTarget(ClearTarget.fromQuery(clear));
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, e.getMessage(), e);
        }
    }
}
