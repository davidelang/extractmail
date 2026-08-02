/**
 * Shell e-Receipt HTML parser (Track A / Wave 0).
 * Pure functions: HTML → ParsedFuelReceipt | null.
 *
 * Fuel-only: require fuel volume + fuel amount paid (after discounts).
 * Ignore non-fuel merchandise. Never invent odometer/vehicle/partial flag.
 *
 * Timestamp rule (v1): receipt MM-DD-YYYY + HH:MM:SS treated as UTC wall clock
 * for stable cross-environment epoch ms. Documented in README.
 */

'use strict';

/**
 * @param {string} html
 * @param {Object} [opts]
 * @param {string} [opts.messageKey]
 * @param {string} [opts.gmailMessageId]
 * @returns {import('./parsed-fuel-receipt').ParsedFuelReceipt|null}
 */
function parseShellReceiptHtml(html, opts) {
  opts = opts || {};
  if (!html || typeof html !== 'string') return null;

  // Reject obvious non-Shell if From/body markers both missing (allow fixture HTML)
  const lower = html.toLowerCase();
    if (lower.indexOf('samsclub.com') >= 0 || lower.indexOf("sam's club fuel") >= 0) return null;
  const looksShell =
    lower.indexOf('ereceiptshell') >= 0 ||
    lower.indexOf('shell e-receipt') >= 0 ||
    lower.indexOf('welcome to shell') >= 0 ||
    lower.indexOf('shell oil') >= 0;
  if (!looksShell) return null;

  const text = htmlToText(html);
  const parts = text
    .split(/\n+/)
    .map((s) => s.trim())
    .filter(Boolean);

  const address = extractAddress(parts);
  const { dateStr, timeStr } = extractDateTime(parts);
  const fuel = extractFuelLine(parts);
  const amountPaid = extractAmountPaid(parts, text);

  if (!fuel || fuel.gallons == null || !(fuel.gallons > 0)) return null;
  if (amountPaid == null || !(amountPaid > 0)) return null;
  if (!dateStr || !timeStr) return null;

  const timestampMs = wallTimeToEpochMs(dateStr, timeStr);
  if (timestampMs == null) return null;

  const timestampLocal = toIsoLocal(dateStr, timeStr);
  const siteId = extractSiteId(parts);
  const pump = extractPump(parts);

  const locationBits = [];
  if (address && address.length) locationBits.push(address.join(', '));
  const locationText =
    (locationBits.length ? 'Shell — ' + locationBits.join(', ') : 'Shell').trim();

  const messageKey =
    opts.messageKey ||
    opts.gmailMessageId ||
    ['shell', siteId || 'nosite', timestampLocal || String(timestampMs)].join('|');

  return {
    brand: 'Shell',
    currency: 'USD',
    cost: roundMoney(amountPaid),
    gallons: roundGallons(fuel.gallons),
    timestampMs: timestampMs,
    timestampLocal: timestampLocal,
    locationText: locationText,
    siteId: siteId || undefined,
    pump: pump || undefined,
    product: fuel.product || undefined,
    messageKey: messageKey,
    rawProvenance: {
      dateStr: dateStr,
      timeStr: timeStr,
      fuelTotalPreDiscount: fuel.fuelTotal,
      pricePerGal: fuel.pricePerGal,
    },
  };
}

/**
 * HTML → plain text lines (strip tags, decode common entities, drop scripts).
 * @param {string} html
 */
function htmlToText(html) {
  let s = String(html);
  s = s.replace(/<script[\s\S]*?<\/script>/gi, ' ');
  s = s.replace(/<style[\s\S]*?<\/style>/gi, ' ');
  s = s.replace(/<!--[\s\S]*?-->/g, ' ');
  // br/p/tr/div → newline
  s = s.replace(/<\s*br\s*\/?>/gi, '\n');
  s = s.replace(/<\/\s*(p|div|tr|h[1-6]|li|table)\s*>/gi, '\n');
  s = s.replace(/<\s*td[^>]*>/gi, ' ');
  s = s.replace(/<[^>]+>/g, ' ');
  s = s
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(parseInt(n, 10)))
    .replace(/&[a-z]+;/gi, ' ');
  s = s.replace(/\r/g, '\n');
  s = s.replace(/[ \t]+/g, ' ');
  s = s.replace(/\n[ \t]+/g, '\n');
  s = s.replace(/[ \t]+\n/g, '\n');
  s = s.replace(/\n{2,}/g, '\n');
  return s.trim();
}

