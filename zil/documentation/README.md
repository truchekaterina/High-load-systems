# Документация (LAB6–LAB13)

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
| [LAB13_MANUAL_FULL_RU.md](LAB13_MANUAL_FULL_RU.md) | **LAB13**: единый гайд — §**0** пошагово (SSH, команды); нагрузка **прокси + k6 `http.post`**, batch listener, матрица CPU × concurrency, топик **`hl07`**, **2 партиции** |
| [LAB13_PLAN_RU.md](LAB13_PLAN_RU.md) | Ссылка на **LAB13_MANUAL_FULL_RU.md** (дубль не поддерживается) |
| [README_K6_LABS_RU.md](README_K6_LABS_RU.md) | Как связаны **k6**, папки отчётов, `plot_*.py` и `docker-compose` для LAB6–LAB8 |

**Запуск приложения:** комментарии в корне `zil/docker-compose.yml`, переменные и теги образов — в `registry-tags-lab8-hl7.env` (или аналог под ваш стенд).
