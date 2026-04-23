package rental.configuration;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ViewControllerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Удобные алиасы на Swagger UI: часто 404 из‑за неверного пути в адресной строке.
 * Рабочие URL см. комментарии в {@code application.properties}.
 */
@Configuration
public class SwaggerUiWebConfiguration implements WebMvcConfigurer {

    @Override
    public void addViewControllers(ViewControllerRegistry registry) {
        registry.addRedirectViewController("/swagger", "/swagger-ui/index.html");
        registry.addRedirectViewController("/api-docs", "/swagger-ui/index.html");
    }
}
