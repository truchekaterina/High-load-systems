# LAB11 — Kafka KRaft в Docker Swarm: пошаговый практикум (hl14/hl15)

Документ для лабораторной работы LAB11 по инфраструктуре Kafka в режиме KRaft на Docker Swarm.
Сценарий опирается на практику из статьи ZIL про Kafka+KRaft+Swarm и на стандартные команды Kafka CLI для учебного стенда.

---

## 0) Что должно получиться в конце

После выполнения шагов у вас должно быть:

- доступ к узлам `hl14.zil` (SSH порт `2314`) и `hl15.zil` (SSH порт `2315`);
- понимание состояния Docker Swarm и Kafka-сервисов по логам/статусам;
- рабочая папка вида `/home/hl/<variant>` (пример: `/home/hl/hl07`) на `hl15`;
- топик по вашему варианту (в этом прогоне использовалось имя `hl07`);
- название топика внесено в требуемую колонку Google Sheets;
- доступ к Kafka UI через SSH-туннель;
- возможность с локальной машины отправлять дополнительные сообщения в созданный топик (раздел 8).

---

## 0.1) Текущее состояние и что уже сделано (вариант hl07)

Факты по завершенному прогону LAB11 (актуальное состояние на этом проекте):

- рабочий вариант: `hl07`;
- рабочий каталог создан: `/home/hl/hl07`;
- проверки кластера/сервисов выполнены на `hl15` (`docker node ls`, `docker stack services`, `docker service logs ...`);
- сообщения в топик успешно отправлены и подтверждены чтением (CLI/UI).

Важно: ниже сохраняется шаблонный формат `<variant>` для повторного использования, но все конкретные примеры в этом документе приведены для `hl07`.

---

## 0.2) Порты и доступы (фактические значения этого прогона)

- SSH gateway host: `hlssh.zil.digital`;
- SSH порт `2314` -> `hl14`, SSH порт `2315` -> `hl15`;
- Kafka UI локально: `127.0.0.1:8080`;
- Kafka broker forwards:
  - `127.0.0.1:19094` -> `hl15:9094`;
  - `127.0.0.1:19095` -> `hl14:9094`.

---

## 0.3) SSH алиасы в профиле пользователя (Windows)

Рекомендуемый файл: `%USERPROFILE%\.ssh\config`.

Ниже два рабочих режима. Используйте один из них:

- режим A (рекомендуется с автоскриптом): без `LocalForward` в alias `zil-hl15`;
- режим B (ручной): с `LocalForward` в alias `zil-hl15`, но без `start-kafka-ui-tunnel.ps1`.

Режим A:

```sshconfig
Host zil-hl14
    HostName hlssh.zil.digital
    User hl
    Port 2314
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

Host zil-hl15
    HostName hlssh.zil.digital
    User hl
    Port 2315
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

Режим B (если хотите всё поднимать только alias-командой):

```sshconfig
Host zil-hl15
    HostName hlssh.zil.digital
    User hl
    Port 2315
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    LocalForward 8080 127.0.0.1:8080
    LocalForward 19094 hl15.zil:9094
    LocalForward 19095 hl14.zil:9094
