# LAB14 — подключение узла к k3s и деплой двух микросервисов (hl07)

Документ для варианта **Трюх Екатерина** с привязкой к стенду курса:

- узел студентки: **hl07** (`ssh -p 2307 hl@hlssh.zil.digital`)
- k3s master: **hl16** (`10.60.3.14`, `ssh -p 2316 hl@hlssh.zil.digital`)
- DB host по ТЗ: **`10.60.3.9`**
- Kafka hosts по ТЗ: **`10.60.3.12,10.60.3.13`**

Цель LAB14:

1. Подключить свой узел к общему кластеру k3s (разделы 5 и 6 K3S-SETUP).
2. Развернуть в k3s основной и дополнительный сервис через YAML-манифесты.
3. Показать доступ к Swagger UI через `port-forward` и через `NodePort`.

---

## 1. Что должно быть в результате

В `k8s` должны быть созданы:

- `Namespace` с именем варианта: **`hl07`**
- `ConfigMap` с ENV-параметрами
- `Secret` для пароля БД
- `Secret` для DockerHub доступа (реальный создаётся вручную, в git хранится шаблон)
- `Deployment` для `app`
- `Deployment` для `additional`
- `Service` `ClusterIP` для внутреннего вызова `additional -> app`
- `Service` `NodePort` для внешнего доступа к Swagger UI обоих сервисов

Ресурсы по ТЗ:

- на каждый сервис `requests == limits`:
  - `cpu: 1`
  - `memory: 1Gi`
- это режим **Guaranteed**

---

## 2. Подключение узла hl07 в k3s (раздел 5)

## 2.1 На master получить токен

```bash
ssh -p 2316 hl@hlssh.zil.digital
sudo cat /var/lib/rancher/k3s/server/node-token
kubectl get nodes -o wide
```

Скопируйте токен из вывода `node-token`.

## 2.2 На узле hl07 поставить k3s-agent

```bash
ssh -p 2307 hl@hlssh.zil.digital
ip a show tun0
```

Проверьте VPN IP вашего узла (для hl07 обычно `10.60.3.7`).

Установка агента:

```bash
curl -sfL https://get.k3s.io | \
  K3S_URL=https://10.60.3.14:6443 \
  K3S_TOKEN=<TOKEN_С_HL16> \
  INSTALL_K3S_EXEC="--node-ip 10.60.3.7 --flannel-iface tun0" sh -
```

Проверка:

```bash
sudo systemctl status k3s-agent
```

## 2.3 Проверка на master

```bash
ssh -p 2316 hl@hlssh.zil.digital
kubectl get nodes -o wide
```

Ожидание: `hl07` в статусе `Ready`.

---

## 3. Настройка kubectl на hl07 (раздел 6)

## 3.1 Взять kubeconfig с master

```bash
ssh -p 2316 hl@hlssh.zil.digital
sudo cat /etc/rancher/k3s/k3s.yaml
```

В скопированном файле замените:

- `server: https://127.0.0.1:6443`

на:

- `server: https://10.60.3.14:6443`

## 3.2 Установить kubectl на hl07

```bash
ssh -p 2307 hl@hlssh.zil.digital

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

mkdir -p ~/.kube
nano ~/.kube/config
chmod 600 ~/.kube/config
```

Проверка:

```bash
kubectl cluster-info
kubectl get nodes -o wide
```

---

## 4. Каталог манифестов в репозитории

На `hl07`:

```bash
cd ~/work/Labs_hls/zil
mkdir -p k8s/lab14
```

Создайте файлы ниже.

---

## 5. YAML-манифесты LAB14

## 5.1 `k8s/lab14/00-namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: hl07
```

## 5.2 `k8s/lab14/01-configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: zil-config
  namespace: hl07
data:
  DB_HOST: "10.60.3.9"
  DB_PORT: "5433"
  DB_NAME: "hl7"
  DB_SCHEMA: "hl7"
  DB_USER: "hl7"

  KAFKA_HOSTS: "10.60.3.12,10.60.3.13"
  KAFKA_BOOTSTRAP_SERVERS: "10.60.3.12:9094,10.60.3.13:9094"
  KAFKA_TOPIC: "hl07-lab13"
  KAFKA_CONSUMER_GROUP_ID: "rental-app-lab14-hl07"
  KAFKA_LISTENER_CONCURRENCY: "2"

  MAIN_SERVICE_BASE_URL: "http://zil-app-internal:8083"
```

## 5.3 `k8s/lab14/02-secret-db.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: zil-db-secret
  namespace: hl07
type: Opaque
stringData:
  DB_PASSWORD: "hl7_labs"
```

## 5.4 `k8s/lab14/03-secret-dockerhub-template.yaml` (в git только шаблон)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dockerhub-regcred
  namespace: hl07
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: "<BASE64_DOCKER_CONFIG_JSON>"
```

