/**
 * LAB4: два параллельных пула (POST /clients, GET /stats), без рандома.
 *
 * Другой вариант сценария (как у коллеги: везде ramping + TARGET_VUS + POST_SHARE,
 * summary в reports/summary-vus-*.json) — см. `rental-mixed.js` и `run-sweep.sh` / README_LAB4_RU.md.
 *
 * Режим A — ramping-vus (методичка), по умолчанию:
 *   k6 run load.js
 *   k6 run --summary-export summary-ramping.json load.js
 *
 * Режим B — constant-vu для графика avg vs VU; задайте TARGET_VUS (суммарно; пополам по пулам):
 *   k6 run -e TARGET_VUS=10 -e DURATION=45s --summary-export summary-10.json load.js
 * Все точки + PNG: python sweep_plot.py
 *
 * Метрики Trend: post_req_duration, get_req_duration (две линии в sweep_plot.py).
 */
import http from 'k6/http';
import { check } from 'k6';
import { Trend } from 'k6/metrics';

/** UUID v4 без внешнего jslib (иначе k6 качает .map с сети и пишет WARN). */
function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

const postReqDuration = new Trend('post_req_duration');
const getReqDuration = new Trend('get_req_duration');

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8083';

/** С sweep_plot.py / вручную: `-e TARGET_VUS=10` (и опционально `DURATION=45s`). */
const targetVusFromEnv = String(__ENV.TARGET_VUS ?? '').trim();
const runConstantVusForGraph = targetVusFromEnv.length > 0;

/**
 * constant-vu: ровно столько VU, сколько задано в TARGET_VUS (суммарно; пополам POST/GET).
 */
function createConstantVusOptions() {
  const totalVus = Math.max(2, Number(targetVusFromEnv));
  const vusForPostClients = Math.floor(totalVus / 2);
  const vusForGetStats = totalVus - vusForPostClients;
  const runDuration = __ENV.DURATION || '45s';
  return {
    scenarios: {
      post_clients: {
        executor: 'constant-vus',
        vus: vusForPostClients,
        duration: runDuration,
        exec: 'postClients',
      },
      get_stats: {
        executor: 'constant-vus',
        vus: vusForGetStats,
        duration: runDuration,
        exec: 'getStats',
      },
    },
  };
}

/**
 * Без TARGET_VUS: «ступенчатый» ramping (методичка), два параллельных сценария.
 */
function createRampingVusOptions() {
  return {
    scenarios: {
      post_clients: {
        executor: 'ramping-vus',
        startVUs: 0,
        exec: 'postClients',
        stages: [
          { duration: '30s', target: 3 },
          { duration: '45s', target: 5 },
          { duration: '45s', target: 10 },
          { duration: '30s', target: 0 },
        ],
        gracefulRampDown: '20s',
      },
      get_stats: {
        executor: 'ramping-vus',
        startVUs: 0,
        exec: 'getStats',
        stages: [
          { duration: '30s', target: 2 },
          { duration: '45s', target: 5 },
          { duration: '45s', target: 10 },
          { duration: '30s', target: 0 },
        ],
        gracefulRampDown: '20s',
      },
    },
  };
}

export const options = runConstantVusForGraph
  ? createConstantVusOptions()
  : createRampingVusOptions();

export function postClients() {
  const headers = { 'Content-Type': 'application/json' };
  const body = JSON.stringify({
    fullName: `k6 vu${__VU} iter${__ITER}`,
    driverLicense: `DL-${uuidv4()}`,
    phone: `+79${String(__VU).padStart(2, '0')}${String(__ITER).padStart(8, '0')}`,
  });

  const res = http.post(`${BASE_URL}/clients`, body, {
    headers,
    tags: { endpoint: 'create_client' },
  });
  postReqDuration.add(res.timings.duration);
  check(res, { 'POST /clients ok': (r) => r.status === 200 });
}

export function getStats() {
  const res = http.get(`${BASE_URL}/stats`, {
    tags: { endpoint: 'stats' },
  });
  getReqDuration.add(res.timings.duration);
  check(res, { 'GET /stats ok': (r) => r.status === 200 });
}