/**
 * Station address: street line after "receipt", then city, then ST ZIP.
 * @param {string[]} parts
 * @returns {string[]|null}
 */
function extractAddress(parts) {
  // Find "receipt" welcome line then next 3 lines are street/city/zip-ish
  for (let i = 0; i < parts.length; i++) {
    const p = parts[i];
    if (/here is your/i.test(p) && /receipt/i.test(p)) {
      const street = parts[i + 1];
      const city = parts[i + 2];
      const stZip = parts[i + 3];
      if (street && city && stZip && looksStreet(street) && looksStateZip(stZip)) {
        return [street, city, stZip];
      }
    }
  }
  // Fallback: ST ZIP pattern (e.g. CA 93063-6546)
  for (let i = 2; i < parts.length; i++) {
    if (looksStateZip(parts[i]) && looksStreet(parts[i - 2])) {
      return [parts[i - 2], parts[i - 1], parts[i]];
    }
  }
  return null;
}

function looksStreet(s) {
  return /\d/.test(s) && /[A-Za-z]/.test(s) && s.length >= 5 && s.length < 80;
}

function looksStateZip(s) {
  return /^[A-Z]{2}\s+\d{5}(-\d{4})?$/.test(String(s).trim());
}

/**
 * @param {string[]} parts
 * @returns {{dateStr:string|null, timeStr:string|null}}
 */
function extractDateTime(parts) {
  let dateStr = null;
  let timeStr = null;
  for (const p of parts) {
    const dm = p.match(/^(\d{1,2}-\d{1,2}-\d{4})$/);
    if (dm) dateStr = dm[1];
    const tm = p.match(/^(\d{1,2}:\d{2}:\d{2})$/);
    if (tm) timeStr = tm[1];
  }
  return { dateStr: dateStr, timeStr: timeStr };
}

/**
 * Fuel product row after headers Fuel Type / Gallons / Price/Gal / Fuel Total.
 * @param {string[]} parts
 */
function extractFuelLine(parts) {
  let headerIdx = -1;
  for (let i = 0; i < parts.length - 3; i++) {
    if (
      /^Fuel Type$/i.test(parts[i]) &&
      /^Gallons$/i.test(parts[i + 1]) &&
      /^Price\/Gal$/i.test(parts[i + 2]) &&
      /^Fuel Total$/i.test(parts[i + 3])
    ) {
      headerIdx = i;
      break;
    }
  }
  if (headerIdx < 0) {
    // looser: find Gallons header then product block
    for (let i = 0; i < parts.length - 4; i++) {
      if (/^Gallons$/i.test(parts[i]) && /^Price\/Gal$/i.test(parts[i + 1])) {
        headerIdx = i - 1;
        break;
      }
    }
  }
  if (headerIdx < 0) return null;

  // Next lines: product, gallons, price, fuel total
  const product = parts[headerIdx + 4];
  const gallonsStr = parts[headerIdx + 5];
  const priceStr = parts[headerIdx + 6];
  const fuelTotalStr = parts[headerIdx + 7];

  const gallons = parseNumber(gallonsStr);
  const pricePerGal = parseMoney(priceStr);
  const fuelTotal = parseMoney(fuelTotalStr);

  // Non-fuel guard: must have positive gallons; product should not look like shop junk only
  if (gallons == null || !(gallons > 0)) return null;
  // If fuel total missing but gallons present, still OK if amount paid found later
  return {
    product: product || undefined,
    gallons: gallons,
    pricePerGal: pricePerGal,
    fuelTotal: fuelTotal,
  };
}

/**
 * Prefer "Amount Paid: $X.XX"; else final Total after discount block.
 * @param {string[]} parts
 * @param {string} fullText
 */
