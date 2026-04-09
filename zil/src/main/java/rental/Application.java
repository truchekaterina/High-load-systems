package rental;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * LAB2: пока модели без {@code @Entity} и репозитории на HashMap — не поднимаем пул к PostgreSQL
 * при старте (иначе {@code Connection refused}, если Docker не запущен).
 * После перевода на JPA — удалите {@code excludeName} ниже.
 */
@SpringBootApplication(excludeName = {
        "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration",
        "org.springframework.boot.autoconfigure.orm.jpa.HibernateJpaAutoConfiguration",
        "org.springframework.boot.autoconfigure.data.jpa.JpaRepositoriesAutoConfiguration"
})
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
