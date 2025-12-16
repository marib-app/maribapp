# Verification metadata contract (client)

The app now consumes the unified verification metadata API (`verification/metadata`) to render the subscription sheet and verification flow.

## Payload shape

```
{
  "updated_at": "2024-12-01T12:00:00Z",
  "account_types": [
    {
      "account_type": "individual" | "commercial" | "realestate",
      "pricing": { "amount": 0.0, "currency": "SAR", "duration_days": 30 },
      "benefits": ["شارة موثقة أمام اسمك", "ثقة أعلى لدى المشترين", ...],
      "required_fields": [
        { "id": 1, "name": "National ID", "type": "fileinput", "required": 1, "min_length": null, "max_length": null, "status": 1, "values": [] }
      ],
      "updated_at": "2024-12-01T12:00:00Z"
    }
  ]
}
```

* `pricing.amount`/`currency`/`duration_days` drive the plan tile and benefit labels.
* `benefits` is rendered as-is; if empty, the UI falls back to the default localized labels.
* `required_fields` is the canonical list used to build dynamic verification fields per account type.

## Account type resolution

The client normalizes account types into one of `individual`, `commercial`, or `realestate` using the selected account type value or the cached Hive user details.

## Caching

* The metadata response is cached in `SharedPreferences` under `verification_metadata_cache_v1` with a companion timestamp key.
* Cache TTL is 5 minutes. If the cache is missing or stale, the app refetches from the API; stale cache is only used as a fallback on fetch failures.

## UI consumption

* `verification_subscription_sheet.dart` uses the metadata to populate pricing, benefits, and required fields for the active account type before launching the full verification flow.
* The verification screen (`seller_verification.dart`) refreshes metadata when the user proceeds to the dynamic fields step to ensure required field validation stays in sync with the backend.
