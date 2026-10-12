# Google Sheets Provider: Transaction Sheet Format

The Google Sheets provider expects a **publicly shared** sheet URL and reads a single tab as transaction rows.

## Required columns

| Column | Type | Description |
|---|---|---|
| `date` | Date (`YYYY-MM-DD` preferred) | Transaction posting date |
| `amount` | Number | Signed amount (`-` for outflow, `+` for inflow) |
| `name` | String | Merchant/payee display name |

## Optional columns

| Column | Type | Description |
|---|---|---|
| `currency` | String | ISO-4217 code (defaults to `USD`) |
| `memo` | String | Notes/description |
| `category` | String | Category label for downstream mapping |
| `external_id` | String | Stable source ID for de-duplication |
| `pending` | Boolean | `true/false`, `1/0`, or `yes/no` |

## Rules

- Header names are case-insensitive.
- Empty rows are skipped.
- Rows missing any required field (`date`, `amount`, `name`) are skipped.
- The provider reads from the first sheet tab by default.
- Use a Google Sheets sharing URL like:
  - `https://docs.google.com/spreadsheets/d/<SHEET_ID>/edit?gid=<GID>`

The provider converts the sharing URL into a CSV export URL:
`https://docs.google.com/spreadsheets/d/<SHEET_ID>/export?format=csv&gid=<GID>`.
