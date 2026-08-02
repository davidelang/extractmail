/**
 * Sam's Club fuel-station e-receipt HTML parser (Wave multi-vendor).
 * Pure functions: HTML → ParsedFuelReceipt | null.
 *
 * Cost = Total paid after discounts. Volume = N.NNN gal near Fuel - product.
 * Year/zone: body fill time has no year; use email Date header (required).
 * Timezone rule (v1): apply fill wall clock in the offset from email Date.
 */

'use strict';

/**
 * @param {string} html
 * @param {Object} [opts]
 * @param {string} [opts.messageKey]
 * @param {string} [opts.gmailMessageId]
 * @param {string} [opts.fromHeader]
 * @param {string} [opts.subject]
 * @param {string} [opts.emailDateHeader] RFC822 Date (year + zone)
 * @returns {Object|null}
 */
function parseSamsClubReceiptHtml(html, opts) {
  opts = opts || {};
  if (!html || typeof html !== 'string') return null;
  if (!looksSamsClubFuel(html, opts.fromHeader, opts.subject)) return null;

  const text = htmlToText(html);
  const parts = text
    .split(/\n+/)
    .map((s) => s.trim())
    .filter(Boolean);

  const address = extractAddress(parts);
  const fillStr = extractFillDateTimeString(parts);
  const fuel = extractFuel(parts);
  const amountPaid = extractTotalPaid(parts);
  const pump = extractPump(parts);
  const txnId = extractTxnId(parts);

  if (!fuel || fuel.gallons == null || !(fuel.gallons > 0)) return null;
  if (amountPaid == null || !(amountPaid > 0)) return null;
  if (!fillStr) return null;

  const emailDate = opts.emailDateHeader || opts.dateHeader || null;
  const ts = resolveTimestamp(fillStr, emailDate);
  if (!ts) return null;

  const locationBits = [];
  if (address && address.club) locationBits.push(address.club);
  if (address && address.street) locationBits.push(address.street);
  if (address && address.cityStateZip) locationBits.push(address.cityStateZip);
  let locationText = locationBits.length
    ? "Sam's Club — " + locationBits.join(', ')
    : "Sam's Club";
  if (pump) locationText += ' (Pump ' + pump + ')';

  const messageKey =
    opts.messageKey ||
    opts.gmailMessageId ||
    ['sams', txnId || 'notxn', ts.timestampLocal || String(ts.timestampMs)].join('|');

  return {
    brand: 'SamsClub',
    currency: 'USD',
    cost: roundMoney(amountPaid),
    gallons: roundGallons(fuel.gallons),
    timestampMs: ts.timestampMs,
    timestampLocal: ts.timestampLocal,
    locationText: locationText,
    siteId: txnId || undefined,
    pump: pump || undefined,
    product: fuel.product || undefined,
    messageKey: messageKey,
    rawProvenance: {
      fillStr: fillStr,
      emailDateHeader: emailDate || undefined,
      unitPrice: fuel.unitPrice,
    },
  };
}

function looksSamsClubFuel(html, fromHeader, subject) {
  const blob = [html, fromHeader || '', subject || ''].join('\n').toLowerCase();
  // Reject Shell explicitly
  if (blob.indexOf('ereceiptshell') >= 0 || blob.indexOf('mail.ereceiptshell.com') >= 0) {
    return false;
  }
  const fromSams =
    blob.indexOf('samsclub.com') >= 0 ||
    blob.indexOf("sam's club") >= 0 ||
    blob.indexOf('sams club') >= 0;
  const fuelMarkers =
    blob.indexOf('fuel station receipt') >= 0 ||
    blob.indexOf("sam's club fuel station") >= 0 ||
    blob.indexOf('sams club fuel station') >= 0 ||
    (blob.indexOf('total paid') >= 0 && blob.indexOf('fuel -') >= 0);
  return fromSams && fuelMarkers;
}

