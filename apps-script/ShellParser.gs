/**
 * Shell HTML parser for Apps Script (paste alongside Code.gs).
 * Keep behavior aligned with lib/shell-receipt-parser.js (Node tests are SoT for goldens).
 */

function parseShellReceiptHtml(html, opts) {
  opts = opts || {};
  if (!html || typeof html !== 'string') return null;

  var lower = html.toLowerCase();
  var looksShell =
    lower.indexOf('ereceiptshell') >= 0 ||
    lower.indexOf('shell e-receipt') >= 0 ||
    lower.indexOf('welcome to shell') >= 0 ||
    lower.indexOf('shell oil') >= 0;
  if (!looksShell) return null;

  var text = htmlToText_(html);
  var parts = text.split(/\n+/).map(function (s) { return s.trim(); }).filter(Boolean);

  var address = extractAddress_(parts);
  var dt = extractDateTime_(parts);
  var fuel = extractFuelLine_(parts);
  var amountPaid = extractAmountPaid_(parts, text);

  if (!fuel || fuel.gallons == null || !(fuel.gallons > 0)) return null;
  if (amountPaid == null || !(amountPaid > 0)) return null;
  if (!dt.dateStr || !dt.timeStr) return null;

  var timestampMs = wallTimeToEpochMs_(dt.dateStr, dt.timeStr);
  if (timestampMs == null) return null;

  var timestampLocal = toIsoLocal_(dt.dateStr, dt.timeStr);
  var siteId = extractSiteId_(parts);
  var pump = extractPump_(parts);

  var locationText = 'Shell';
  if (address && address.length) locationText = 'Shell — ' + address.join(', ');

  var messageKey =
    opts.messageKey ||
    opts.gmailMessageId ||
    ['shell', siteId || 'nosite', timestampLocal || String(timestampMs)].join('|');

  return {
    brand: 'Shell',
    currency: 'USD',
    cost: roundMoney_(amountPaid),
    gallons: roundGallons_(fuel.gallons),
    timestampMs: timestampMs,
    timestampLocal: timestampLocal,
    locationText: locationText,
    siteId: siteId || undefined,
    pump: pump || undefined,
    product: fuel.product || undefined,
    messageKey: messageKey,
    rawProvenance: {
      dateStr: dt.dateStr,
      timeStr: dt.timeStr,
      fuelTotalPreDiscount: fuel.fuelTotal,
      pricePerGal: fuel.pricePerGal,
    },
  };
}

function htmlToText_(html) {
  var s = String(html);
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
    .replace(/&#(\d+);/g, function (_, n) {
      return String.fromCharCode(parseInt(n, 10));
    })
    .replace(/&[a-z]+;/gi, ' ');
  s = s.replace(/\r/g, '\n');
  s = s.replace(/[ \t]+/g, ' ');
  s = s.replace(/\n[ \t]+/g, '\n');
  s = s.replace(/[ \t]+\n/g, '\n');
  s = s.replace(/\n{2,}/g, '\n');
  return s.trim();
}

function extractAddress_(parts) {
  var i;
  for (i = 0; i < parts.length; i++) {
    var p = parts[i];
    if (/here is your/i.test(p) && /receipt/i.test(p)) {
      var street = parts[i + 1];
      var city = parts[i + 2];
      var stZip = parts[i + 3];
      if (street && city && stZip && looksStreet_(street) && looksStateZip_(stZip)) {
        return [street, city, stZip];
      }
    }
  }
  for (i = 2; i < parts.length; i++) {
    if (looksStateZip_(parts[i]) && looksStreet_(parts[i - 2])) {
      return [parts[i - 2], parts[i - 1], parts[i]];
    }
  }
  return null;
}

function looksStreet_(s) {
  return /\d/.test(s) && /[A-Za-z]/.test(s) && s.length >= 5 && s.length < 80;
}

function looksStateZip_(s) {
  return /^[A-Z]{2}\s+\d{5}(-\d{4})?$/.test(String(s).trim());
}

function extractDateTime_(parts) {
  var dateStr = null;
  var timeStr = null;
  for (var i = 0; i < parts.length; i++) {
    var p = parts[i];
    var dm = p.match(/^(\d{1,2}-\d{1,2}-\d{4})$/);
    if (dm) dateStr = dm[1];
    var tm = p.match(/^(\d{1,2}:\d{2}:\d{2})$/);
    if (tm) timeStr = tm[1];
  }
  return { dateStr: dateStr, timeStr: timeStr };
}

