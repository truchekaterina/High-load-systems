# LAB7+: пошаговый мануал «как повторить» — pgAdmin, приложение hl07, PostgreSQL hl12, k6 hl11, seed.py

Этот документ собирает последовательность действий и типичные ошибки из учебной отладки: **восстановление pgAdmin**, **проверка сети и приложения**, **учётные данные БД**, **нагрузка k6 server→server**, **заполнение БД через `seed.py`** и **ручная очистка через `TRUNCATE`**.

Типичные номера SSH-портов (сверять с вашей таблицей курса):

| ВМ           | Роль                         | SSH (пример)                            |
| ------------ | ---------------------------- | --------------------------------------- |
| hl07 или аналог | приложение Zil (Docker `zil-app`) | `ssh -p 2307 hl@hlssh.zil.digital`   |
| hl11 или аналог | k6-тесты                      | `ssh -p 2311 hl@hlssh.zil.digital`      |
| hl12 или аналог | PostgreSQL + pgAdmin (Docker)| `ssh -p 2312 hl@hlssh.zil.digital`      |

Пароли к **`hl`** на хост берите из методички/таблицы курса; **не сохраняйте пароли в публичных репозиториях.**

---

## Часть 1. Что считать «упал pgAdmin»

pgAdmin в учебном стенде чаще всего работает как **Docker-контейнер**. «Упал» обычно значит один из вариантов:

- контейнер **`Exited`** / в цикле **Restarting**;
- ВМ (**hl12**) перезагрузили или выполняли **`docker compose down`**;
- закрыли браузер **или SSH-туннель** с ПК (страница перестала открываться, хотя контейнер жив);
- контейнеру не хватило RAM / повредился том.

---

## Часть 2. На hl12: проверить и поднять pgAdmin и PostgreSQL

**Зачем:** убедиться, что процессы в Docker действительно работают.

### 2.1. Войти на сервер БД

```powershell
ssh -p 2312 hl@hlssh.zil.digital
```

Подставьте **свой** порт, если другой.

### 2.2. Перейти в каталог с `docker-compose`

У вас compose лежал в домашнем каталоге `~` (`~/docker-compose.yaml`). Если файл в другом месте — выполните `cd` туда же.

```bash
cd ~
```

### 2.3. Посмотреть статус контейнеров

```bash
docker compose ps
```

**Ожидание:** у сервисов **`postgres`** и **`pgadmin`** состояние **Up** и не **Restarting**.

### 2.4. Если pgAdmin или postgres не в статусе Up

Поднять pgAdmin явно:

```bash
docker compose up -d pgadmin
```

Если не поднимается с первого раза — поднять весь файл:

```bash
docker compose up -d
```

Посмотреть последние логи pgAdmin при сбое:

```bash
docker logs pgadmin --tail 50
```

**Зачем лог:** при нехватке памяти, ошибке конфигурации или битом томе в конце будет причина (OOM, Exception и т.д.).

### 2.5. Зайти в pgAdmin из браузера на своём ПК

Порт проброса в compose у вас был **`5051:80`** у pgAdmin (**внешний порт 5051** на хосте hl12 значит то, что с localhost по туннелю нужно пробрасывать на **5051**).

Откройте **отдельный** PowerShell (не закрывая сеанс) и выполните **SSH-порт‑форвардинг**:

```powershell
ssh -p 2312 -L 5051:127.0.0.1:5051 hl@hlssh.zil.digital
```

**Зачем:** трафик с вашего **`http://localhost:5051`** идёт в зашифрованный канал SSH и попадает на **127.0.0.1:5051** на hl12 — туда же смотрит Docker.

После успешного входа по паролю `hl` **окно этого SSH не закрывайте**, пока работает pgAdmin в браузере.

В браузере:

```text
http://localhost:5051
```

### 2.6. Логин и пароль первого входа в веб-приложение pgAdmin

Они задаются в **`.env`** рядом с `docker-compose` на hl12 (**не путать** с пользователем PostgreSQL **`postgres`**).

```bash
grep PGADMIN ~/.env
```

Обычно это **`PGADMIN_DEFAULT_EMAIL`** и **`PGADMIN_DEFAULT_PASSWORD`**.