function htmlToText(html) {
  let s = String(html);
  s = s.replace(/<script[\s\S]*?<\/script>/gi, ' ');
  s = s.replace(/<style[\s\S]*?<\/style>/gi, ' ');
  s = s.replace(/<!--[\s\S]*?-->/g, ' ');
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

function extractAddress(parts) {
  // After "Transaction Details": club, street, city state zip
  let start = -1;
  for (let i = 0; i < parts.length; i++) {
    if (/transaction details/i.test(parts[i])) {
      start = i + 1;
      break;
    }
  }
  if (start < 0) {
    for (let i = 0; i < parts.length; i++) {
      if (/sam'?s club/i.test(parts[i]) && /\d/.test(parts[i + 1] || '')) {
        start = i;
        break;
      }
    }
  }
  if (start < 0) return null;
  const club = parts[start];
  const street = parts[start + 1];
  const cityStateZip = parts[start + 2];
  if (!club || !street || !cityStateZip) return null;
  if (!/\d/.test(street)) return null;
  return { club: club, street: street, cityStateZip: cityStateZip };
}

function extractFillDateTimeString(parts) {
  // Fri, Jul 31 at 8:43 pm
  const re = /^[A-Za-z]{3},\s+[A-Za-z]{3}\s+\d{1,2}\s+at\s+\d{1,2}:\d{2}\s*[ap]m$/i;
  for (const p of parts) {
    if (re.test(p.trim())) return p.trim();
  }
  // looser
  for (const p of parts) {
    if (/\bat\s+\d{1,2}:\d{2}\s*[ap]m\b/i.test(p) && /[A-Za-z]{3}/.test(p)) return p.trim();
  }
  return null;
}

function extractFuel(parts) {
  for (let i = 0; i < parts.length; i++) {
    const prod = parts[i];
    if (!/^Fuel\s*-\s*/i.test(prod)) continue;
    // next lines may include volume
    for (let j = i + 1; j < Math.min(parts.length, i + 6); j++) {
      const m = parts[j].match(/^([\d,]+\.\d+)\s*gal\b/i);
      if (m) {
        const gallons = parseFloat(m[1].replace(/,/g, ''));
        let unitPrice = null;
        for (let k = j; k < Math.min(parts.length, j + 4); k++) {
          const up = parts[k].match(/\$?\s*([\d.]+)\s*\/\s*gal/i);
          if (up) {
            unitPrice = parseFloat(up[1]);
            break;
          }
        }
        return { product: prod, gallons: gallons, unitPrice: unitPrice };
      }
    }
  }
  // fallback: any N.NNN gal with Fuel nearby
  for (let i = 0; i < parts.length; i++) {
    const m = parts[i].match(/^([\d,]+\.\d+)\s*gal\b/i);
    if (!m) continue;
    let product = null;
    for (let j = Math.max(0, i - 4); j < i; j++) {
      if (/^Fuel\s*-/i.test(parts[j])) product = parts[j];
    }
    if (product) {
      return { product: product, gallons: parseFloat(m[1].replace(/,/g, '')), unitPrice: null };
    }
  }
  return null;
}

function extractTotalPaid(parts) {
  for (let i = 0; i < parts.length; i++) {
    if (/^Total\s+paid$/i.test(parts[i].trim())) {
      for (let j = i + 1; j < Math.min(parts.length, i + 4); j++) {
        const mon = parseMoney(parts[j]);
        if (mon != null && mon > 0) return mon;
      }
    }
  }
  // "Total paid" embedded
  for (let i = 0; i < parts.length; i++) {
    const m = parts[i].match(/Total\s+paid\s*:?\s*\$?\s*([\d,]+\.\d{2})/i);
    if (m) return parseMoney(m[1]);
  }
  return null;
}

function extractPump(parts) {
  for (const p of parts) {
    const m = p.match(/Pump\s+(\d+)/i);
    if (m) return m[1];
  }
  return null;
}

function extractTxnId(parts) {
  for (const p of parts) {
    const m = p.match(/TC\s+(\d+)/i);
    if (m) return m[1];
  }
  return null;
}

function parseMoney(s) {
  if (s == null) return null;
  const t = String(s).replace(/[$,\s]/g, '');
  const m = t.match(/^(-?\d+(?:\.\d+)?)$/);
  if (!m) return null;
  const n = parseFloat(m[1]);
  return isFinite(n) ? n : null;
}

function roundMoney(n) {
  return Math.round(n * 100) / 100;
}

function roundGallons(n) {
  return Math.round(n * 1000) / 1000;
}

const MONTHS = {
  jan: 1,
  feb: 2,
  mar: 3,
  apr: 4,
  may: 5,
  jun: 6,
  jul: 7,
  aug: 8,
  sep: 9,
  oct: 10,
  nov: 11,
  dec: 12,
};

/**
 * @param {string} fillStr e.g. Fri, Jul 31 at 8:43 pm
 * @param {string|null} emailDateHeader
 */
function resolveTimestamp(fillStr, emailDateHeader) {
  const fm = fillStr.match(
    /([A-Za-z]{3}),\s*([A-Za-z]{3})\s+(\d{1,2})\s+at\s+(\d{1,2}):(\d{2})\s*([ap]m)/i
  );
  if (!fm) return null;
  const mon = MONTHS[fm[2].slice(0, 3).toLowerCase()];
  if (!mon) return null;
  let day = parseInt(fm[3], 10);
  let hour = parseInt(fm[4], 10);
  const minute = parseInt(fm[5], 10);
  const ap = fm[6].toLowerCase();
  if (ap === 'pm' && hour < 12) hour += 12;
  if (ap === 'am' && hour === 12) hour = 0;

  let year = null;
  let offsetMin = null; // minutes east of UTC
  if (emailDateHeader) {
    const parsed = parseRfc822Date(emailDateHeader);
    if (parsed) {
      year = parsed.year;
      offsetMin = parsed.offsetMin;
    }
  }
  if (year == null) return null; // do not invent year

  const pad = (n) => String(n).padStart(2, '0');
  const timestampLocal =
    year +
    '-' +
    pad(mon) +
    '-' +
    pad(day) +
    'T' +
    pad(hour) +
    ':' +
    pad(minute) +
    ':00';

  // epoch: wall clock in email Date offset (v1 rule)
  let ms;
  if (offsetMin != null) {
    // Date.UTC of wall, then subtract offset (offset east of UTC means local = UTC+offset)
    const utcLike = Date.UTC(year, mon - 1, day, hour, minute, 0);
    ms = utcLike - offsetMin * 60 * 1000;
  } else {
    ms = Date.UTC(year, mon - 1, day, hour, minute, 0);
  }
  if (!isFinite(ms)) return null;
  return { timestampMs: ms, timestampLocal: timestampLocal };
}

function parseRfc822Date(s) {
  // Fri, 31 Jul 2026 21:48:47 -0600
  const m = String(s).match(
    /\d{1,2}\s+([A-Za-z]{3})\s+(\d{4})\s+\d{1,2}:\d{2}:\d{2}\s*([+-]\d{4}|[A-Z]{2,4})/
  );
  if (!m) {
    // try Date.parse
    const t = Date.parse(s);
    if (!isNaN(t)) {
      const d = new Date(t);
      return { year: d.getUTCFullYear(), offsetMin: 0 };
    }
    return null;
  }
  const year = parseInt(m[2], 10);
  let offsetMin = 0;
  const off = m[3];
  if (/^[+-]\d{4}$/.test(off)) {
    const sign = off[0] === '-' ? -1 : 1;
    const hh = parseInt(off.slice(1, 3), 10);
    const mm = parseInt(off.slice(3, 5), 10);
    offsetMin = sign * (hh * 60 + mm);
  }
  return { year: year, offsetMin: offsetMin };
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    parseSamsClubReceiptHtml,
    looksSamsClubFuel,
    resolveTimestamp,
    htmlToText,
  };
}