function extractFuelLine_(parts) {
  var headerIdx = -1;
  var i;
  for (i = 0; i < parts.length - 3; i++) {
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
    for (i = 0; i < parts.length - 4; i++) {
      if (/^Gallons$/i.test(parts[i]) && /^Price\/Gal$/i.test(parts[i + 1])) {
        headerIdx = i - 1;
        break;
      }
    }
  }
  if (headerIdx < 0) return null;

  var product = parts[headerIdx + 4];
  var gallonsStr = parts[headerIdx + 5];
  var priceStr = parts[headerIdx + 6];
  var fuelTotalStr = parts[headerIdx + 7];
  var gallons = parseNumber_(gallonsStr);
  if (gallons == null || !(gallons > 0)) return null;
  return {
    product: product || undefined,
    gallons: gallons,
    pricePerGal: parseMoney_(priceStr),
    fuelTotal: parseMoney_(fuelTotalStr),
  };
}

function extractAmountPaid_(parts, fullText) {
  var i;
  for (i = 0; i < parts.length; i++) {
    var m = parts[i].match(/Amount\s*Paid\s*:\s*\$?\s*([\d,]+\.\d{2})/i);
    if (m) return parseMoney_(m[1]);
  }
  var m2 = fullText.match(/Amount\s*Paid\s*:\s*\$?\s*([\d,]+\.\d{2})/i);
  if (m2) return parseMoney_(m2[1]);

  var totalIdx = -1;
  for (i = 0; i < parts.length; i++) {
    if (/^Total$/i.test(parts[i])) totalIdx = i;
  }
  if (totalIdx >= 0) {
    var monies = [];
    for (var j = totalIdx + 1; j < Math.min(parts.length, totalIdx + 8); j++) {
      if (/^Payment/i.test(parts[j])) break;
      var v = parseMoney_(parts[j]);
      if (v != null) monies.push(v);
    }
    if (monies.length >= 1) return monies[monies.length - 1];
  }
  return null;
}

function extractSiteId_(parts) {
  var i;
  for (i = 0; i < parts.length; i++) {
    if (/^\d{10,14}$/.test(parts[i])) {
      if (i + 1 < parts.length && /^\d{1,2}-\d{1,2}-\d{4}$/.test(parts[i + 1])) {
        return parts[i];
      }
    }
  }
  for (i = 0; i < parts.length; i++) {
    if (/^\d{10,14}$/.test(parts[i])) return parts[i];
  }
  return null;
}

function extractPump_(parts) {
  for (var i = 0; i < parts.length; i++) {
    var m = parts[i].match(/PUMP\s*#\s*(\d+)/i);
    if (m) return m[1];
  }
  return null;
}

function parseMoney_(s) {
  if (s == null) return null;
  var t = String(s).replace(/[$,\s]/g, '').replace(/^\((.*)\)$/, '-$1');
  var m = t.match(/^(-?\d+(?:\.\d+)?)$/);
  if (!m) return null;
  var n = parseFloat(m[1]);
  return isFinite(n) ? n : null;
}

function parseNumber_(s) {
  if (s == null) return null;
  var n = parseFloat(String(s).replace(/,/g, '').trim());
  return isFinite(n) ? n : null;
}

function roundMoney_(n) {
  return Math.round(n * 100) / 100;
}

function roundGallons_(n) {
  return Math.round(n * 1000) / 1000;
}

function wallTimeToEpochMs_(dateStr, timeStr) {
  var dm = String(dateStr).match(/^(\d{1,2})-(\d{1,2})-(\d{4})$/);
  var tm = String(timeStr).match(/^(\d{1,2}):(\d{2}):(\d{2})$/);
  if (!dm || !tm) return null;
  var year = parseInt(dm[3], 10);
  var month = parseInt(dm[1], 10);
  var day = parseInt(dm[2], 10);
  var hh = parseInt(tm[1], 10);
  var mm = parseInt(tm[2], 10);
  var ss = parseInt(tm[3], 10);
  // Apps Script Date.UTC available
  var ms = Date.UTC(year, month - 1, day, hh, mm, ss);
  return isFinite(ms) ? ms : null;
}

function toIsoLocal_(dateStr, timeStr) {
  var dm = String(dateStr).match(/^(\d{1,2})-(\d{1,2})-(\d{4})$/);
  var tm = String(timeStr).match(/^(\d{1,2}):(\d{2}):(\d{2})$/);
  if (!dm || !tm) return null;
  function pad(n) {
    n = String(n);
    return n.length === 1 ? '0' + n : n;
  }
  return dm[3] + '-' + pad(dm[1]) + '-' + pad(dm[2]) + 'T' + pad(tm[1]) + ':' + pad(tm[2]) + ':' + pad(tm[3]);
}