```

Зачем это нужно:

- `IdentityFile` фиксирует используемый ключ;
- `IdentitiesOnly yes` исключает перебор лишних ключей SSH-клиентом;
- в режиме A скрипт сам поднимает tunnel и fallback;
- в режиме B alias `zil-hl15` сразу поднимает forwards для UI и обоих брокеров.

---

## 1) Вход на hl14.zil и hl15.zil (в указанном порядке)

Подключение выполняется через общий SSH-шлюз курса:

```powershell
ssh -p 2314 hl@hlssh.zil.digital
```

Это вход на `hl14.zil`.

Во втором терминале:

```powershell
ssh -p 2315 hl@hlssh.zil.digital
```

Это вход на `hl15.zil`.

### Проверка, что вы точно на нужном узле

На каждом узле выполните:

```bash
hostname -f
hostname -I
whoami
```

Ожидаемо:

- на первом сеансе имя содержит `hl14.zil`;
- на втором сеансе имя содержит `hl15.zil`;
- пользователь: `hl`.

---

## 2) Проверка Docker Swarm и Kafka-сервисов

> Практическое правило: команды `docker node ls`, `docker stack services`, `docker service logs` выполняйте на manager-узле (обычно `hl15`).

### 2.1 Проверка кластера Swarm

На `hl15`:

```bash
docker info | grep -i swarm
docker node ls
```

Что проверить:

- Swarm активен (`Swarm: active`);
- есть минимум два узла (например `hl14` и `hl15`);
- один узел в роли `Leader`.

### 2.2 Проверка сервисов Kafka-стека

Если стек называется `kafka_stack`:

```bash
docker stack services kafka_stack
docker stack ps --no-trunc kafka_stack
```

> В вашем стенде имена стека/сервисов могут отличаться. Если видите другие названия, подставьте их во все команды ниже.

Дополнительно по всем сервисам:

```bash
docker service ls
```

Что проверить:

- сервисы Kafka (`kafka-1`, `kafka-2`) и `kafka-ui` находятся в состоянии `Running`;
- нет постоянных `Rejected`/`Failed` задач в `docker stack ps`.

### 2.3 Проверка логов Kafka и Kafka UI

На `hl15`:

```bash
docker service logs kafka_stack_kafka-1 --tail 120
docker service logs kafka_stack_kafka-2 --tail 120
docker service logs kafka_stack_kafka-ui --tail 120
```

Для наблюдения в реальном времени:

```bash
docker service logs kafka_stack_kafka-1 -f
```

Что считать нормой:

- у Kafka нет бесконечных рестартов;
- в логах отсутствуют постоянные ошибки quorum/controller;
- `kafka-ui` поднялся и слушает порт `8080`.

---

## 3) Подключение с локальной машины к hl15.zil

С локального ПК (PowerShell):

```powershell
ssh -p 2315 hl@hlssh.zil.digital
```

Это основной операционный узел для дальнейших шагов LAB11.

Проверка:

```bash
hostname -f
pwd
```

---

## 4) Создание рабочей директории варианта

На `hl15` создайте каталог в формате `/home/hl/<variant>`.

Пример для варианта `hl07`:

```bash
mkdir -p /home/hl/hl07
cd /home/hl/hl07
pwd
```

Проверка:

- `pwd` возвращает `/home/hl/hl07`;
- у вас есть права на запись в каталог.

---

## 5) Создание топика по номеру варианта

Ниже команды в формате Kafka CLI. Если Kafka распакована, например, в `~/kafka_2.13-3.7.1`, перейдите в этот каталог:

```bash
cd ~/kafka_2.13-3.7.1
```

В этом прогоне использовалось имя топика `hl07`.
Для повторного запуска можно применять ваш шаблон именования (например `<variant>` или `<variant>-topic`), но используйте один формат последовательно в командах и Google Sheet.

```bash
bin/kafka-topics.sh --create \
  --topic hl07 \
  --partitions 1 \
  --replication-factor 1 \
  --bootstrap-server hl15.zil:9094
```

Пояснение по `--replication-factor`:

- `1` — минимальный учебный вариант, подойдёт когда нужна простая сдача и нет требования к отказоустойчивости.
- `2` — предпочтительно в двухузловом стенде, если нужно переживать отказ одного брокера.
- значение RF не должно превышать число доступных брокеров в кластере.

Проверка, что топик создан:

```bash
bin/kafka-topics.sh --describe \
  --topic hl07 \
  --bootstrap-server hl15.zil:9094
```

И общая проверка списка:

```bash
bin/kafka-topics.sh --list --bootstrap-server hl15.zil:9094
```

Если в вашем стенде нужен другой `bootstrap-server` (например `hl14.zil:9094`), берите адрес из текущей схемы кластера/методички.

Если на `hl15` нет локальной распаковки Kafka CLI (`~/kafka_2.13-3.7.1`), используйте контейнерный fallback:

```bash
docker ps --format "{{.Names}}" | grep -E "kafka|broker"
# пример запуска CLI внутри найденного контейнера:
docker exec -it <kafka_container_name> kafka-topics --list --bootstrap-server hl15.zil:9094
```

---

## 6) Внести имя топика в Google Sheet

После успешного создания топика:

1. Откройте выданный Google Sheet для LAB11.
2. Найдите строку своего варианта.
3. Впишите точное имя созданного топика в требуемую колонку (без лишних пробелов).

Рекомендуется сразу сверить:

- совпадает ли регистр имени (`hl07` не равно `HL07`);
- не добавлены ли случайно префиксы/суффиксы.

---

## 7) Проверка Kafka UI через SSH-туннель

Используйте команду из задания (локально, в отдельном терминале):

```powershell
ssh -p 2315 -L 8080:127.0.0.1:8080 hl@hlssh.zil.digital
```

Пока этот терминал открыт, в браузере на локальной машине откройте:

- `http://localhost:8080/`

### 7.1 Автозапуск туннеля при открытии проекта (Windows, локально)

В репозитории добавлена автоматизация для Windows:

- скрипт запуска: `zil/scripts/start-kafka-ui-tunnel.ps1`;
- скрипт остановки: `zil/scripts/stop-kafka-ui-tunnel.ps1`;
- автозадача VS Code: `.vscode/tasks.json` (task с `runOn: folderOpen`).

Что делает автозапуск:

