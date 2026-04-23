/**
 * LAB4 (стиль «смешанной нагрузки»): два параллельных пула виртуальных пользователей (VU):
 *   • post_clients — только POST /clients (создание клиента)
 *   • get_stats    — только GET /stats
 *
 * Оба сценария используют executor `ramping-vus` с одинаковой *формой* ступеней (разгон → плато → сброс),
 * но с *разным* пиковым числом VU: доля POST и GET задаётся через POST_SHARE.
 *
 * Имена Trend-метрик совпадают с plot_avg_vs_vus.py:
 *   k6_post_clients_ms, k6_get_stats_ms — попадают в --summary-export для графика POST vs GET.
 *
 * Переменные окружения (__ENV / k6 run -e):
 *   BASE_URL    — база API (по умолчанию http://localhost:8083)
 *   TARGET_VUS  — суммарное «целевое» число VU для разбиения на два пула (задаёт run-sweep.ps1 / вручную)
 *   POST_SHARE  — доля VU под POST в диапазоне [0..1], остальное — GET (по умолчанию 0.5 = пополам)
 *
 * Примеры:
 *   k6 run rental-mixed.js
 *   TARGET_VUS=40 POST_SHARE=0.5 k6 run --summary-export reports/summary-vus-40.json rental-mixed.js
 */
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

/** Средние длительности по типу запроса — отдельные кривые на графике. */
const k6PostClientsMs = new Trend('k6_post_clients_ms');
const k6GetStatsMs = new Trend('k6_get_stats_ms');

const baseUrl = __ENV.BASE_URL || 'http://localhost:8083';
const postShare = Number(__ENV.POST_SHARE || '0.5');
/** Суммарный «бюджет» VU; из него считаются два целочисленных пула. */
const targetVus = Number(__ENV.TARGET_VUS || '10');

/**
 * Целочисленное разбиение: postVuPool + getVuPool === targetVus
 * (как у коллеги: floor(targetVus * postShare), остаток на GET).
 */
const postVuPool = Math.min(targetVus, Math.floor(targetVus * postShare));
const getVuPool = targetVus - postVuPool;

/**
 * Одна «волна» ramping: разгон до peak → держим → спад к 0.
 * Длительности как в референсе: 15s / 45s / 15s.
 */
const rampStages = (peak) => [
  { duration: '15s', target: peak },
  { duration: '45s', target: peak },
  { duration: '15s', target: 0 },
];

export const options = {
  scenarios: {
    post_clients: {
      executor: 'ramping-vus',
      exec: 'postClients',
      startVUs: 0,
      stages: rampStages(postVuPool),
      gracefulRampDown: '15s',
    },
    get_stats: {
      executor: 'ramping-vus',
      exec: 'getStats',
      startVUs: 0,
      stages: rampStages(getVuPool),
      gracefulRampDown: '15s',
    },
  },
  thresholds: {
    /** Не более 15% HTTP-ошибок (наглядный «потолок» для отчёта). */
    http_req_failed: ['rate<0.15'],
  },
};

const jsonHeaders = { headers: { 'Content-Type': 'application/json' } };

/** UUID v4 локально — без импорта jslib (иначе k6 тянет source map и пишет WARN). */
function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/** Пул 1: только создание клиентов (нагрузка на запись в БД). */
export function postClients() {
  const body = JSON.stringify({
    fullName: `k6 vu${__VU} iter${__ITER}`,
    driverLicense: `DL-${uuidv4()}`,
    phone: `+79${String(__VU).padStart(2, '0')}${String(__ITER).padStart(8, '0')}`,
  });
  const res = http.post(`${baseUrl}/clients`, body, jsonHeaders);
  k6PostClientsMs.add(res.timings.duration);
  check(res, { 'POST /clients 200': (r) => r.status === 200 });
  sleep(0.05);
}

/** Пул 2: только чтение статистики. */
export function getStats() {
  const res = http.get(`${baseUrl}/stats`, {
    tags: { endpoint: 'stats' },
  });
  k6GetStatsMs.add(res.timings.duration);
  check(res, { 'GET /stats 200': (r) => r.status === 200 });
  sleep(0.05);
}
