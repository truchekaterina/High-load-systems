# Документация (LAB6–LAB14)

Краткий указатель по текущему контуру курса.

| Документ | Содержание |
|----------|------------|
| [LAB6_PLAN_RU.md](LAB6_PLAN_RU.md) | ВМ, Docker, лимиты CPU/RAM, Harbor, k6 (const VU, смеси POST/GET), Swagger |
| [SWAGGER_GUIDE_RU.md](SWAGGER_GUIDE_RU.md) | OpenAPI / Swagger UI, вызовы API из браузера |
| [LAB7_REPEAT_MANUAL_PGADMIN_SEED_K6_RU.md](LAB7_REPEAT_MANUAL_PGADMIN_SEED_K6_RU.md) | Повтор прогонов после выноса PostgreSQL на узел БД (hl12), pgAdmin, сиды |
| [LAB8_PLAN_RU.md](LAB8_PLAN_RU.md) | Сервис **Additional** (8084), образы, k6, графики |
| [LAB9_MANUAL_FULL_RU.md](LAB9_MANUAL_FULL_RU.md) | **LAB9**: `ObservabilityService`, тайминги, ВМ (hl07/hl11/hl12), образы, k6, логи, графики — пошагово |
| [LAB10_MANUAL_FULL_RU.md](LAB10_MANUAL_FULL_RU.md) | **LAB10**: кеш в Additional, `@Scheduled`, прогоны с CPU 0.5/1.0, k6 и логи |
| [LAB11_MANUAL_FULL_RU.md](LAB11_MANUAL_FULL_RU.md) | **LAB11**: Kafka KRaft в Docker Swarm (hl14/hl15), топики, Kafka UI, SSH-туннели (минимальный и продвинутый режимы) |
| [LAB12_IMPLEMENTATION_MANUAL_FULL_RU.md](LAB12_IMPLEMENTATION_MANUAL_FULL_RU.md) | **LAB12**: план реализации — консьюмер в основном `app`, `concurrency`/партиции, контракт JSON, команды Kafka CLI/Python, локальный compose hl-module2, роли ВМ |
| [LAB13_MANUAL_FULL_RU.md](LAB13_MANUAL_FULL_RU.md) | **LAB13**: единый гайд; топик эксперимента **`hl07-lab13`** (2 партиции), **`registry-tags-lab13-topic.env`**, прокси + k6, batch, матрица CPU × concurrency |
| [LAB13_PLAN_RU.md](LAB13_PLAN_RU.md) | Ссылка на **LAB13_MANUAL_FULL_RU.md** (дубль не поддерживается) |
| [LAB14_MANUAL_FULL_RU.md](LAB14_MANUAL_FULL_RU.md) | **LAB14**: подключение `hl07` к k3s, настройка `kubectl`, YAML-манифесты (Namespace/ConfigMap/Secret/Deployment/Service), проверки `port-forward` и `NodePort` |
| [README_K6_LABS_RU.md](README_K6_LABS_RU.md) | Как связаны **k6**, папки отчётов, `plot_*.py` и `docker-compose` для LAB6–LAB8 |

**Запуск приложения:** комментарии в корне `zil/docker-compose.yml`, переменные и теги образов — в `registry-tags-lab8-hl7.env` (или аналог под ваш стенд).
