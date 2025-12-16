# Verification metadata contract (server)

The API now exposes a unified verification dataset at `GET /api/verification/metadata`.

## Response structure

```
{
  "updated_at": "2024-12-01T12:00:00Z",
  "account_types": [
    {
      "account_type": "individual" | "commercial" | "realestate",
      "pricing": { "amount": 0.0, "currency": "SAR", "duration_days": 30 },
      "benefits": ["شارة موثقة أمام اسمك", "ثقة أعلى لدى المشترين", ...],
      "required_fields": [
        { "id": 1, "name": "National ID", "type": "fileinput", "account_type": "individual", "required": 1, "min_length": null, "max_length": null, "status": 1, "values": [] }
      ],
      "updated_at": "2024-12-01T12:00:00Z"
    }
  ]
}
```

* `required_fields` is filtered by `account_type` and excludes soft-deleted entries.
* `benefits` include plan-specific details (duration/price) when available; otherwise defaults are injected by the client.
* `pricing` is sourced from the active `verification_plans` row for the same account type.

## Account type normalization

Accepted values in requests (`account_type` query param) map to slugs as follows:
* `1`, `individual`, `personal`, `customer`, `private` → `individual`
* `2`, `realestate`, `real_estate`, `property` → `realestate`
* `3`, `commercial`, `business`, `merchant`, `seller` → `commercial`

## Validation alignment

* `POST /api/send-verification-request` now validates required verification fields per account type using the canonical metadata (required fields with `is_required = 1`).
* Missing required values return a validation error listing the missing field names.

## Database updates

* `verification_fields.account_type` column tracks which account type a field belongs to (defaults to `individual`).
* `verification_plans` model is available for plan/pricing retrieval.
