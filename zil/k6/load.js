/**
 * k6: POST /clients + GET /stats, метрики post_ms и get_ms.
 *
 * Режим LAB4 (по умолчанию):
 *   ramping-vus, два сценария only_post / only_get, доли VU по POST_SHARE.
 *   TARGET_VUS, POST_SHARE, BASE_URL — как в материалах курса для ранних лаб.
 *
 * Режим LAB6 (const VU, фиксированная длительность, микс 5/95 …):
 *   LAB6_CONST=1
 *   TARGET_VUS — число VU (не менять между прогонами в рамках одного графика)
 *   POST_SHARE — доля итераций с POST (0.05, 0.5, 0.95)
 *   DURATION — напр. 3m
 *   Пример: LAB6_CONST=1 TARGET_VUS=20 POST_SHARE=0.05 DURATION=3m k6 run load.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const timePost = new Trend('post_ms');
const timeGet = new Trend('get_ms');

const baseUrl = __ENV.BASE_URL || 'http://localhost:8083';
const howManyPost = Number(__ENV.POST_SHARE || '0.5');
const totalVu = Number(__ENV.TARGET_VUS || '10');
const isLab6 = __ENV.LAB6_CONST === '1';

const vuForPost = Math.min(totalVu, Math.floor(totalVu * howManyPost));
const vuForGet = totalVu - vuForPost;

const upDown = (maxVu) => [
  { duration: '15s', target: maxVu },
  { duration: '45s', target: maxVu },
  { duration: '15s', target: 0 },
];

const lab4Options = {
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

const lab6Options = {
  vus: totalVu,
  duration: __ENV.DURATION || '3m',
  summaryTrendStats: ['avg', 'p(95)', 'min', 'med', 'max'],
  thresholds: {
    http_req_failed: ['rate<0.15'],
  },
};

export const options = isLab6 ? lab6Options : lab4Options;

const jsonHeader = { headers: { 'Content-Type': 'application/json' } };

function randomUuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const n = (Math.random() * 16) | 0;
    return (c === 'x' ? n : (n & 0x3) | 0x8).toString(16);
  });
}

function k6Phone() {
  return `+7900${String(__VU).padStart(2, '0')}${String(__ITER).padStart(6, '0')}`;
}

/**
 * LAB6: один VU-цикл — с вероятностью POST_SHARE идёт POST, иначе GET.
 * (Сценарии LAB4 в этом режиме не используются; работает default.)
 */
export default function () {
  if (!isLab6) {
    return;
  }
  if (Math.random() < howManyPost) {
    const body = JSON.stringify({
      fullName: `k6 u${__VU} i${__ITER}`,
      driverLicense: 'DL-' + randomUuid(),
      phone: k6Phone(),
    });
    const res = http.post(`${baseUrl}/clients`, body, jsonHeader);
    timePost.add(res.timings.duration);
    check(res, { ok: (r) => r.status === 200 || r.status === 201 });
  } else {
    const res = http.get(`${baseUrl}/stats`);
    timeGet.add(res.timings.duration);
    check(res, { ok: (r) => r.status === 200 });
  }
  sleep(0.05);
}

export function doPost() {
  const body = JSON.stringify({
    fullName: `k6 u${__VU} i${__ITER}`,
    driverLicense: 'DL-' + randomUuid(),
    phone: k6Phone(),
  });
  const res = http.post(`${baseUrl}/clients`, body, jsonHeader);
  timePost.add(res.timings.duration);
  check(res, { ok: (r) => r.status === 200 || r.status === 201 });
  sleep(0.05);
}

export function doGet() {
  const res = http.get(`${baseUrl}/stats`);
  timeGet.add(res.timings.duration);
  check(res, { ok: (r) => r.status === 200 });
  sleep(0.05);
}
