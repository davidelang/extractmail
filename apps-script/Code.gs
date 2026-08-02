/**
 * VehicleExpenses — Gmail → Sheets fuel intake (Track A / Wave 0)
 *
 * Script properties (File → Project settings → Script properties):
 *   RECEIPT_LABEL          (required) Gmail label name to process, e.g. VehicleExpenses/ShellReceipts
 *   SPREADSHEET_ID         (required) Google Sheet id (same as app sync spreadsheet)
 *   FUEL_TAB_NAME          (optional) default "Fuel - Unassigned"
 *   UNASSIGNED_VEHICLE_SYNC_ID (optional) default a0000000-0000-4000-8000-000000000001
 *   PROCESSED_LABEL        (optional) if set, apply this label after successful append
 *   DRY_RUN                (optional) "true" → log only, no sheet writes / label changes
 *
 * Install: paste this file + ShellParser.gs into a new Apps Script project bound or standalone.
 * Trigger: time-driven (e.g. every 15 minutes) → processReceiptLabel
 *
 * Scope note: GmailApp requires broad Gmail scopes; label filtering is application-level only.
 *
 * Parser + encoder are inlined below for single-project paste (keep in sync with lib/*.js).
 */

// ---- Constants (keep aligned with lib/parsed-fuel-receipt.js) ----
var UNASSIGNED_VEHICLE_ID = 0;
var UNASSIGNED_VEHICLE_SYNC_ID_DEFAULT = 'a0000000-0000-4000-8000-000000000001';
var DEFAULT_FUEL_TAB_NAME = 'Fuel - Unassigned';
var ORIGIN_DEVICE_GMAIL_APPS_SCRIPT = 'gmail-apps-script';
// Mixed vendors under one label; autodetect at parse time (no Shell-only From filter).

var FUEL_HEADERS = [
  'Sync ID', 'ID', 'Vehicle Sync ID', 'Vehicle ID', 'Odometer', 'Gallons', 'Cost', 'Currency', 'Timestamp',
  'Photo URL', 'Partial Fill', 'Economy Ignored', 'Latitude', 'Longitude', 'Location', 'Cloud Manifest',
  'Origin Device ID', 'Updated At', 'Deleted', 'Deleted At',
];

/**
 * Entry point for time-driven trigger.
 */
function processReceiptLabel() {
  var props = PropertiesService.getScriptProperties();
  var labelName = props.getProperty('RECEIPT_LABEL');
  var spreadsheetId = props.getProperty('SPREADSHEET_ID');
  var fuelTab = props.getProperty('FUEL_TAB_NAME') || DEFAULT_FUEL_TAB_NAME;
  var unassignedSync =
    props.getProperty('UNASSIGNED_VEHICLE_SYNC_ID') || UNASSIGNED_VEHICLE_SYNC_ID_DEFAULT;
  var processedLabel = props.getProperty('PROCESSED_LABEL') || '';
  var dryRun = String(props.getProperty('DRY_RUN') || '').toLowerCase() === 'true';

  if (!labelName || !spreadsheetId) {
    throw new Error('Set Script properties RECEIPT_LABEL and SPREADSHEET_ID');
  }

  var query = 'label:' + quoteLabel(labelName);
  var threads = GmailApp.search(query, 0, 50);
  Logger.log('processReceiptLabel: query=%s threads=%s dryRun=%s', query, threads.length, dryRun);

  var existing = dryRun ? [] : loadExistingSyncIds_(spreadsheetId, fuelTab);
  var existingSet = {};
  for (var i = 0; i < existing.length; i++) existingSet[existing[i]] = true;

  var stats = { scanned: 0, parsed: 0, appended: 0, skippedDup: 0, skippedParse: 0, skippedSender: 0 };

  for (var t = 0; t < threads.length; t++) {
    var messages = threads[t].getMessages();
    for (var m = 0; m < messages.length; m++) {
      stats.scanned++;
      var msg = messages[m];
      var from = msg.getFrom() || '';
      var body = msg.getBody() || '';
      var messageId = msg.getId();
      var dateHdr = '';
      try {
        if (msg.getDate()) {
          dateHdr = Utilities.formatDate(msg.getDate(), Session.getScriptTimeZone(), 'EEE, dd MMM yyyy HH:mm:ss Z');
        }
      } catch (e1) {}
      var parsed = tryParseReceiptHtml(body, {
        gmailMessageId: messageId,
        messageKey: messageId,
        fromHeader: from,
        subject: msg.getSubject() || '',
        emailDateHeader: dateHdr,
      });
      if (!parsed) {
        stats.skippedParse++;
        Logger.log('skip parse: id=%s subject=%s', messageId, msg.getSubject());
        continue;
      }
      stats.parsed++;
      var row = encodeFuelRowApps_(parsed, {
        gmailMessageId: messageId,
        unassignedSyncId: unassignedSync,
        originDeviceId: ORIGIN_DEVICE_GMAIL_APPS_SCRIPT,
        updatedAtMs: Date.now(),
      });
      var syncId = row[0];
      if (existingSet[syncId]) {
        stats.skippedDup++;
        Logger.log('skip dup syncId=%s', syncId);
        continue;
      }
      if (dryRun) {
        Logger.log('DRY_RUN would append: %s', JSON.stringify(row));
        stats.appended++;
        existingSet[syncId] = true;
        continue;
      }
      appendFuelRow_(spreadsheetId, fuelTab, row);
      existingSet[syncId] = true;
      stats.appended++;
      if (processedLabel) {
        try {
          labelMessage_(msg, processedLabel);
        } catch (e) {
          Logger.log('processed label failed: %s', e);
        }
      }
    }
  }
  Logger.log('done %s', JSON.stringify(stats));
  return stats;
}

