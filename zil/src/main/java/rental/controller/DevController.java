package rental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import rental.service.DevDataService;

/**
 * LAB5: HTTP-обёртка для сброса БД в учебном стенде.
 * <p>
 * Скрипт {@code seed.py} перед заливкой вызывает {@code POST /dev/clear}, чтобы не копить дубликаты
 * (VIN, телефоны) и начинать с пустых таблиц. В production такие эндпоинты не оставляют без защиты.
 */
@RestController
public class DevController {

    private final DevDataService devDataService;

    @Autowired
    public DevController(DevDataService devDataService) {
        this.devDataService = devDataService;
    }

    /**
     * Полная очистка аренд, машин и клиентов. Порядок удаления в сервисе соответствует внешним ключам.
     *
     * @return пустое тело, статус {@link HttpStatus#NO_CONTENT} (204) при успехе
     */
    @PostMapping("/dev/clear")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void clear() {
        devDataService.clearAllData();
    }
}
