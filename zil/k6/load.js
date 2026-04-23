// LAB4, k6: половина виртуальных пользователей шлёт POST /clients, половина — GET /stats.
// Сколько всего "пользователей" (VU) — переменная TARGET_VUS. Как поделить — POST_SHARE (0.5 = пополам).
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const timePost = new Trend('post_ms');
const timeGet = new Trend('get_ms');

const baseUrl = __ENV.BASE_URL || 'http://localhost:8083';
const howManyPost = Number(__ENV.POST_SHARE || '0.5');
const totalVu = Number(__ENV.TARGET_VUS || '10');

const vuForPost = Math.min(totalVu, Math.floor(totalVu * howManyPost));
const vuForGet = totalVu - vuForPost;

const upDown = (maxVu) => [
  { duration: '15s', target: maxVu },
  { duration: '45s', target: maxVu },
  { duration: '15s', target: 0 },
];

export const options = {
  scenarios: {
    only_post: {
      executor: 'ramping-vus',
      exec: 'doPost',
      startVUs: 0,
      stages: upDown(vuForPost),
      gracefulRampDown: '15s',
    },
    only_get: {
      executor: 'ramping-vus',
      exec: 'doGet',
      startVUs: 0,
      stages: upDown(vuForGet),
      gracefulRampDown: '15s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.15'],
  },
};

const jsonHeader = { headers: { 'Content-Type': 'application/json' } };

function randomUuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const n = (Math.random() * 16) | 0;
    return (c === 'x' ? n : (n & 0x3) | 0x8).toString(16);
  });
}

export function doPost() {
  const body = JSON.stringify({
    fullName: `k6 u${__VU} i${__ITER}`,
    driverLicense: 'DL-' + randomUuid(),
    phone: `+7900${String(__VU).padStart(2, '0')}${String(__ITER).padStart(6, '0')}`,
  });
  const res = http.post(`${baseUrl}/clients`, body, jsonHeader);
  timePost.add(res.timings.duration);
  check(res, { ok: (r) => r.status === 200 });
  sleep(0.05);
}

export function doGet() {
  const res = http.get(`${baseUrl}/stats`);
  timeGet.add(res.timings.duration);
  check(res, { ok: (r) => r.status === 200 });
  sleep(0.05);
}
