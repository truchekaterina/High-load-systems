package rental.configuration;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Метаинформация для OpenAPI (появляется в /v3/api-docs и вверху Swagger UI).
 */
@Configuration
public class OpenApiInfoConfiguration {

    @Bean
    public OpenAPI carRentalOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Car Rental API")
                        .description("Сервис аренды авто (zil)")
                        .version("v1"));
    }
}
