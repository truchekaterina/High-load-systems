/**
 * Тот же смысл, что load.js: два параллельных пула (POST и GET), но constant-vus — для графика avg vs VU.
 * TARGET_VUS — желаемая суммарная нагрузка; пополам делим между пулами (при нечётном — 1 VU в одном пуле больше).
 *
 * Все точки + график одной командой (summary-*.json и PNG перезаписываются при каждом запуске):
 *   python run_sweep_and_plot.py
 *
 * Одна точка вручную:
 *   k6 run -e TARGET_VUS=10 -e DURATION=45s --summary-export summary-10.json load-sweep.js
 */
import http from 'k6/http';
import { check } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8083';
// Минимум 2: иначе один из пулов был бы с 0 VU (k6 не запустит сценарий).
const target = Math.max(2, Number(__ENV.TARGET_VUS || '10'));
const vusPost = Math.floor(target / 2);
const vusGet = target - vusPost;
const duration = __ENV.DURATION || '45s';

export const options = {
  scenarios: {
    post_clients: {
      executor: 'constant-vus',
      vus: vusPost,
      duration,
      exec: 'postClients',
    },
    get_stats: {
      executor: 'constant-vus',
      vus: vusGet,
      duration,
      exec: 'getStats',
    },
  },
};

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
  check(res, { 'POST /clients ok': (r) => r.status === 200 });
}

export function getStats() {
  const res = http.get(`${BASE_URL}/stats`, {
    tags: { endpoint: 'stats' },
  });
  check(res, { 'GET /stats ok': (r) => r.status === 200 });
}
