# Data Dictionary

This project uses simulated iGaming-style data for a SQL-only player retention and churn analysis project.

## players.csv

| Field | Description |
|---|---|
| player_id | Unique player identifier |
| registration_date | Date the player registered |
| country | Player country/market |
| acquisition_channel | How the player was acquired |
| initial_segment | Starting player segment |
| age_band | Player age band |
| account_status | Current account status |

## sessions.csv

| Field | Description |
|---|---|
| session_id | Unique gameplay/session identifier |
| player_id | Player linked to the session |
| activity_date | Date of activity |
| game_type | Game category |
| session_minutes | Session length |
| stake_amount | Amount wagered |
| win_amount | Amount won by the player |

## transactions.csv

| Field | Description |
|---|---|
| transaction_id | Transaction identifier |
| player_id | Player linked to the transaction |
| transaction_date | Date of transaction |
| transaction_type | Deposit or withdrawal |
| amount | Transaction amount |
| payment_method | Payment method used |
| notes | Notes used to document intentionally inserted data-quality issues |

## bonuses.csv

| Field | Description |
|---|---|
| bonus_id | Bonus record identifier |
| player_id | Player receiving the bonus |
| campaign_id | Campaign linked to the bonus |
| bonus_date | Date the bonus was issued |
| bonus_amount | Bonus value |
| bonus_status | Redeemed, expired, or cancelled |

## campaigns.csv

| Field | Description |
|---|---|
| campaign_id | Campaign identifier |
| campaign_name | Campaign name |
| campaign_type | Campaign category |
| start_date | Campaign start date |
| end_date | Campaign end date |

## ab_test_assignments.csv

| Field | Description |
|---|---|
| player_id | Player assigned to test |
| test_group | Control or Variant |
| test_start_date | Test start date |
| deposit_converted | Whether the player made a deposit after assignment |
| retained_14d | Whether the player was retained after 14 days |
| revenue_14d | Revenue generated within 14 days |

## KPI Definitions

| KPI | Definition |
|---|---|
| GGR | stake_amount - win_amount |
| NGR | GGR - redeemed bonus cost |
| Deposit Volume | Sum of deposit transactions |
| Withdrawal Volume | Sum of withdrawal transactions |
| Churn Risk | Player with no activity for 30+ days as of 2026-04-01 |
| At Risk | Player with no activity for 14-29 days as of 2026-04-01 |
| Player LTV Proxy | Q1 NGR per player in the observation window |
| Bonus Abuse Flag | High bonus usage relative to deposits with negative NGR |
| Conversion Rate | Converted players divided by assigned players |
