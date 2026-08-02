/**
 * Multi-vendor tryParse for Apps Script (Shell then Sam's).
 */
function tryParseReceiptHtml(html, meta) {
  meta = meta || {};
  if (!html || typeof html !== 'string') return null;
  var blob = [html, meta.fromHeader || '', meta.subject || ''].join('\n').toLowerCase();
  if (looksShellBlob_(blob)) {
    return parseShellReceiptHtml(html, meta);
  }
  if (looksSamsBlob_(blob)) {
    return parseSamsClubReceiptHtml(html, meta);
  }
  var shell = parseShellReceiptHtml(html, meta);
  if (shell) return shell;
  return parseSamsClubReceiptHtml(html, meta);
}

function looksShellBlob_(blob) {
  return (
    blob.indexOf('ereceiptshell') >= 0 ||
    blob.indexOf('mail.ereceiptshell.com') >= 0 ||
    blob.indexOf('shell e-receipt') >= 0 ||
    (blob.indexOf('welcome to shell') >= 0 && blob.indexOf('amount paid') >= 0)
  );
}

function looksSamsBlob_(blob) {
  if (blob.indexOf('ereceiptshell') >= 0) return false;
  return (
    blob.indexOf('samsclub.com') >= 0 ||
    blob.indexOf("sam's club fuel") >= 0 ||
    blob.indexOf('fuel station receipt') >= 0 ||
    (blob.indexOf("sam's club") >= 0 && blob.indexOf('total paid') >= 0)
  );
}
