# Образ только с JRE: jar с хоста (prepare-docker.ps1 / .bat).
# 25-jre (glibc) на части ПК с Docker Desktop даёт "exec java: input/output error" — используем Alpine (musl).
FROM eclipse-temurin:25-jre-alpine
WORKDIR /app

COPY docker/app.jar app.jar

EXPOSE 8082
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
