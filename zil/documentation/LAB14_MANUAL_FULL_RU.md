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
- `Secret` для DockerHub доступа к образу **`app`** (реальный создаётся вручную; в git — шаблон `03-secret-dockerhub-template.yaml`)
- `Secret` для Harbor доступа к образу **`additional`** (реальный создаётся вручную; в git — шаблон `03-secret-harbor-template.yaml`)
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

## 5.4б `k8s/lab14/03-secret-harbor-template.yaml` (в git только шаблон)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: harbor-regcred
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
      hostAliases:
        - ip: "10.60.3.12"
          hostnames:
            - "hl14.zil"
        - ip: "10.60.3.13"
          hostnames:
            - "hl15.zil"
      imagePullSecrets:
        - name: dockerhub-regcred
      containers:
        - name: app
          image: docker.io/rinakt/zil-app:lab9
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
            - name: KAFKA_HOSTS
              valueFrom:
                configMapKeyRef:
                  name: zil-config
                  key: KAFKA_HOSTS
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

Дополнительный сервис должен работать на **отдельной** worker-ноде кластера, а не на ВМ **hl07**, где обычно стоят kubectl и k3s-agent. В манифесте задано `nodeAffinity`: узел с `kubernetes.io/hostname=hl07` исключён.

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
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: kubernetes.io/hostname
                    operator: NotIn
                    values:
                      - hl07
      imagePullSecrets:
        - name: harbor-regcred
      containers:
        - name: additional
          image: 10.60.3.11:8888/katya/zil-additional-service:lab14-swagger
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

## 6. Секреты реестров (создаются вручную, в git только шаблоны)

### 6.1 Docker Hub — только для образа **основного** `app`

Реальный секрет создаётся командой, а не хранится в git:

```bash
kubectl -n hl07 create secret docker-registry dockerhub-regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<DOCKERHUB_USER> \
  --docker-password='<DOCKERHUB_PASSWORD_OR_TOKEN>' \
  --docker-email='<YOUR_EMAIL>' \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 6.2 Harbor — для образа **additional**

Harbor развёрнут на отдельной ВМ реестра (**SSH `2313`** на `hlssh.zil.digital`, внутренний IP **`10.60.3.11`**). На этой машине обычно делают **`docker login`** и **`docker push`** вашего `zil-additional-service` в проект Harbor.

В Kubernetes нужен **отдельный** pull-secret (имя в манифесте — **`harbor-regcred`**). Подставьте URL реестра такой же, как в `docker login` (часто **`https://hl13.zil:8888`** по методичке курса; если у вас другой hostname — используйте его):

```bash
kubectl -n hl07 create secret docker-registry harbor-regcred \
  --docker-server=https://hl13.zil:8888 \
  --docker-username=admin \
  --docker-password='<ПАРОЛЬ_HARBOR_ИЗ_ТАБЛИЦЫ>' \
  --docker-email='<YOUR_EMAIL>' \
  --dry-run=client -o yaml | kubectl apply -f -
```

Шаблон без секретов в репозитории: `k8s/lab14/03-secret-harbor-template.yaml`.

**Замечание по стенду:** `kubelet` на нодах качает образ **до** запуска Pod и использует **DNS самой ноды**, а не `hostAliases` Pod. Если при образе `hl13.zil:8888/...` получаете `lookup hl13.zil: no such host` или `HTTP response to HTTPS client`, в **`05-additional-deployment.yaml`** для pull используется **`10.60.3.11:8888/...`** (IP Harbor из таблицы), а в **`kubectl create secret`** указывайте `--docker-server=http://10.60.3.11:8888` (Harbor часто на HTTP). Логин/пароль — из таблицы курса для Harbor.

Если из подов не резолвится **`hl13.zil`** для исходящих запросов приложения (не для pull), можно добавить **`hostAliases`** в Pod (или согласовать DNS с преподавателем).

---

## 7. Применение манифестов

```bash
cd ~/work/Labs_hls/zil/k8s/lab14

kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-configmap.yaml
kubectl apply -f 02-secret-db.yaml
# Перед деплоем additional создайте dockerhub-regcred и harbor-regcred (§6).
kubectl apply -f 04-app-deployment.yaml
kubectl apply -f 05-additional-deployment.yaml
kubectl apply -f 06-services.yaml

kubectl -n hl07 get all
kubectl -n hl07 get pods -o wide
kubectl -n hl07 get svc
```

