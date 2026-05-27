# Car Rental Service

## Project Description

Car Rental Service is a backend application for managing car rentals across multiple cities and dealerships.

The system allows clients to rent vehicles for a selected period, calculates the total rental cost, and tracks vehicle availability in real time.

The platform includes functionality for:

* managing cars and dealerships;
* storing customer information;
* creating and managing rental orders;
* calculating rental prices based on rental duration;
* checking vehicle availability for selected dates and city.

## Business Goal

The main goal of the project is to automate the rental workflow for a distributed car rental company and provide a scalable backend platform capable of handling high load and concurrent requests.

## Main Entities

### Car

Represents a vehicle available for rent.

Fields:

* VIN
* model
* color
* rental price per day
* city
* dealership name

### Client

Represents a customer renting a vehicle.

Fields:

* full name
* driver license number
* phone number

### Rental

Represents a rental operation связывающую клиента и автомобиль.

Fields:

* rental start date
* rental end date
* total rental price

## Additional Features

* Vehicle availability validation by city and rental dates
* REST API for CRUD operations
* PostgreSQL persistence layer
* Docker-based deployment
* Kafka integration for asynchronous event processing
* Redis caching for statistics and frequently accessed data
* Kubernetes deployment support
* Load testing with k6
* Monitoring with Prometheus and Grafana

## Technology Stack

* Java 25
* Spring Boot
* Spring Data JPA
* PostgreSQL
* Docker & Docker Compose
* Kubernetes (k3s)
* Apache Kafka
* Redis
* k6
* Prometheus & Grafana

## Architecture

The application is designed using a microservices-oriented approach and includes:

* Core CRUD service
* Additional statistics service
* PostgreSQL database
* Kafka messaging layer
* Redis cache layer

## API Features

* Create/update/delete cars
* Register clients
* Create rentals
* Calculate rental costs
* Check available cars by city and date
* Retrieve aggregated statistics