- при открытии папки в VS Code запускает проверку туннеля `8080 -> 127.0.0.1:8080` на `hl15`;
- сначала пытается поднять туннель через alias `zil-hl15` (режим A: alias без `LocalForward`);
- если запуск через alias не удался, автоматически делает fallback на `ssh -p 2315 hl@hlssh.zil.digital`;
- для запуска SSH включает неинтерактивные опции `BatchMode`, `ExitOnForwardFailure`, `ConnectTimeout`;
- не поднимает дубликат туннеля, если он уже существует;
- при неуспешной проверке готовности после старта удаляет только что поднятый `ssh`-процесс и завершает скрипт с ошибкой;
- открывает `http://127.0.0.1:8080/` в браузере.

Как отключить/включить:

- отключить: в `.vscode/tasks.json` убрать блок `"runOptions": { "runOn": "folderOpen" }`;
- включить обратно: вернуть этот блок в ту же задачу.

Ручной запуск/остановка:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\zil\scripts\start-kafka-ui-tunnel.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\zil\scripts\stop-kafka-ui-tunnel.ps1
```

Остановка туннеля выполняется по PID-файлу `zil/scripts/kafka-ui-tunnel.pid`, который создаёт стартовый скрипт. `stop-kafka-ui-tunnel.ps1` завершает только managed-туннель из этого PID-файла.

Проверка в UI:

- виден Kafka-кластер;
- в списке топиков присутствует ваш топик (`hl07` в примере);
- можно открыть карточку топика и увидеть метаданные.

---

## 8) SSH-туннелирование для удалённой Kafka-работы и запись сообщений с локальной машины

Этот шаг нужен, чтобы локально запускать producer/consumer и отправлять дополнительные сообщения в ваш топик.

### 8.1 Минимальный режим (один туннель, только если нужно быстро проверить)

Однотуннельный вариант иногда срабатывает, но может ломаться: Kafka может вернуть в metadata второй broker, которого нет в локальном туннеле.
Используйте его только как временный быстрый тест.

```powershell
ssh -p 2315 -L 8080:127.0.0.1:8080 -L 19094:hl15.zil:9094 hl@hlssh.zil.digital
```

Локальный bootstrap для этого режима:

```text
--bootstrap-server 127.0.0.1:19094
```

### 8.2 Рекомендуемый режим (по умолчанию): мульти-брокерный туннель

Этот режим устойчивее и должен быть основным для LAB11.

Для Windows PowerShell:

```powershell
ssh -p 2315 -L 8080:127.0.0.1:8080 -L 19094:hl15.zil:9094 -L 19095:hl14.zil:9094 hl@hlssh.zil.digital
```

Для Linux/macOS:

```bash
ssh -p 2315 -L 8080:127.0.0.1:8080 -L 19094:hl15.zil:9094 -L 19095:hl14.zil:9094 hl@hlssh.zil.digital
```

Используйте в командах один из прокинутых bootstrap (`127.0.0.1:19094` или `127.0.0.1:19095`).

### 8.3 Продвинутый режим: алиасы `hl14.zil`/`hl15.zil` на localhost

Нужен, если хотите локально обращаться по именам узлов.

Linux:

```bash
sudo ip addr add 127.0.0.2/8 dev lo
sudo ip addr add 127.0.0.3/8 dev lo
```

macOS:

```bash
sudo ifconfig lo0 alias 127.0.0.2 up
sudo ifconfig lo0 alias 127.0.0.3 up
```

Windows:

- обычно используйте режим 8.2 без loopback-алиасов;
- при необходимости алиасы настраиваются отдельно через сетевые интерфейсы/hosts.

Добавьте в hosts:

```text
127.0.0.2 hl15.zil
127.0.0.3 hl14.zil
```

Туннель с явной привязкой к двум брокерам:

```powershell
ssh -p 2315 -L 8080:127.0.0.1:8080 -L 127.0.0.2:9094:hl15.zil:9094 -L 127.0.0.3:9094:hl14.zil:9094 hl@hlssh.zil.digital
```

### 8.4 Отправить дополнительные сообщения в топик (локально)

На локальной машине из каталога Kafka CLI.

Для Linux/macOS (или Git Bash/WSL):

```bash
bin/kafka-console-producer.sh \
  --topic hl07 \
  --bootstrap-server 127.0.0.1:19094
```

Для Windows PowerShell:

```powershell
.\bin\windows\kafka-console-producer.bat --topic hl07 --bootstrap-server 127.0.0.1:19094
```

Если локально нет Kafka CLI, используйте fallback в контейнере на `hl15`:

```bash
docker exec -it <kafka_container_name> kafka-console-producer --topic hl07 --bootstrap-server hl15.zil:9094
```

Введите несколько сообщений, например:

```text
lab11 extra message 1
lab11 extra message 2
```

Завершение producer:

- Linux/macOS: `Ctrl+D`;
- Windows (PowerShell/cmd): `Ctrl+Z`, затем `Enter`.

### 8.5 Проверить, что сообщения реально записались

Локально (или на `hl15`) запустите consumer:

Для Linux/macOS (или Git Bash/WSL):

```bash
bin/kafka-console-consumer.sh \
  --topic hl07 \
  --bootstrap-server 127.0.0.1:19094 \
  --from-beginning \
  --group hl07-lab11-check-local
