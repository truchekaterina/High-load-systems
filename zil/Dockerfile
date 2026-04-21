# Multi-stage: сборка bootJar внутри контейнера (Alpine + musl — стабильнее на части Docker Desktop для Windows).
FROM eclipse-temurin:25-jdk-alpine AS builder
WORKDIR /app

COPY gradlew .
COPY gradle gradle
COPY gradle.properties .
COPY settings.gradle .
COPY build.gradle .
COPY src src

# Через wrapper JAR, не через ./gradlew — нет проблем с CRLF/shebang на Windows в репозитории.
RUN ["java", "-classpath", "gradle/wrapper/gradle-wrapper.jar", "org.gradle.wrapper.GradleWrapperMain", "clean", "bootJar", "-x", "test", "--no-daemon"]

FROM eclipse-temurin:25-jre-alpine
WORKDIR /app

COPY --from=builder /app/build/libs/module1-1.0-SNAPSHOT.jar app.jar

EXPOSE 8082
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
