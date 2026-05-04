/**
 * LAB8 k6: Additional service S2S endpoints.
 *
 * Main run defaults to 100% availability_new requests:
 *   BASE_URL=http://localhost:8084 TARGET_VUS=20 DURATION=3m k6 run load-lab8-s2s.js
 *
 * Optional path override (absolute URL or path under BASE_URL):
 *   AVAILABILITY_PATH=/additional/cars/availability_new
 *
 * Optional mixed run (STATS_SHARE is a fraction from 0 to 1):
 *   STATS_SHARE=0.5 k6 run load-lab8-s2s.js
 *
 * Trend names intentionally stay post_ms/get_ms so existing simple plotting
 * helpers can read the summary JSON without extra mapping.
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const timeAvailability = new Trend('post_ms');
const timeStats = new Trend('get_ms');

const baseUrl = (__ENV.BASE_URL || 'http://localhost:8084').replace(/\/+$/, '');
const totalVu = Number(__ENV.TARGET_VUS || '20');
const duration = __ENV.DURATION || '3m';
const rawStatsShare = Number(__ENV.STATS_SHARE || '0');
const statsShare = Math.min(1, Math.max(0, rawStatsShare));

function resolveAvailabilityUrl() {
  const raw = __ENV.AVAILABILITY_PATH || '/additional/cars/availability_new';
  const trimmed = raw.trim();
  if (/^https?:\/\//i.test(trimmed)) {
    return trimmed.replace(/\/+$/, '');
  }
  const rel = trimmed.replace(/^\/+/, '').replace(/\/+$/, '');
  return `${baseUrl}/${rel}`;
}

const availabilityUrl = resolveAvailabilityUrl();

export const options = {
  vus: totalVu,
  duration,
  summaryTrendStats: ['avg', 'p(95)', 'min', 'med', 'max'],
  thresholds: {
    http_req_failed: ['rate<0.15'],
  },
};

export default function () {
  if (Math.random() < statsShare) {
    const res = http.get(`${baseUrl}/additional/stats`);
    timeStats.add(res.timings.duration);
    check(res, { ok: (r) => r.status === 200 });
  } else {
    const res = http.get(availabilityUrl);
    timeAvailability.add(res.timings.duration);
    check(res, { ok: (r) => r.status === 200 });
  }

  sleep(0.05);
}