Для показа работы лабораторной преподавателю используйте **раздел 8** (пошаговый сценарий: `apply`, `port-forward`, NodePort, внутренний сервис).

---

## 8. Сдача преподавателю: пошаговый сценарий демонстрации по ТЗ

Ниже — **единый сценарий**, который закрывает формулировки ТЗ: узел в кластере, манифесты через `kubectl apply -f`, **Swagger обоих** сервисов через **`port-forward`**, **Swagger обоих** через **NodePort**, внутренний доступ **additional → app** (§10).

### 8.1 Где запускать команды (важно для защиты)

| Что делаете | Где |
|-------------|-----|
| **`kubectl`** (в том числе `apply`, `get`, **`port-forward`**) | Только на **ВМ hl07** после настройки `~/.kube/config` (раздел 6). Там API кластера доступен по VPN. |
| Браузер со Swagger | На **hl07** (если есть графика / проброс дисплея) **или** на **домашнем ПК (Windows)** через **SSH-туннель** (ниже). |

**Не запускайте `kubectl` на домашнем Windows без kubeconfig:** клиент пытается достучаться до **`http://localhost:8080`**, получает **connection refused** — это не ошибка лабы, а отсутствие контекста кластера.

Зафиксированные в манифестах порты:

- **NodePort основного (`zil-app`):** **32083**
- **NodePort дополнительного (`zil-additional`):** **32084**

Для **`port-forward`** ниже используются локальные порты **18083** и **18084** на стороне той машины, где висит `kubectl` (удобно не путать с NodePort).

### 8.2 Блок 1 — показать развёртывание (ТЗ: успешный `kubectl apply -f`)

На **hl07**, в каталоге с YAML:

```bash
ssh -p 2307 hl@hlssh.zil.digital
cd ~/work/Labs_hls/zil/k8s/lab14
kubectl apply -f 00-namespace.yaml -f 01-configmap.yaml -f 02-secret-db.yaml
kubectl apply -f 04-app-deployment.yaml -f 05-additional-deployment.yaml -f 06-services.yaml
kubectl -n hl07 get pods -o wide
kubectl -n hl07 get svc
```

Преподавателю показываете: поды **`Running`**, сервисы есть (**ClusterIP** `zil-app-internal`, два **NodePort** с портами **32083** и **32084**). Дополнительный сервис по манифесту **не должен** оказаться на узле **`hl07`** — колонка **NODE** у Pod **`zil-additional`** должна быть **другая** worker-нода.

### 8.3 Блок 2 — Swagger через `port-forward` (ТЗ)

Нужны **два** процесса `port-forward` (два сервиса). Их держите **в отдельных терминальных вкладках** на **hl07** (или один — в foreground, второй — во второй SSH-сессии).

**Терминал 1 (SSH → hl07):**

```bash
kubectl -n hl07 port-forward service/zil-app-nodeport 18083:8083
```

Оставить окно открытым; в логе будет `Forwarding from 127.0.0.1:18083 -> 8083`.

**Терминал 2 (второй SSH → hl07):**

```bash
kubectl -n hl07 port-forward service/zil-additional-nodeport 18084:8084
```

Оставить открытым; будет `Forwarding from 127.0.0.1:18084 -> 8084`.

**Если браузер на hl07:** открыть в браузере:

- `http://127.0.0.1:18083/swagger-ui/index.html` — основной сервис  
- `http://127.0.0.1:18084/swagger-ui/index.html` — дополнительный сервис  

**Если браузер на Windows (вариант A):** пока работают оба `port-forward` на hl07, на **ПК** откройте **третье** окно PowerShell и поднимите туннель **без интерактивной оболочки** (`-N`):

```powershell
ssh -p 2307 -N -L 18083:127.0.0.1:18083 -L 18084:127.0.0.1:18084 hl@hlssh.zil.digital
```

Окно с этой командой **не закрывать**. В **Chrome на Windows** открыть те же URL:

- `http://127.0.0.1:18083/swagger-ui/index.html`
- `http://127.0.0.1:18084/swagger-ui/index.html`

Так **127.0.0.1 на ПК** пробрасывается на **127.0.0.1 hl07**, где слушает `kubectl port-forward`.

