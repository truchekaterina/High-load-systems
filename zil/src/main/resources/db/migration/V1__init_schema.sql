-- V1: создаём таблицы один раз. Порядок важен: сначала cars и clients, потом rents (есть ссылки на них).
-- Зачем: Hibernate с ddl-auto=validate не создаёт таблицы, а только проверяет, что они есть. Создаёт их Flyway.
CREATE TABLE cars (
                      id UUID PRIMARY KEY,
                      vin VARCHAR(255) NOT NULL UNIQUE,
                      model VARCHAR(255) NOT NULL,
                      color VARCHAR(255) NOT NULL,
                      rental_cost_per_day NUMERIC(19, 2) NOT NULL,
                      city VARCHAR(255) NOT NULL,
                      salon_name VARCHAR(255) NOT NULL
);

CREATE TABLE clients (
                         id UUID PRIMARY KEY,
                         full_name VARCHAR(255) NOT NULL,
                         driver_license VARCHAR(255) NOT NULL,
                         phone VARCHAR(255) NOT NULL
);

CREATE TABLE rents (
                       id UUID PRIMARY KEY,
                       car_id UUID NOT NULL,
                       client_id UUID NOT NULL,
                       start_date DATE NOT NULL,
                       end_date DATE NOT NULL,
                       total_cost NUMERIC(19, 2) NOT NULL,
                       CONSTRAINT fk_rents_car FOREIGN KEY (car_id) REFERENCES cars (id),
                       CONSTRAINT fk_rents_client FOREIGN KEY (client_id) REFERENCES clients (id),
                       CONSTRAINT chk_rents_dates CHECK (end_date >= start_date)
);