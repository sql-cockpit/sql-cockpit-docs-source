# Localization Preferences

SQL Cockpit can format display values using environment defaults, automatically detected browser settings, and your saved profile overrides.

## What Can Be Customized

- language
- region
- timezone
- date format
- number format
- currency
- measurement units

The effective setting is calculated from `.env` defaults, then request detection, then your saved profile override. Your profile wins when a value is set.

## Storage

Profile overrides are stored in the local SQL Cockpit SQLite database in the `user_preferences` table under the `localization` key. Timestamps are still stored internally in UTC; the localization service only converts them for display.

## Safe Use

Choose a timezone and currency that match how you expect to interpret operational data. Incorrect display settings do not change stored data, but they can make timestamps or amounts look different from another operator's view.

API users can inspect the current effective settings with `GET /api/localization` and save profile overrides with `PUT /api/localization/profile`.

The same profile fields are available from the Account page in the SQL Cockpit dashboard.
