import http from 'k6/http';
import { check } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8083';
const CREATE_SHARE = Math.min(1, Math.max(0, Number(__ENV.CREATE_SHARE ?? '0.5')));

// Шаг 2: в каждой итерации либо POST /clients, либо GET /stats — доля задаётся CREATE_SHARE (по умолчанию 0.5 = пополам).

export const options = {
  scenarios: {
    lab4: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 5 },
        { duration: '45s', target: 10 },
        { duration: '45s', target: 20 },
        { duration: '30s', target: 0 },
      ],
      gracefulRampDown: '20s',
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