```

Для Windows PowerShell:

```powershell
.\bin\windows\kafka-console-consumer.bat --topic hl07 --bootstrap-server 127.0.0.1:19094 --from-beginning --group hl07-lab11-check-local
```

Должны отобразиться отправленные строки.

Альтернативная проверка через Kafka UI:

- открыть топик;
- посмотреть messages/offsets;
- убедиться, что появились новые записи.

---

## 9) Мини-чеклист сдачи LAB11

- Есть доступ по SSH к `2314` и `2315`.
- Проверено состояние Swarm (`docker node ls`) и сервисов (`docker stack services`).
- Проверены логи Kafka/Kafka UI (`docker service logs ...`).
- Создан каталог `/home/hl/<variant>`.
- Создан топик по варианту и проверен `describe/list`.
- Имя топика занесено в нужную колонку Google Sheet.
- Kafka UI доступен через туннель `ssh -p 2315 -L 8080:127.0.0.1:8080 ...`.
- С локальной машины отправлены дополнительные сообщения и проверено чтение.

---

## 10) Практические замечания и troubleshooting (по этому прогону)

- Если `127.0.0.1:8080` уже занят существующим SSH-процессом, не поднимайте дублирующий туннель.
- `zil/scripts/stop-kafka-ui-tunnel.ps1` останавливает только managed-туннель из `kafka-ui-tunnel.pid`. Если туннель поднимали вручную, закройте соответствующую SSH-сессию вручную.
- После изменений в `%USERPROFILE%\.ssh\config` переподключите SSH-сессию, иначе новые `LocalForward` могут не примениться.
- Если на локальной машине нет Kafka CLI, допустимая локальная операция для LAB11 - использовать Kafka UI (`http://127.0.0.1:8080`) для Produce и затем проверить появление сообщений в топике.

---

## 11) Пароли, ключи и секреты

### 11.1 Почему «положить пароль в файл в репозитории» не решает ввод автоматически

OpenSSH (в т. ч. Windows) **не умеет** хранить пароль к серверу в `ssh config` или в произвольном файле так, чтобы `ssh hl@…` сам подставил пароль. Для этого в Unix иногда ставят утилиты вроде `sshpass` — такой сценарий обычно неудобнее, чем нормальная ключевая авторизация.

### 11.2 Как не вводить пароль при каждом подключении (рекомендуется для учебного проекта)

Сделайте **отдельный ключ только для этого курса** и сгенерируйте его **без passphrase** (ключ не шифруется на диске — приемлемо для изолированного учебного доступа):

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\id_ed25519_zil_nopass" -N "" -C "zil-course-nopass"
```

Дальше в `ssh config` укажите для `zil-hl14`/`zil-hl15` именно этот файл:

```sshconfig
IdentityFile ~/.ssh/id_ed25519_zil_nopass
IdentitiesOnly yes
```

На стороне курсового доступа нужен ваш **public key** в authorized_keys учётки `hl` (как уже сделано для основного ключа).

После этого `ssh zil-hl15` выполняется **без ввода пароля и passphrase**.

### 11.3 Если всё-таки хочется хранить пароль текстом локально

- Создайте файл в папке `zil/secrets/` (например `zil/secrets/passwords.txt`): она добавлена в `.gitignore` и **не уйдёт в git**.
- Это будет просто блокнот для ручного ввода, не автоматическое подключение OpenSSH.

### 11.4 Чего не делать без необходимости

- не класть пароли и приватные ключи в общие маркдауны или скрипты, которые лежат под контролем git;
- не коммитить файл `zil/scripts/kafka-ui-tunnel.pid` (локальный PID туннеля).

---

## 12) Быстрые команды диагностики

На `hl15`:

```bash
docker stack services kafka_stack
docker stack ps --no-trunc kafka_stack
docker service logs kafka_stack_kafka-1 --tail 200
docker service logs kafka_stack_kafka-2 --tail 200
docker service logs kafka_stack_kafka-ui --tail 200
```

Kafka CLI:

```bash
bin/kafka-topics.sh --list --bootstrap-server hl15.zil:9094
bin/kafka-topics.sh --describe --topic hl07 --bootstrap-server hl15.zil:9094
```

---

Если внешняя методичка временно недоступна, используйте этот план как базовый рабочий сценарий: он покрывает операционный порядок действий и контрольные проверки для LAB11.
