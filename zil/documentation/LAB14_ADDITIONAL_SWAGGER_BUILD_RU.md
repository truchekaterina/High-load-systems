# LAB14 — образ additional со Swagger UI (Harbor)

Текущий тег **`lab10`** в Harbor не включает SpringDoc; в Swagger по **`/swagger-ui/index.html`** часто ответ **404**. По полному ТЗ LAB14 нужен Swagger UI у **обоих** сервисов.

Нужные изменения в коде **`zil-additional-service`**:

- **`build.gradle`** — зависимость **`springdoc-openapi-starter-webmvc-ui`**
- **`src/main/resources/application.properties`** — включение springdoc (пути **`/swagger-ui.html`**, **`/v3/api-docs`**)
- **`gradle.properties`**, правка **`Dockerfile`** — таймауты/копирование `gradle.properties` для сборки в контейнере

## 1. Git

На машине с доступом к вашему репозиторию:

```bash
cd ~/path/to/zil-additional-service
git pull
# внесите те же правки, что в коммите feat(lab14): SpringDoc..., или скопируйте файлы из актуального клона
git push origin main
```

## 2. Сборка и push в Harbor

На ВМ с Docker и доступом к **10.60.3.11:8888** (часто SSH **2313** или **hl07**):

В **`/etc/docker/daemon.json`** должны быть **`insecure-registries`** для **`10.60.3.11:8888`** и при необходимости **`hl13.zil:8888`**, затем **`sudo systemctl restart docker`**.

```bash
docker login http://10.60.3.11:8888 -u admin
cd ~/path/to/zil-additional-service
docker build --network=host -t 10.60.3.11:8888/katya/zil-additional-service:lab14-swagger .
docker push 10.60.3.11:8888/katya/zil-additional-service:lab14-swagger
```

Имя проекта/репозитория в Harbor подставьте своё, если не **`katya/zil-additional-service`**.

## 3. Kubernetes

В **`zil/k8s/lab14/05-additional-deployment.yaml`** укажите тег **`lab14-swagger`** в поле **`image:`**, затем:

```bash
kubectl apply -f ~/work/Labs_hls/zil/k8s/lab14/05-additional-deployment.yaml
kubectl -n hl07 rollout restart deployment/zil-additional
kubectl -n hl07 rollout status deployment/zil-additional
```

Проверка Swagger additional (NodePort или port-forward на **8084**):

```bash
curl -I http://127.0.0.1:32084/swagger-ui/index.html
```
