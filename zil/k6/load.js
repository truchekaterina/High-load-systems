/**
 * LAB4 — сценарий нагрузочного теста для k6.
 *
 * Идея простыми словами:
 * - «Виртуальные пользователи» (VU) — это не люди, а одновременно работающие циклы k6.
 *   Каждый VU в цикле: сделал запрос → чуть подождал (sleep) → снова запрос.
 * - Часть VU в сценарии only_post шлёт POST /clients (создают клиентов).
 *   Другая часть в only_get шлёт GET /stats (статистика по кэшу/счётчикам).
 * - Сколько VU вообще — задаётся TARGET_VUS (извне, например из run-lab4.ps1).
 *   Как поделить между POST и GET — POST_SHARE (0.5 = половина на POST, половина на GET).
 * - Метрики post_ms и get_ms — это «тренды»: k6 накапливает время ответа; в итоге в summary JSON
 *   появляется avg (среднее), min, max, перцентили — график строит именно avg.
 */

// Стандартный модуль k6 для HTTP-запросов.
import http from 'k6/http';
// check — мини-assert: прошёл ли запрос (GET обычно 200; POST на создание — 200 или 201). sleep — пауза между итерациями.
import { check, sleep } from 'k6';
// Trend — кастомная метрика: мы сами кладём туда длительность в миллисекундах.
import { Trend } from 'k6/metrics';

// Две кривые на графике: среднее время POST и среднее время GET (имена видны в summary JSON).
const timePost = new Trend('post_ms');
const timeGet = new Trend('get_ms');

// База URL API. Можно переопределить: BASE_URL=https://... k6 run load.js
// В run-lab4.ps1 по умолчанию под Docker на хосте — localhost:8083.
const baseUrl = __ENV.BASE_URL || 'http://localhost:8083';

// Доля VU, которые пойдут в сценарий с POST. 0.5 = 50% (округление вниз, см. ниже).
const howManyPost = Number(__ENV.POST_SHARE || '0.5');

// Целевое число «пользователей» для этого прогона. Один и тот же load.js, разные TARGET_VUS — разная нагрузка.
const totalVu = Number(__ENV.TARGET_VUS || '10');

// Сколько VU отводим под POST: не больше totalVu, и floor — целое число (например 10 * 0.5 = 5).
const vuForPost = Math.min(totalVu, Math.floor(totalVu * howManyPost));
// Остаток — на GET. В сумме vuForPost + vuForGet === totalVu (кроме странных float, тут целые).
const vuForGet = totalVu - vuForPost;

/**
 * Профиль нагрузки: три ступени «лесенка вверх — держим — лесенка вниз».
 * ramping-vus executor: target — сколько VU к концу ступени.
 * 15s разгон → 45s полка → 15s сход на 0. Итого ~75s активной фазы + graceful stop в options.
 * @param {number} maxVu — максимальное число VU в этом сценарии (post или get).
 */
const upDown = (maxVu) => [
  { duration: '15s', target: maxVu },
  { duration: '45s', target: maxVu },
  { duration: '15s', target: 0 },
];

// Настройки прогона: два параллельных сценария с разными exec-функциями.
export const options = {
  scenarios: {
    // Сценарий 1: только POST /clients, столько VU, сколько посчитали для поста.
    only_post: {
      executor: 'ramping-vus', // плавно меняем число VU по ступеням
      exec: 'doPost', // ниже export function doPost
      startVUs: 0,
      stages: upDown(vuForPost),
      gracefulRampDown: '15s', // при остановке не рубить VU мгновенно
    },
    // Сценарий 2: только GET /stats, VU = vuForGet.
    only_get: {
      executor: 'ramping-vus',
      exec: 'doGet',
      startVUs: 0,
      stages: upDown(vuForGet),
      gracefulRampDown: '15s',
    },
  },
  // Порог: если больше 15% HTTP-запросов с ошибкой — k6 завершит с ненулевым кодом (для CI/скриптов).
  thresholds: {
    http_req_failed: ['rate<0.15'],
  },
};

// Заголовок для JSON-тела; сервер ждёт application/json.
const jsonHeader = { headers: { 'Content-Type': 'application/json' } };

/**
 * Псевдо-UUID v4 в виде строки. Нужен уникальный driverLicense (в БД, скорее всего, unique).
 * Не криптостойкий; для теста хватает.
 */
function randomUuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const n = (Math.random() * 16) | 0;
    return (c === 'x' ? n : (n & 0x3) | 0x8).toString(16);
  });
}

/**
 * Один «шаг» сценария only_post: создать клиента POST-ом.
 * __VU — номер виртуального пользователя, __ITER — номер итерации (цикла) у этого VU.
 * Поля — как в API: fullName, driverLicense, phone (см. ClientController/модель).
 */
export function doPost() {
  const body = JSON.stringify({
    fullName: `k6 u${__VU} i${__ITER}`,
    driverLicense: 'DL-' + randomUuid(),
    phone: `+7900${String(__VU).padStart(2, '0')}${String(__ITER).padStart(6, '0')}`,
  });
  const res = http.post(`${baseUrl}/clients`, body, jsonHeader);
  // res.timings.duration — длительность в ms; кладём в Trend для avg в отчёте.
  timePost.add(res.timings.duration);
  // check не роняет VU, только помечает passed/failed в summary.
  // 201 Created — типичный ответ Spring на POST; 200 тоже допустим — оба считаем успехом (иначе растёт http_req_failed).
  check(res, { ok: (r) => r.status === 200 || r.status === 201 });
  // Небольшая пауза, иначе все VU долбят с нулевой задержкой (нереалистично и может забить CPU).
  sleep(0.05);
}

/**
 * Один «шаг» only_get: запросить агрегированную статистику (кэш + счётчики в рамках LAB4).
 */
export function doGet() {
  const res = http.get(`${baseUrl}/stats`);
  timeGet.add(res.timings.duration);
  check(res, { ok: (r) => r.status === 200 });
  sleep(0.05);
}