/** Manual dry-run from script editor. */
function dryRunProcessReceiptLabel() {
  PropertiesService.getScriptProperties().setProperty('DRY_RUN', 'true');
  try {
    return processReceiptLabel();
  } finally {
    PropertiesService.getScriptProperties().deleteProperty('DRY_RUN');
  }
}

function quoteLabel(name) {
  // Gmail search: labels with spaces use dashes or quotes
  if (/\s/.test(name)) return '"' + name + '"';
  return name;
}

function loadExistingSyncIds_(spreadsheetId, tabName) {
  var ss = SpreadsheetApp.openById(spreadsheetId);
  var sheet = ss.getSheetByName(tabName);
  if (!sheet) {
    sheet = ss.insertSheet(tabName);
    sheet.getRange(1, 1, 1, FUEL_HEADERS.length).setValues([FUEL_HEADERS]);
    return [];
  }
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) {
    // Ensure header
    var header = sheet.getRange(1, 1, 1, FUEL_HEADERS.length).getValues()[0];
    if (!header[0]) {
      sheet.getRange(1, 1, 1, FUEL_HEADERS.length).setValues([FUEL_HEADERS]);
    }
    return [];
  }
  var vals = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
  var ids = [];
  for (var i = 0; i < vals.length; i++) {
    if (vals[i][0]) ids.push(String(vals[i][0]));
  }
  return ids;
}

function appendFuelRow_(spreadsheetId, tabName, row) {
  var ss = SpreadsheetApp.openById(spreadsheetId);
  var sheet = ss.getSheetByName(tabName);
  if (!sheet) {
    sheet = ss.insertSheet(tabName);
    sheet.getRange(1, 1, 1, FUEL_HEADERS.length).setValues([FUEL_HEADERS]);
  } else if (sheet.getLastRow() === 0) {
    sheet.getRange(1, 1, 1, FUEL_HEADERS.length).setValues([FUEL_HEADERS]);
  }
  sheet.appendRow(row);
}

function labelMessage_(msg, labelName) {
  var label = GmailApp.getUserLabelByName(labelName);
  if (!label) label = GmailApp.createLabel(labelName);
  msg.getThread().addLabel(label);
}

function encodeFuelRowApps_(parsed, opts) {
  opts = opts || {};
  var syncId = syncIdForReceiptApps_(parsed, opts.gmailMessageId);
  var updatedAt = opts.updatedAtMs != null ? opts.updatedAtMs : Date.now();
  var origin = opts.originDeviceId || ORIGIN_DEVICE_GMAIL_APPS_SCRIPT;
  var unassignedSync = opts.unassignedSyncId || UNASSIGNED_VEHICLE_SYNC_ID_DEFAULT;
  var manifest = JSON.stringify({
    src: 'email',
    provider: (parsed.brand || 'shell').toLowerCase(),
    msgId: opts.gmailMessageId || parsed.messageKey || '',
    siteId: parsed.siteId || undefined,
    product: parsed.product || undefined,
  });
  return [
    syncId,
    '0',
    unassignedSync,
    String(UNASSIGNED_VEHICLE_ID),
    '0',
    formatNumberApps_(parsed.gallons),
    formatNumberApps_(parsed.cost),
    parsed.currency || 'USD',
    String(parsed.timestampMs),
    '',
    'false',
    'false',
    '',
    '',
    parsed.locationText || '',
    manifest,
    origin,
    String(updatedAt),
    'false',
    '',
  ];
}

function formatNumberApps_(n) {
  if (typeof n !== 'number' || !isFinite(n)) return String(n);
  return String(n);
}

function syncIdForReceiptApps_(parsed, gmailMessageId) {
  if (gmailMessageId) return uuidFromNameApps_('email|gmail|' + gmailMessageId);
  var site = (parsed && parsed.siteId) || 'unknown';
  var local = (parsed && parsed.timestampLocal) || String((parsed && parsed.timestampMs) || 0);
  return uuidFromNameApps_('email|shell|' + site + '|' + local);
}

function uuidFromNameApps_(name) {
  var ns = 'email|receipt|v1|';
  var raw = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_1,
    ns + String(name || ''),
    Utilities.Charset.UTF_8
  );
  var bytes = [];
  for (var i = 0; i < 16; i++) {
    var b = raw[i];
    if (b < 0) b += 256;
    bytes.push(b);
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  function hex2(n) {
    var h = n.toString(16);
    return h.length === 1 ? '0' + h : h;
  }
  var h = bytes.map(hex2).join('');
  return (
    h.substring(0, 8) +
    '-' +
    h.substring(8, 12) +
    '-' +
    h.substring(12, 16) +
    '-' +
    h.substring(16, 20) +
    '-' +
    h.substring(20, 32)
  );
}
