/**
 * Multi-vendor autodetect facade for email fuel receipts.
 * Order: Shell exclusive markers → Sam's Club → null.
 */

'use strict';

const { parseShellReceiptHtml } = require('./shell-receipt-parser.js');
const { parseSamsClubReceiptHtml } = require('./sams-club-receipt-parser.js');

/**
 * @param {string} html
 * @param {Object} [meta]
 * @param {string} [meta.fromHeader]
 * @param {string} [meta.subject]
 * @param {string} [meta.emailDateHeader]
 * @param {string} [meta.messageKey]
 * @param {string} [meta.gmailMessageId]
 * @returns {Object|null} ParsedFuelReceipt
 */
function tryParseReceiptHtml(html, meta) {
  meta = meta || {};
  if (!html || typeof html !== 'string') return null;

  const blob = [html, meta.fromHeader || '', meta.subject || ''].join('\n').toLowerCase();

  // Exclusive: Shell first if Shell markers
  if (looksShell(blob)) {
    return parseShellReceiptHtml(html, meta);
  }
  if (looksSams(blob)) {
    return parseSamsClubReceiptHtml(html, meta);
  }
  // Fallback try each without claiming wrong brand — parsers self-reject
  const shell = parseShellReceiptHtml(html, meta);
  if (shell) return shell;
  const sams = parseSamsClubReceiptHtml(html, meta);
  if (sams) return sams;
  return null;
}

function looksShell(blob) {
  return (
    blob.indexOf('ereceiptshell') >= 0 ||
    blob.indexOf('mail.ereceiptshell.com') >= 0 ||
    blob.indexOf('shell e-receipt') >= 0 ||
    (blob.indexOf('welcome to shell') >= 0 && blob.indexOf('amount paid') >= 0)
  );
}

function looksSams(blob) {
  if (blob.indexOf('ereceiptshell') >= 0) return false;
  return (
    blob.indexOf('samsclub.com') >= 0 ||
    blob.indexOf("sam's club fuel") >= 0 ||
    blob.indexOf('fuel station receipt') >= 0 ||
    (blob.indexOf("sam's club") >= 0 && blob.indexOf('total paid') >= 0)
  );
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    tryParseReceiptHtml,
    looksShell,
    looksSams,
  };
}