Если вместо страницы — **connection refused**, проверьте: оба `port-forward` на hl07 запущены, SSH с `-L` не упал, после перезапуска Pod команду `port-forward` **запустите заново** (старый процесс теряет Pod).

### 8.4 Блок 3 — Swagger через NodePort (ТЗ)

**На hl07** (достаточно для показа преподавателю по SSH):

```bash
curl -I http://127.0.0.1:32083/swagger-ui/index.html
curl -I http://127.0.0.1:32084/swagger-ui/index.html
```

Ожидается строка ответа с **`HTTP/1.1 200`** (или `200 OK`).

**Если нужно открыть NodePort в браузере на Windows:** отдельное окно PowerShell:

```powershell
ssh -p 2307 -N -L 32083:127.0.0.1:32083 -L 32084:127.0.0.1:32084 hl@hlssh.zil.digital
```

Затем в браузере:

- `http://127.0.0.1:32083/swagger-ui/index.html`
- `http://127.0.0.1:32084/swagger-ui/index.html`

(При необходимости то же можно делать с VPN-доступной **внутренней IP любой ноды** кластера и теми же **32083** / **32084** — NodePort слушается на каждой ноде.)

### 8.5 Блок 4 — внутренний ClusterIP (ТЗ: доступ статистики к основному сервису)

Выполняется на **hl07**, см. раздел **10**.

### 8.6 Что проговорить преподавателю по чек-листу ТЗ

1. Узел **hl07** в кластере (**разделы 5–6** методички K3S-SETUP / этот документ §2–3).  
2. Все нужные сущности в **`Namespace hl07`**: ConfigMap, Secret БД, Secret Docker Hub (**шаблон в git**), Secret Harbor для pull **additional**, два Deployment, три Service.  
3. **`DB_HOST`** в конфиге совпадает с ТЗ (**10.60.3.9**), **Kafka** — IP **10.60.3.12,10.60.3.13** и при необходимости **hostAliases** в основном приложении (манифест **04**).  
4. Ресурсы подов — **1 CPU / 1 Gi**, **Guaranteed**.  
5. Показали Swagger **дважды**: через **`port-forward`** и через **NodePort**.  

---

## 9. Демонстрация Swagger UI (обязательно)

Образ **additional** с тегом **`lab10`** из Harbor может **не отдавать** Swagger (**404** на `/swagger-ui/...`). Чтобы выполнить ТЗ для **обоих** Swagger UI, соберите и запушьте **`lab14-swagger`** по инструкции [LAB14_ADDITIONAL_SWAGGER_BUILD_RU.md](LAB14_ADDITIONAL_SWAGGER_BUILD_RU.md) и обновите **`05-additional-deployment.yaml`**.

Краткий сценарий показа преподавателю — в **разделе 8**.

## 9.1 Через port-forward

```bash
kubectl -n hl07 port-forward service/zil-app-nodeport 18083:8083
kubectl -n hl07 port-forward service/zil-additional-nodeport 18084:8084
```

Проверка:

- `http://127.0.0.1:18083/swagger-ui/index.html`
- `http://127.0.0.1:18084/swagger-ui/index.html`

## 9.2 Через NodePort

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

## 10. Демонстрация внутреннего доступа additional -> app

Проверка сервисного имени `zil-app-internal` внутри namespace:

```bash
kubectl -n hl07 run curl-tmp --rm -it --restart=Never --image=curlimages/curl -- \
  curl -sS http://zil-app-internal:8083/stats
```

Если получен ответ, внутренний сервисный доступ работает.

---

## 11. Чек-лист защиты LAB14

Пошаговый сценарий сдачи преподавателю — **раздел 8**.

- узел `hl07` подключён в кластер и `Ready`
- `kubectl` на вашем узле работает
- namespace `hl07` создан
- есть `ConfigMap`, `Secret` БД, `Secret` DockerHub (**для app**), `Secret` Harbor (**для additional**, имя `harbor-regcred`)
- есть 2 `Deployment` и 3 `Service`
- для обоих сервисов ресурсы `cpu=1`, `memory=1Gi` (Guaranteed)
- в ENV есть `DB_HOST=10.60.3.9`
- в ENV есть `KAFKA_HOSTS=10.60.3.12,10.60.3.13`
- Swagger UI обоих сервисов показан через `port-forward`
- Swagger UI обоих сервисов показан через `NodePort`
