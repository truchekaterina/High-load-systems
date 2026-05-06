/**
 * LAB13: нагрузка записи в Kafka через REST-прокси (k6 → HTTP POST → Producer → hl07).
 *
 * Обязательно:
 *   PROXY_URL=http://127.0.0.1:18080/publish k6 run load-lab13-kafka-proxy.js
 *
 * Опционально:
 *   BASE_URL, STATS_SHARE (доля GET /additional/stats vs POST прокси; как LAB8: 0.05 / 0.5 / 0.95 для матрицы mix05/mix50/mix95).
 * Метрики Trend post_ms / get_ms — для графиков как LAB8 (lab13_latency_vs_cpu*.png).
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

/** Имена как в load-lab8-s2s.js — общий формат summary для plot_lab13_reports.py (LAB8-стиль панелей). */
const timeProxyPost = new Trend('post_ms');
const timeStatsGet = new Trend('get_ms');

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
    timeStatsGet.add(res.timings.duration);
    check(res, { 'stats 200': (r) => r.status === 200 });
  } else {
    const body = buildUserPostBody();
    const res = http.post(proxyUrl, body, {
      headers: { 'Content-Type': 'application/json' },
    });
    timeProxyPost.add(res.timings.duration);
    check(res, {
      'publish 200': (r) => r.status === 200,
    });
  }
  sleep(0.05);
}