**Зачем отдельно:** пароль пользователя базы данных **`postgres`** / **`hl_postgres`** нужен уже при **регистрации сервера** в дереве Servers в pgAdmin, а первый вход в веб-интерфейс использует переменные **PGADMIN_\*** из `.env`.

---

## Часть 3. Сеть между ВМ: почему k6 не может достучаться до приложения

### 3.1. На ВМ приложения (hl07) узнать внутренний IP в учебной сети

```bash
ip -4 -br a
```

На **`tun0`** или аналоге VPN часто будет адрес вида **`10.60.3.x/24`** — **его** нужно использовать в **`BASE_URL` для k6** (например **`10.60.3.2`**, если именно ваш адрес там).

Интерфейс **`eth0`** с **`192.168.x.x`** — другая подсеть; к6-ВМ к нему может не иметь прямого маршрута, ориентируйтесь на **`10.60.3.x`**.

### 3.2. Проверка с ВМ приложения до самого приложения

```bash
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8083/stats
```

**Ожидание:** `200`. Пока здесь не **200**, k6 будет получать ошибки.

### 3.3. Проверка с ВМ k6 до приложения по внутреннему IP

```bash
curl -sS -o /dev/null -w "%{http_code}\n" http://10.60.3.2:8083/stats
```

Подставьте **ваш** IP из п. 3.1.

**Если `connection refused`:** на целевой ВМ на **8083** ничего не слушает (Docker не запущен, контейнер падает) или указан не тот IP.

**Если `no route to host` / долгий timeout:** между ВМ нет маршрута до **`10.60.3.x`** (нет VPN-туннеля на k6-ВМ, не тот адрес).

---

## Часть 4. Контейнер `zil-app` в цикле Restarting на hl07 — что смотреть

Статус:

```bash
docker ps -a
docker compose ps
```

Журнал приложения:

```bash
docker logs zil-app --tail 120
```

### Частая ошибка: `password authentication failed for user "hl7"`

Приложение по JDBC подключается под **`hl7`**, а в PostgreSQL была настроена другая связка (на hl12 из `.env` часто задаётся **`POSTGRES_USER=postgres`**, **`POSTGRES_PASSWORD=hl_postgres`**). Варианты:

- задать роли **`hl7`** пароль и использовать его в приложении; **или**
- выровнять [zil/docker-compose.yml](../docker-compose.yml) под учётную запись **`postgres`** / **`hl_postgres`**, как в рабочем примере с курса (в вашем проекте по умолчанию сейчас):

```yaml
SPRING_DATASOURCE_USERNAME: ${SPRING_DATASOURCE_USERNAME:-postgres}
SPRING_DATASOURCE_PASSWORD: ${SPRING_DATASOURCE_PASSWORD:-hl_postgres}
```

После смены env:

```bash
cd ~/work/Labs_hls/zil
docker compose up -d --force-recreate app
```

Затем:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8083/stats
```

---

## Часть 5. Обновить код на ВМ после `git push` с вашего ПК

На **любой** ВМ с клоном репозитория:

```bash
cd ~/work/Labs_hls
git fetch origin
git status
git pull origin lab7
```

Если ветка уже настроена на отслеживание **`origin/lab7`**, достаточно:

```bash
git pull
```

**Зачем:** подтянуть правки **`docker-compose.yml`**, **`seed.py`**, документацию.

---

## Часть 6. Коротко: собрать образ и отправить на Docker Hub (опционально)

На ВМ со свежим кодом в каталоге **`zil`** с **`Dockerfile`**:

```bash
cd ~/work/Labs_hls/zil
docker login
docker build -t truchekaterina/zil-app:lab7 .
docker push truchekaterina/zil-app:lab7
```

Подставьте **своё** имя на Docker Hub. На hl07 затем можно **`docker compose pull app`** и пересоздать контейнер.

---

## Часть 7. Нагрузка k6 «сервер → сервер» при лимите **2 CPU** у контейнера app

Именование отчётов в проекте: **`cpu20`** соответствует **2.0** ядер (`APP_CPUS=2.0`).

### 7.1. На ВМ приложения (hl07)

```bash
cd ~/work/Labs_hls/zil
export APP_CPUS=2.0
docker compose pull app
docker compose up -d --force-recreate app
```

Подождать 1–2 минуты, проверить **`curl`** к **`/stats`**.

### 7.2. На ВМ k6 (hl11)

```bash
cd ~/work/Labs_hls/zil/k6
mkdir -p reports-lab7-s2s

