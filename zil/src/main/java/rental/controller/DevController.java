package rental.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import rental.service.DevDataService;

/**
 * Только для dev / лаб: полная очистка таблиц перед заливкой тестовых данных.
 */
@RestController
public class DevController {

    private final DevDataService devDataService;

    @Autowired
    public DevController(DevDataService devDataService) {
        this.devDataService = devDataService;
    }

    @PostMapping("/dev/clear")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void clear() {
        devDataService.clearAllData();
    }
}
