/**
 * Shared DTO + fuel sheet contract for email receipt intake (Track A / Wave 0).
 * Mirrors master TabularSchema.FUEL_HEADERS (incl. Economy Ignored).
 */

'use strict';

/** System Unassigned vehicle (VehicleRepository on master). */
const UNASSIGNED_VEHICLE_ID = 0;
const UNASSIGNED_VEHICLE_SYNC_ID = 'a0000000-0000-4000-8000-000000000001';
const UNASSIGNED_VEHICLE_NAME = 'Unassigned';
const DEFAULT_FUEL_TAB_NAME = 'Fuel - Unassigned';
const ORIGIN_DEVICE_GMAIL_APPS_SCRIPT = 'gmail-apps-script';

/**
 * Canonical fuel header order — must match master TabularSchema.FUEL_HEADERS.
 * @type {readonly string[]}
 */
const FUEL_HEADERS = Object.freeze([
  'Sync ID',
  'ID',
  'Vehicle Sync ID',
  'Vehicle ID',
  'Odometer',
  'Gallons',
  'Cost',
  'Currency',
  'Timestamp',
  'Photo URL',
  'Partial Fill',
  'Economy Ignored',
  'Latitude',
  'Longitude',
  'Location',
  'Cloud Manifest',
  'Origin Device ID',
  'Updated At',
  'Deleted',
  'Deleted At',
]);

/**
 * @typedef {Object} ParsedFuelReceipt
 * @property {number} cost
 * @property {number} gallons
 * @property {number} timestampMs
 * @property {string} [timestampLocal]
 * @property {string} locationText
 * @property {string} currency
 * @property {string} brand
 * @property {string} messageKey
 * @property {string} [siteId]
 * @property {string} [pump]
 * @property {string} [product]
 * @property {Object} [rawProvenance]
 */

/**
 * Name-based UUID (v5-like via SHA-1) for stable Sync ID from a string key.
 * Works in Node (crypto) and Apps Script (Utilities.computeDigest).
 * @param {string} name
 * @returns {string} UUID string
 */