export BASE_URL="http://10.60.3.2:8083"
export LAB6_CONST=1
export TARGET_VUS=20
export DURATION=3m

k6 run --summary-export="$PWD/reports-lab7-s2s/s2s_cpu20_mix05.json" -e POST_SHARE=0.05 load.js
k6 run --summary-export="$PWD/reports-lab7-s2s/s2s_cpu20_mix50.json" -e POST_SHARE=0.5 load.js
k6 run --summary-export="$PWD/reports-lab7-s2s/s2s_cpu20_mix95.json" -e POST_SHARE=0.95 load.js
```

Подставьте свой **`BASE_URL`** (IP приложения из п. 3.1).

### 7.3. Замечание про порт **6565** в k6

Если видите **`listen tcp 127.0.0.1:6565: bind: address already in use`**, на порту уже висит другой процесс **`k6`**. Освободить:

```bash
ss -tlnp | grep 6565
# или
sudo fuser -k 6565/tcp
```

Сам прогон нагрузки при этом может продолжать работать (предупреждение служебного API).

---

## Часть 8. Заливка **по ~1000 строк в clients, cars, rents** через `seed.py` на hl07

Скрипт [zil/seed.py](../seed.py) ходит в HTTP API; для **трёх таблиц сразу** используется режим **`rents`**: создаются **count** клиентов, **count** машин и **count** аренд.

### 8.1. Зависимости Python через venv (Debian `externally-managed-environment`)

На hl07:

```bash
cd ~/work/Labs_hls/zil
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install requests faker
```

**Зачем venv:** в Debian **`pip install` в системный Python** блокируется (PEP 668); внутри виртуального окружения ставится без `--break-system-packages`.

Если команда создания **`venv`** падает:

```bash
sudo apt install -y python3-full
python3 -m venv .venv
```

### 8.2. Файл [zil/requirements.txt](../requirements.txt)

Если строка второго комментария **без символа `#`**, `pip install -r requirements.txt` выдаст **invalid requirement**. Временное решение: **`pip install requests faker`** (см. п. 8.1). Корректно в файле вторую строку сделать комментарием: `# (см. seed.py ...)`.

### 8.3. Увеличить таймаут HTTP в `seed.py`

По умолчанию **`TIMEOUT = 10`** секунд; **`POST /dev/clear`** и массовые вставки могут идти дольше.

**Вариант А — через `sed`** (ставим 300 секунд):

```bash
cd ~/work/Labs_hls/zil
sed -i 's/^TIMEOUT = 10$/TIMEOUT = 300/' seed.py
grep '^TIMEOUT' seed.py
```

**Вариант Б — редактором:** открыть `seed.py`, заменить константу **`TIMEOUT`** вручную.

### 8.4. Запуск

```bash
cd ~/work/Labs_hls/zil
source .venv/bin/activate
python seed.py --endpoint rents --count 1000 --base-url http://127.0.0.1:8083
```

После успешного **`TRUNCATE`** можно добавить **`--no-clear`**, если не хотите снова вызывать **`/dev/clear`**.

---

## Часть 9. Если `POST /dev/clear` отдаёт **500** при большом объёме данных

### 9.1. Диагностика

Ответ без подавления тела:

```bash
curl -sS -X POST "http://127.0.0.1:8083/dev/clear?clear=all" --max-time 300
docker logs zil-app --tail 80
```

В логах Hibernate может быть проверка **ожидается 1 удалённая строка, затронуто 0** (конкуренция запросов к API или тяжёлый цикл удаления по одной записи).

**Рекомендация перед clear:** не запускать **k6** и не гонять **seed параллельно**.

### 9.2. Жёсткая очистка на hl12 через `psql` (минуя API)

Без этого SQL **как команд shell** не выполняются.

Вход в клиент **`psql`** (имя контейнера было **`postgres`**):

```bash
docker exec -it postgres psql -U postgres -d hl7
```