## 5.5 `k8s/lab14/04-app-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zil-app
  namespace: hl07
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zil-app
  template:
    metadata:
      labels:
        app: zil-app
    spec:
      imagePullSecrets:
        - name: dockerhub-regcred
      containers:
        - name: app
          image: <YOUR_DOCKERHUB_LOGIN>/zil-app:lab14
          imagePullPolicy: Always
          ports:
            - containerPort: 8083
          env:
            - name: DBHOST
              valueFrom:
                configMapKeyRef:
                  name: zil-config
                  key: DB_HOST
            - name: DBPORT
              valueFrom:
                configMapKeyRef:
                  name: zil-config
                  key: DB_PORT
            - name: DBNAME
              valueFrom:
                configMapKeyRef:
                  name: zil-config
                  key: DB_NAME
            - name: SCHEMANAME
              valueFrom:
                configMapKeyRef:
                  name: zil-config
                  key: DB_SCHEMA
            - name: SPRING_DATASOURCE_USERNAME
              valueFrom:
                configMapKeyRef:
                  name: zil-config
                  key: DB_USER
            - name: SPRING_DATASOURCE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: zil-db-secret
                  key: DB_PASSWORD
            - name: SPRING_KAFKA_BOOTSTRAP_SERVERS
              valueFrom:
                configMapKeyRef:
                  name: zil-config
                  key: KAFKA_BOOTSTRAP_SERVERS
            - name: KAFKA_TOPIC
              valueFrom:
                configMapKeyRef:
                  name: zil-config
                  key: KAFKA_TOPIC
            - name: SPRING_KAFKA_CONSUMER_GROUP_ID
              valueFrom:
                configMapKeyRef:
                  name: zil-config
                  key: KAFKA_CONSUMER_GROUP_ID
            - name: KAFKA_LISTENER_CONCURRENCY
              valueFrom:
                configMapKeyRef:
                  name: zil-config
                  key: KAFKA_LISTENER_CONCURRENCY
          resources:
            requests:
              cpu: "1"
              memory: "1Gi"
            limits:
              cpu: "1"
              memory: "1Gi"
```

## 5.6 `k8s/lab14/05-additional-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: zil-additional
  namespace: hl07
spec:
  replicas: 1
  selector:
    matchLabels:
      app: zil-additional
  template:
    metadata:
      labels:
        app: zil-additional
    spec:
      imagePullSecrets:
        - name: dockerhub-regcred
      containers:
        - name: additional
          image: <YOUR_DOCKERHUB_LOGIN>/zil-additional-service:lab14
          imagePullPolicy: Always
          ports:
            - containerPort: 8084
          env:
            - name: MAIN_SERVICE_BASE_URL
              valueFrom:
                configMapKeyRef:
                  name: zil-config
                  key: MAIN_SERVICE_BASE_URL
            - name: SERVER_PORT
              value: "8084"
          resources:
            requests:
              cpu: "1"
              memory: "1Gi"
            limits:
              cpu: "1"
              memory: "1Gi"
```

## 5.7 `k8s/lab14/06-services.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: zil-app-internal
  namespace: hl07
spec:
  type: ClusterIP
  selector:
    app: zil-app
  ports:
    - name: http
      port: 8083
      targetPort: 8083
---
apiVersion: v1
kind: Service
metadata:
  name: zil-app-nodeport
  namespace: hl07
spec:
  type: NodePort
  selector:
    app: zil-app
  ports:
    - name: http
      port: 8083
      targetPort: 8083
      nodePort: 32083
---
apiVersion: v1
kind: Service
metadata:
  name: zil-additional-nodeport
  namespace: hl07
spec:
  type: NodePort
  selector:
    app: zil-additional
  ports:
    - name: http
      port: 8084
      targetPort: 8084
      nodePort: 32084
```

---

## 6. DockerHub Secret (создаётся вручную)

Реальный секрет создаётся командой, а не хранится в git:

```bash
kubectl -n hl07 create secret docker-registry dockerhub-regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<DOCKERHUB_USER> \
  --docker-password='<DOCKERHUB_PASSWORD_OR_TOKEN>' \
  --docker-email='<YOUR_EMAIL>' \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## 7. Применение манифестов

```bash
cd ~/work/Labs_hls/zil/k8s/lab14

kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-configmap.yaml
kubectl apply -f 02-secret-db.yaml
kubectl apply -f 04-app-deployment.yaml
kubectl apply -f 05-additional-deployment.yaml
kubectl apply -f 06-services.yaml

kubectl -n hl07 get all
kubectl -n hl07 get pods -o wide
kubectl -n hl07 get svc
```

---

## 8. Демонстрация Swagger UI (обязательно)

## 8.1 Через port-forward

```bash
kubectl -n hl07 port-forward service/zil-app-nodeport 18083:8083
kubectl -n hl07 port-forward service/zil-additional-nodeport 18084:8084
```

Проверка:

- `http://127.0.0.1:18083/swagger-ui/index.html`
- `http://127.0.0.1:18084/swagger-ui/index.html`

## 8.2 Через NodePort

На `hl07`:

```bash
curl -I http://127.0.0.1:32083/swagger-ui/index.html
curl -I http://127.0.0.1:32084/swagger-ui/index.html
```

Если открываете из локального браузера, сделайте SSH туннель:

```bash
ssh -p 2307 -L 32083:127.0.0.1:32083 -L 32084:127.0.0.1:32084 hl@hlssh.zil.digital
```

После этого:

- `http://127.0.0.1:32083/swagger-ui/index.html`
- `http://127.0.0.1:32084/swagger-ui/index.html`

---

## 9. Демонстрация внутреннего доступа additional -> app

Проверка сервисного имени `zil-app-internal` внутри namespace:

```bash
kubectl -n hl07 run curl-tmp --rm -it --restart=Never --image=curlimages/curl -- \
  curl -sS http://zil-app-internal:8083/stats
```

Если получен ответ, внутренний сервисный доступ работает.

---

## 10. Чек-лист защиты LAB14

- узел `hl07` подключён в кластер и `Ready`
- `kubectl` на вашем узле работает
- namespace `hl07` создан
- есть `ConfigMap`, `Secret` БД, `Secret` DockerHub
- есть 2 `Deployment` и 3 `Service`
- для обоих сервисов ресурсы `cpu=1`, `memory=1Gi` (Guaranteed)
- в ENV есть `DB_HOST=10.60.3.9`
- в ENV есть `KAFKA_HOSTS=10.60.3.12,10.60.3.13`
- Swagger UI обоих сервисов показан через `port-forward`
- Swagger UI обоих сервисов показан через `NodePort`