function uuidFromName(name) {
  const ns = 'email|receipt|v1|';
  const input = ns + String(name || '');
  const hex = sha1Hex(input);
  // UUID v5 layout from first 16 bytes of SHA-1
  const bytes = [];
  for (let i = 0; i < 16; i++) {
    bytes.push(parseInt(hex.substr(i * 2, 2), 16));
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x50; // version 5
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
  const h = bytes.map((b) => b.toString(16).padStart(2, '0')).join('');
  return (
    h.substr(0, 8) +
    '-' +
    h.substr(8, 4) +
    '-' +
    h.substr(12, 4) +
    '-' +
    h.substr(16, 4) +
    '-' +
    h.substr(20, 12)
  );
}

/**
 * @param {string} str
 * @returns {string} 40-char lowercase hex
 */
function sha1Hex(str) {
  if (typeof require === 'function') {
    try {
      const crypto = require('crypto');
      return crypto.createHash('sha1').update(str, 'utf8').digest('hex');
    } catch (_) {
      /* fall through */
    }
  }
  // Apps Script
  if (typeof Utilities !== 'undefined' && Utilities.computeDigest) {
    const raw = Utilities.computeDigest(
      Utilities.DigestAlgorithm.SHA_1,
      str,
      Utilities.Charset.UTF_8
    );
    return raw
      .map((b) => {
        const v = b < 0 ? b + 256 : b;
        return v.toString(16).padStart(2, '0');
      })
      .join('');
  }
  throw new Error('sha1Hex: no crypto backend');
}

/**
 * Stable Sync ID: prefer Gmail message id; else shell site+date+time.
 * @param {ParsedFuelReceipt} parsed
 * @param {string} [gmailMessageId]
 * @returns {string}
 */
function syncIdForReceipt(parsed, gmailMessageId) {
  if (gmailMessageId && String(gmailMessageId).trim()) {
    return uuidFromName('email|gmail|' + String(gmailMessageId).trim());
  }
  const site = (parsed && parsed.siteId) || 'unknown';
  const local = (parsed && parsed.timestampLocal) || String((parsed && parsed.timestampMs) || 0);
  return uuidFromName('email|shell|' + site + '|' + local);
}

/**
 * Map ParsedFuelReceipt → ordered cells matching FUEL_HEADERS.
 * Partial Fill = false, Economy Ignored = false, vehicle 0 + fixed Unassigned sync id, odo 0.
 *
 * @param {ParsedFuelReceipt} parsed
 * @param {Object} [opts]
 * @param {string} [opts.gmailMessageId]
 * @param {string} [opts.originDeviceId]
 * @param {number} [opts.updatedAtMs]
 * @param {boolean} [opts.includeProvenanceManifest]
 * @returns {string[]}
 */
function encodeFuelRow(parsed, opts) {
  opts = opts || {};
  if (!parsed || parsed.cost == null || parsed.gallons == null || !parsed.timestampMs) {
    throw new Error('encodeFuelRow: missing required fuel cost/gallons/timestampMs');
  }
  const syncId = syncIdForReceipt(parsed, opts.gmailMessageId);
  const updatedAt = opts.updatedAtMs != null ? opts.updatedAtMs : Date.now();
  const origin = opts.originDeviceId || ORIGIN_DEVICE_GMAIL_APPS_SCRIPT;
  let manifest = '';
  if (opts.includeProvenanceManifest !== false) {
    const body = {
      src: 'email',
      provider: (parsed.brand || 'shell').toLowerCase(),
      msgId: opts.gmailMessageId || parsed.messageKey || '',
    };
    if (parsed.siteId) body.siteId = parsed.siteId;
    if (parsed.product) body.product = parsed.product;
    try {
      manifest = JSON.stringify(body);
    } catch (_) {
      manifest = '';
    }
  }
  const boolStr = (v) => (v ? 'true' : 'false');
  return [
    syncId, // Sync ID
    '0', // ID
    UNASSIGNED_VEHICLE_SYNC_ID, // Vehicle Sync ID
    String(UNASSIGNED_VEHICLE_ID), // Vehicle ID
    '0', // Odometer
    formatNumber(parsed.gallons), // Gallons
    formatNumber(parsed.cost), // Cost
    parsed.currency || 'USD', // Currency
    String(parsed.timestampMs), // Timestamp
    '', // Photo URL
    boolStr(false), // Partial Fill — never true for email intake
    boolStr(false), // Economy Ignored
    '', // Latitude
    '', // Longitude
    parsed.locationText || '', // Location
    manifest, // Cloud Manifest
    origin, // Origin Device ID
    String(updatedAt), // Updated At
    boolStr(false), // Deleted
    '', // Deleted At
  ];
}

function formatNumber(n) {
  if (typeof n !== 'number' || !isFinite(n)) return String(n);
  // Preserve reasonable precision; strip trailing zeros via parse
  const s = n.toFixed(6).replace(/\.?0+$/, '');
  return s;
}

/**
 * Idempotent: return true if syncId already present in existing column values.
 * @param {string} syncId
 * @param {string[]|Set<string>} existingSyncIds
 */
function isDuplicateSyncId(syncId, existingSyncIds) {
  if (!syncId) return false;
  if (existingSyncIds instanceof Set) return existingSyncIds.has(syncId);
  if (Array.isArray(existingSyncIds)) return existingSyncIds.indexOf(syncId) >= 0;
  return false;
}

/**
 * @param {string[]} row
 * @param {string[]|Set<string>} existingSyncIds
 * @returns {{ append: boolean, reason: string, syncId: string }}
 */
function shouldAppendRow(row, existingSyncIds) {
  const syncId = (row && row[0]) || '';
  if (!syncId) return { append: false, reason: 'missing_sync_id', syncId: '' };
  if (isDuplicateSyncId(syncId, existingSyncIds)) {
    return { append: false, reason: 'duplicate_sync_id', syncId: syncId };
  }
  return { append: true, reason: 'new', syncId: syncId };
}

// Export for Node
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    FUEL_HEADERS,
    UNASSIGNED_VEHICLE_ID,
    UNASSIGNED_VEHICLE_SYNC_ID,
    UNASSIGNED_VEHICLE_NAME,
    DEFAULT_FUEL_TAB_NAME,
    ORIGIN_DEVICE_GMAIL_APPS_SCRIPT,
    uuidFromName,
    syncIdForReceipt,
    encodeFuelRow,
    isDuplicateSyncId,
    shouldAppendRow,
  };
}
