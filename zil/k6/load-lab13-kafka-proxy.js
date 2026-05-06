/**
 * LAB13: нагрузка записи в Kafka через REST-прокси (k6 → HTTP POST → Producer → hl07).
 *
 * Обязательно:
 *   PROXY_URL=http://127.0.0.1:18080/publish k6 run load-lab13-kafka-proxy.js
 *
 * Опционально (как LAB8):
 *   TARGET_VUS DURATION BASE_URL STATS_SHARE — лёгкий GET к additional /stats
 */

import http from 'k6/http';
import { check, sleep } from 'k6';

const proxyUrl = (__ENV.PROXY_URL || '').trim();
if (!proxyUrl) {
  throw new Error(
    'Задайте PROXY_URL (например http://127.0.0.1:18080/publish). См. LAB13_MANUAL_FULL_RU §0.6'
  );
}

const totalVu = Number(__ENV.TARGET_VUS || '20');
const duration = __ENV.DURATION || '3m';
const baseUrl = (__ENV.BASE_URL || 'http://localhost:8084').replace(/\/+$/, '');
const rawStatsShare = Number(__ENV.STATS_SHARE || '0');
const statsShare = Math.min(1, Math.max(0, rawStatsShare));

export const options = {
  vus: totalVu,
  duration,
  summaryTrendStats: ['avg', 'p(95)', 'min', 'med', 'max'],
  thresholds: {
    http_req_failed: ['rate<0.25'],
  },
};

function buildUserPostBody() {
  const id = `${__VU}_${__ITER}_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
  return JSON.stringify({
    entity: 'USER',
    operation: 'POST',
    payload: {
      fullName: `lab13 ${id}`,
      driverLicense: `DL-${id}`,
      phone: '+70000000001',
    },
  });
}

export default function () {
  if (Math.random() < statsShare) {
    const res = http.get(`${baseUrl}/additional/stats`);
    check(res, { 'stats 200': (r) => r.status === 200 });
  } else {
    const body = buildUserPostBody();
    const res = http.post(proxyUrl, body, {
      headers: { 'Content-Type': 'application/json' },
    });
    check(res, {
      'publish 200': (r) => r.status === 200,
    });
  }
  sleep(0.05);
}
