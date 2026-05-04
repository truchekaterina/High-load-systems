# Документация (LAB6–LAB9)

Краткий указатель по текущему контуру курса.

| Документ | Содержание |
|----------|------------|
| [LAB6_PLAN_RU.md](LAB6_PLAN_RU.md) | ВМ, Docker, лимиты CPU/RAM, Harbor, k6 (const VU, смеси POST/GET), Swagger |
| [SWAGGER_GUIDE_RU.md](SWAGGER_GUIDE_RU.md) | OpenAPI / Swagger UI, вызовы API из браузера |
| [LAB7_REPEAT_MANUAL_PGADMIN_SEED_K6_RU.md](LAB7_REPEAT_MANUAL_PGADMIN_SEED_K6_RU.md) | Повтор прогонов после выноса PostgreSQL на узел БД (hl12), pgAdmin, сиды |
| [LAB8_PLAN_RU.md](LAB8_PLAN_RU.md) | Сервис **Additional** (8084), образы, k6, графики |
| [LAB9_MANUAL_FULL_RU.md](LAB9_MANUAL_FULL_RU.md) | **LAB9**: `ObservabilityService`, тайминги, ВМ (hl07/hl11/hl12), образы, k6, логи, графики — пошагово |
| [README_K6_LABS_RU.md](README_K6_LABS_RU.md) | **LAB8–LAB9**: k6 на **8084**, каталоги отчётов, **`plot_lab8_reports.py`** |

**Запуск приложения:** комментарии в корне `zil/docker-compose.yml`, переменные и теги образов — в `registry-tags-lab8-hl7.env` (или аналог под ваш стенд).