function extractAmountPaid(parts, fullText) {
  for (const p of parts) {
    const m = p.match(/Amount\s*Paid\s*:\s*\$?\s*([\d,]+\.\d{2})/i);
    if (m) return parseMoney(m[1]);
  }
  const m2 = fullText.match(/Amount\s*Paid\s*:\s*\$?\s*([\d,]+\.\d{2})/i);
  if (m2) return parseMoney(m2[1]);

  // Fallback: after "Total" label sequence Subtotal / Fuel Discount / Tax / Total → last money before Payment
  let totalIdx = -1;
  for (let i = 0; i < parts.length; i++) {
    if (/^Total$/i.test(parts[i])) totalIdx = i;
  }
  if (totalIdx >= 0) {
    // Look ahead for money amounts: subtotal, discount, tax, total
    const monies = [];
    for (let j = totalIdx + 1; j < Math.min(parts.length, totalIdx + 8); j++) {
      if (/^Payment/i.test(parts[j])) break;
      const v = parseMoney(parts[j]);
      if (v != null) monies.push(v);
    }
    // Shell layout: $subtotal, -$discount, $tax, $total — take last positive non-discount
    if (monies.length >= 1) {
      // Prefer last value which is amount after discount
      return monies[monies.length - 1];
    }
  }
  return null;
}

function extractSiteId(parts) {
  // Site id is numeric block near date (e.g. 57444178305) — 10–12 digits
  for (let i = 0; i < parts.length; i++) {
    if (/^\d{10,14}$/.test(parts[i])) {
      // Prefer one just before MM-DD-YYYY
      if (i + 1 < parts.length && /^\d{1,2}-\d{1,2}-\d{4}$/.test(parts[i + 1])) {
        return parts[i];
      }
    }
  }
  for (const p of parts) {
    if (/^\d{10,14}$/.test(p)) return p;
  }
  return null;
}

function extractPump(parts) {
  for (const p of parts) {
    const m = p.match(/PUMP\s*#\s*(\d+)/i);
    if (m) return m[1];
  }
  return null;
}

function parseMoney(s) {
  if (s == null) return null;
  const t = String(s).replace(/[$,\s]/g, '').replace(/^\((.*)\)$/, '-$1');
  // allow leading -
  const m = t.match(/^(-?\d+(?:\.\d+)?)$/);
  if (!m) return null;
  const n = parseFloat(m[1]);
  return isFinite(n) ? n : null;
}

function parseNumber(s) {
  if (s == null) return null;
  const t = String(s).replace(/,/g, '').trim();
  const n = parseFloat(t);
  return isFinite(n) ? n : null;
}

function roundMoney(n) {
  return Math.round(n * 100) / 100;
}

function roundGallons(n) {
  return Math.round(n * 1000) / 1000;
}

/**
 * MM-DD-YYYY + HH:MM:SS → epoch ms (wall clock as UTC).
 */
function wallTimeToEpochMs(dateStr, timeStr) {
  const dm = String(dateStr).match(/^(\d{1,2})-(\d{1,2})-(\d{4})$/);
  const tm = String(timeStr).match(/^(\d{1,2}):(\d{2}):(\d{2})$/);
  if (!dm || !tm) return null;
  const month = parseInt(dm[1], 10);
  const day = parseInt(dm[2], 10);
  const year = parseInt(dm[3], 10);
  const hh = parseInt(tm[1], 10);
  const mm = parseInt(tm[2], 10);
  const ss = parseInt(tm[3], 10);
  // UTC wall clock
  const ms = Date.UTC(year, month - 1, day, hh, mm, ss);
  return isFinite(ms) ? ms : null;
}

function toIsoLocal(dateStr, timeStr) {
  const dm = String(dateStr).match(/^(\d{1,2})-(\d{1,2})-(\d{4})$/);
  const tm = String(timeStr).match(/^(\d{1,2}):(\d{2}):(\d{2})$/);
  if (!dm || !tm) return null;
  const pad = (n) => String(n).padStart(2, '0');
  return (
    dm[3] +
    '-' +
    pad(dm[1]) +
    '-' +
    pad(dm[2]) +
    'T' +
    pad(tm[1]) +
    ':' +
    pad(tm[2]) +
    ':' +
    pad(tm[3])
  );
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    parseShellReceiptHtml,
    htmlToText,
    wallTimeToEpochMs,
  };
}
