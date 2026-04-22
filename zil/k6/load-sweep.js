/**
 * Тот же сценарий, что в load.js (шаг 2: POST/GET stats, CREATE_SHARE), но constant-vus — для графика avg vs VU.
 * При правке load.js — скопируйте сюда тело export default function.
 *
 *   k6 run -e TARGET_VUS=10 -e DURATION=45s --summary-export summary-10.json load-sweep.js
 */
import http from 'k6/http';
import { check } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8083';
const CREATE_SHARE = Math.min(1, Math.max(0, Number(__ENV.CREATE_SHARE ?? '0.5')));
const vus = Math.max(1, Number(__ENV.TARGET_VUS || '10'));
const duration = __ENV.DURATION || '45s';

export const options = {
  scenarios: {
    lab4_sweep: {
      executor: 'constant-vus',
      vus,
      duration,
    },
  },
};

export default function () {
  if (Math.random() < CREATE_SHARE) {
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
  } else {
    const res = http.get(`${BASE_URL}/stats`, {
      tags: { endpoint: 'stats' },
    });
    check(res, { 'GET /stats ok': (r) => r.status === 200 });
  }
}