Внутри `psql` (приглашение `hl7=#` или аналог). Сначала таблицы по сути в схеме **`hl7`**, см. свой Flyway/V1):

```sql
SET search_path TO hl7, public;
TRUNCATE TABLE rents, cars, clients RESTART IDENTITY CASCADE;
\q
```

**Ошибка в bash вида `-bash: TRUNCATE: command not found`** означает, что SQL вводился **не внутри psql**.

Однострочно из shell:

```bash
docker exec -it postgres psql -U postgres -d hl7 -c "SET search_path TO hl7, public; TRUNCATE TABLE rents, cars, clients RESTART IDENTITY CASCADE;"
```

Если просят пароль суперпользователя Postgres:

```bash
PGPASSWORD=hl_postgres docker exec -it postgres psql -U postgres -d hl7 ...
```

Подставьте пароль **`POSTGRES_PASSWORD`** из вашего **`~/.env`** на hl12.

После этого снова запустите **`seed.py`**.

---

# Приложение: ошибки и что с ними делать

## A. «ModuleNotFoundError: No module named 'faker'»

**Причина:** пакеты не установлены в том интерпретаторе, которым запускаете скрипт.  
**Решение:** создать **`venv`**, активировать **`source .venv/bin/activate`**, установить **`pip install requests faker`**.

---

## B. Debian: `externally-managed-environment`

**Причина:** PEP 668 — **`pip`** в системный интерпретатор запрещён.  
**Решение:** использовать **`python3 -m venv .venv`** и ставить зависимости внутрь venv; не использовать **`--break-system-packages`** без необходимости.

---

## C. `ERROR: Invalid requirement` при `pip install -r requirements.txt`

**Причина:** строка документации в **`requirements.txt`** без **`#`** в начале строки (частично сохранённые комментарии в файле попали второй строкой как «название пакета»).  
**Решение:** временно **`pip install requests faker`**; поправить вторую строку на **`# (см. ...)`** в репозитории или в локальной копии.

---

## D. Seed: «Read timed out» на `POST /dev/clear`

**Причина:** **`TIMEOUT = 10`** в **`seed.py`** слишком мал для операции очистки/вставки.  
**Решение:** поднять **`TIMEOUT`** до **120–300** с (см. часть 8.3).

---

## E. `curl` `/dev/clear` → HTTP **500**, в логах Hibernate **delete**.

**Причина:** конфликт при удалении по сущности (гонка транзакций, ожидание «одна строка», фактически **0 строк**).

**Что пробовать:**

1. Остановить нагрузку (k6, параллельные запросы), повторить clear.
2. Очистить таблицы **`TRUNCATE`** в **`psql`** на hl12 (часть 9.2).

---

## F. pgAdmin «не открывается», но **`docker compose ps`** показывает Up.

**Причина:** закрыто окно SSH с **локальным порт-форвардом**, или браузер смотрит не на **`localhost:5051`** (или другой порт из вашего `ports:` для pgAdmin).  
**Решение:** заново выполнить туннель **`ssh -L 5051:127.0.0.1:5051`** (порт свой), не закрывать SSH при работе в браузере.

---

## G. Контейнер **`zil-app`** в **Restarting**

**Причины:** недоступен PostgreSQL (**хост/порт/пароль**), долгая миграция Flyway при первом контакте, иные ошибки JVM.  

**Что делать:**

```bash
docker logs zil-app --tail 120
```

Сверить **`SPRING_DATASOURCE_*`**, доступность **`DBHOST`** с hl07 (**`hl12.zil`** порт **`DBPORT`**), совпадение пароля с PostgreSQL на hl12.

---

## H. Таблицы пустые в pgAdmin после `TRUNCATE`, но seed не нужен только «в Postgres»

Подключение приложения через Spring идёт в **`hl7`**, схема **`hl7`** в вашем приложении задаётся **`SCHEMANAME`**. Если в pgAdmin дерево Servers настроено на другую схему/БД, таблицы «не там». Проверяйте **`search_path`** и список:

```sql
\dt hl7.*
SELECT COUNT(*) FROM hl7.clients;
```

---

Конец мануала. Перед каждой сдачей **сверьте порты SSH, имена контейнеров и содержимое `.env`** с актуальной таблицей курса и своими правками на сервере.
