import http from 'k6/http';
import { check } from 'k6';
import { uuidv4 } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8083';

// Два пула (два сценария) параллельно: один крутит только POST, второй — только GET.
// Суммарно на каждом «плато» 50/50: 3+2=5, 5+5=10, 10+10=20 VU. Рандом не используем.

export const options = {
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
