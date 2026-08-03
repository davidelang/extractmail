# Apps Script — Gmail → Sheets (no Android install)

Paste into [script.google.com](https://script.google.com):

| File | Role |
|------|------|
| `Code.gs` | Label poll, sheet append, dedup |
| `ShellParser.gs` | Shell e-receipt HTML |
| `SamsParser.gs` | Sam’s Club fuel receipt HTML |
| `ReceiptParsers.gs` | Autodetect dispatch (Shell + Sam’s) |

**Brands supported:** Shell (`shell-ereceipt`) and Sam’s Club (`samsclub-fuel`), same contract as host extractmail / VE offline goldens.

## Script properties

| Key | Required | Notes |
|-----|----------|--------|
| `RECEIPT_LABEL` | yes | Gmail label, e.g. `VehicleExpenses/ShellReceipts` |
| `SPREADSHEET_ID` | yes | Same spreadsheet as app tabular sync |
| `FUEL_TAB_NAME` | no | default `Fuel - Unassigned` |
| `UNASSIGNED_VEHICLE_SYNC_ID` | no | stable Unassigned vehicle sync id |
| `PROCESSED_LABEL` | no | applied after successful append |
| `DRY_RUN` | no | `"true"` = log only |

## Fuel contract

- Vehicle Unassigned / id **0**
- Odometer **0**
- Partial fill **false**, economy ignored **false**
- Cost = amount paid after discounts
- Sync ID from message id

## Trigger

Time-driven (e.g. every 15 minutes) → `processReceiptLabel`.

Keep parsers in sync with `extractors/reference-js/` when changing goldens.
