-- queries/player_retention_churn_analysis.sql
-- SQL-only portfolio project: Player retention, churn risk, cohort behavior, and data quality validation.
-- Dialect: Redshift-style SQL.
-- Data: Simulated iGaming player, session, transaction, bonus, campaign, and A/B test data.

--------------------------------------------------------------------------------
-- 1. KPI BASE TABLE
-- Purpose:
-- Build one player-level table that brings together activity, revenue, deposits,
-- withdrawals, bonus costs, and last activity date.
--------------------------------------------------------------------------------

WITH session_summary AS (
    SELECT
        player_id,
        COUNT(DISTINCT session_id) AS total_sessions,
        COUNT(DISTINCT activity_date) AS active_days,
        MIN(activity_date) AS first_activity_date,
        MAX(activity_date) AS last_activity_date,
        SUM(session_minutes) AS total_session_minutes,
        SUM(stake_amount) AS total_stakes,
        SUM(win_amount) AS total_winnings,
        SUM(stake_amount - win_amount) AS ggr
    FROM sessions
    WHERE activity_date >= '2026-01-01'
      AND activity_date < '2026-04-01'
    GROUP BY player_id
),

transaction_summary AS (
    SELECT
        player_id,
        SUM(CASE WHEN transaction_type = 'deposit' THEN amount ELSE 0 END) AS deposit_volume,
        SUM(CASE WHEN transaction_type = 'withdrawal' THEN amount ELSE 0 END) AS withdrawal_volume,
        COUNT(CASE WHEN transaction_type = 'deposit' THEN 1 END) AS deposit_count,
        COUNT(CASE WHEN transaction_type = 'withdrawal' THEN 1 END) AS withdrawal_count
    FROM transactions
    WHERE transaction_date >= '2026-01-01'
      AND transaction_date < '2026-04-01'
      AND player_id IS NOT NULL
      AND amount >= 0
    GROUP BY player_id
),

bonus_summary AS (
    SELECT
        player_id,
        SUM(CASE WHEN bonus_status = 'Redeemed' THEN bonus_amount ELSE 0 END) AS redeemed_bonus_cost,
        COUNT(CASE WHEN bonus_status = 'Redeemed' THEN 1 END) AS redeemed_bonus_count
    FROM bonuses
    WHERE bonus_date >= '2026-01-01'
      AND bonus_date < '2026-04-01'
    GROUP BY player_id
)

SELECT
    p.player_id,
    p.registration_date,
    p.country,
    p.acquisition_channel,
    p.initial_segment,
    p.age_band,
    p.account_status,

    COALESCE(s.total_sessions, 0) AS total_sessions,
    COALESCE(s.active_days, 0) AS active_days,
    s.first_activity_date,
    s.last_activity_date,
    COALESCE(s.total_session_minutes, 0) AS total_session_minutes,
    COALESCE(s.total_stakes, 0) AS total_stakes,
    COALESCE(s.total_winnings, 0) AS total_winnings,
    COALESCE(s.ggr, 0) AS ggr,

    COALESCE(t.deposit_volume, 0) AS deposit_volume,
    COALESCE(t.withdrawal_volume, 0) AS withdrawal_volume,
    COALESCE(t.deposit_count, 0) AS deposit_count,
    COALESCE(t.withdrawal_count, 0) AS withdrawal_count,

    COALESCE(b.redeemed_bonus_cost, 0) AS redeemed_bonus_cost,
    COALESCE(b.redeemed_bonus_count, 0) AS redeemed_bonus_count,

    COALESCE(s.ggr, 0) - COALESCE(b.redeemed_bonus_cost, 0) AS ngr,

    DATEDIFF(day, COALESCE(s.last_activity_date, p.registration_date), '2026-04-01') AS days_since_last_activity,

    CASE
        WHEN s.last_activity_date IS NULL THEN 'No Q1 Activity'
        WHEN DATEDIFF(day, s.last_activity_date, '2026-04-01') >= 30 THEN 'Churn Risk'
        WHEN DATEDIFF(day, s.last_activity_date, '2026-04-01') BETWEEN 14 AND 29 THEN 'At Risk'
        ELSE 'Active'
    END AS retention_status,

    CASE
        WHEN COALESCE(t.deposit_volume, 0) = 0 AND COALESCE(b.redeemed_bonus_cost, 0) > 0 THEN 'High Risk'
        WHEN COALESCE(b.redeemed_bonus_cost, 0) >= COALESCE(t.deposit_volume, 0) * 0.75
             AND COALESCE(s.ggr, 0) - COALESCE(b.redeemed_bonus_cost, 0) < 0
             AND COALESCE(b.redeemed_bonus_cost, 0) >= 50
        THEN 'Potential Bonus Abuse'
        ELSE 'Normal'
    END AS bonus_abuse_flag

FROM players p
LEFT JOIN session_summary s
    ON p.player_id = s.player_id
LEFT JOIN transaction_summary t
    ON p.player_id = t.player_id
LEFT JOIN bonus_summary b
    ON p.player_id = b.player_id
ORDER BY ngr DESC;


--------------------------------------------------------------------------------
-- 2. RETENTION STATUS BY PLAYER SEGMENT
-- Purpose:
-- Show where churn risk is concentrated by segment.
--------------------------------------------------------------------------------

WITH player_kpis AS (
    SELECT
        p.player_id,
        p.initial_segment,
        MAX(s.activity_date) AS last_activity_date,
        SUM(s.stake_amount - s.win_amount) AS ggr
    FROM players p
    LEFT JOIN sessions s
        ON p.player_id = s.player_id
       AND s.activity_date >= '2026-01-01'
       AND s.activity_date < '2026-04-01'
    GROUP BY p.player_id, p.initial_segment
)

SELECT
    initial_segment,
    COUNT(*) AS total_players,
    SUM(CASE WHEN last_activity_date IS NULL THEN 1 ELSE 0 END) AS no_q1_activity_players,
    SUM(CASE WHEN DATEDIFF(day, last_activity_date, '2026-04-01') >= 30 THEN 1 ELSE 0 END) AS churn_risk_players,
    SUM(CASE WHEN DATEDIFF(day, last_activity_date, '2026-04-01') BETWEEN 14 AND 29 THEN 1 ELSE 0 END) AS at_risk_players,
    SUM(CASE WHEN DATEDIFF(day, last_activity_date, '2026-04-01') < 14 THEN 1 ELSE 0 END) AS active_players,
    ROUND(
        100.0 * SUM(CASE WHEN DATEDIFF(day, last_activity_date, '2026-04-01') >= 30 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS churn_risk_rate_pct
FROM player_kpis
GROUP BY initial_segment
ORDER BY churn_risk_rate_pct DESC;


--------------------------------------------------------------------------------
-- 3. MONTHLY COHORT RETENTION
-- Purpose:
-- Compare player registration cohorts by whether they returned in Q1.
--------------------------------------------------------------------------------

WITH cohorts AS (
    SELECT
        player_id,
        DATE_TRUNC('month', registration_date) AS registration_month
    FROM players
),

activity_by_month AS (
    SELECT
        player_id,
        DATE_TRUNC('month', activity_date) AS activity_month,
        COUNT(DISTINCT activity_date) AS active_days
    FROM sessions
    WHERE activity_date >= '2026-01-01'
      AND activity_date < '2026-04-01'
    GROUP BY player_id, DATE_TRUNC('month', activity_date)
)

SELECT
    c.registration_month,
    COUNT(DISTINCT c.player_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN a.activity_month = '2026-01-01' THEN c.player_id END) AS active_jan_players,
    COUNT(DISTINCT CASE WHEN a.activity_month = '2026-02-01' THEN c.player_id END) AS active_feb_players,
    COUNT(DISTINCT CASE WHEN a.activity_month = '2026-03-01' THEN c.player_id END) AS active_mar_players,

    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.activity_month = '2026-01-01' THEN c.player_id END) / NULLIF(COUNT(DISTINCT c.player_id), 0), 2) AS jan_retention_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.activity_month = '2026-02-01' THEN c.player_id END) / NULLIF(COUNT(DISTINCT c.player_id), 0), 2) AS feb_retention_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.activity_month = '2026-03-01' THEN c.player_id END) / NULLIF(COUNT(DISTINCT c.player_id), 0), 2) AS mar_retention_pct

FROM cohorts c
LEFT JOIN activity_by_month a
    ON c.player_id = a.player_id
GROUP BY c.registration_month
ORDER BY c.registration_month;


--------------------------------------------------------------------------------
-- 4. TOP CHURN-RISK PLAYERS BY LOST VALUE
-- Purpose:
-- Identify high-value players who have not been active recently.
--------------------------------------------------------------------------------

WITH player_value AS (
    SELECT
        p.player_id,
        p.country,
        p.initial_segment,
        MAX(s.activity_date) AS last_activity_date,
        COUNT(DISTINCT s.session_id) AS total_sessions,
        SUM(s.stake_amount - s.win_amount) AS ggr,
        COALESCE(SUM(CASE WHEN b.bonus_status = 'Redeemed' THEN b.bonus_amount ELSE 0 END), 0) AS bonus_cost
    FROM players p
    LEFT JOIN sessions s
        ON p.player_id = s.player_id
       AND s.activity_date >= '2026-01-01'
       AND s.activity_date < '2026-04-01'
    LEFT JOIN bonuses b
        ON p.player_id = b.player_id
       AND b.bonus_date >= '2026-01-01'
       AND b.bonus_date < '2026-04-01'
    GROUP BY p.player_id, p.country, p.initial_segment
)

SELECT
    player_id,
    country,
    initial_segment,
    last_activity_date,
    DATEDIFF(day, last_activity_date, '2026-04-01') AS days_since_last_activity,
    total_sessions,
    ROUND(COALESCE(ggr, 0), 2) AS ggr,
    ROUND(COALESCE(bonus_cost, 0), 2) AS bonus_cost,
    ROUND(COALESCE(ggr, 0) - COALESCE(bonus_cost, 0), 2) AS estimated_ngr
FROM player_value
WHERE last_activity_date IS NOT NULL
  AND DATEDIFF(day, last_activity_date, '2026-04-01') >= 30
ORDER BY estimated_ngr DESC
LIMIT 25;


--------------------------------------------------------------------------------
-- 5. BONUS ABUSE RISK BY CAMPAIGN
-- Purpose:
-- Find campaigns that may be driving bonus-heavy behavior with poor net revenue.
--------------------------------------------------------------------------------

WITH player_revenue AS (
    SELECT
        player_id,
        SUM(stake_amount - win_amount) AS ggr
    FROM sessions
    WHERE activity_date >= '2026-01-01'
      AND activity_date < '2026-04-01'
    GROUP BY player_id
),

player_deposits AS (
    SELECT
        player_id,
        SUM(CASE WHEN transaction_type = 'deposit' AND amount >= 0 THEN amount ELSE 0 END) AS deposits
    FROM transactions
    WHERE transaction_date >= '2026-01-01'
      AND transaction_date < '2026-04-01'
      AND player_id IS NOT NULL
    GROUP BY player_id
),

campaign_bonus AS (
    SELECT
        b.player_id,
        b.campaign_id,
        c.campaign_name,
        c.campaign_type,
        SUM(CASE WHEN b.bonus_status = 'Redeemed' THEN b.bonus_amount ELSE 0 END) AS redeemed_bonus_cost
    FROM bonuses b
    JOIN campaigns c
        ON b.campaign_id = c.campaign_id
    WHERE b.bonus_date >= '2026-01-01'
      AND b.bonus_date < '2026-04-01'
    GROUP BY b.player_id, b.campaign_id, c.campaign_name, c.campaign_type
)

SELECT
    campaign_name,
    campaign_type,
    COUNT(DISTINCT cb.player_id) AS players_with_bonus,
    ROUND(SUM(redeemed_bonus_cost), 2) AS total_bonus_cost,
    ROUND(SUM(COALESCE(pr.ggr, 0)), 2) AS total_ggr,
    ROUND(SUM(COALESCE(pr.ggr, 0) - redeemed_bonus_cost), 2) AS estimated_ngr_after_bonus,
    ROUND(100.0 * SUM(
        CASE
            WHEN redeemed_bonus_cost >= COALESCE(pd.deposits, 0) * 0.75
             AND COALESCE(pr.ggr, 0) - redeemed_bonus_cost < 0
             AND redeemed_bonus_cost >= 50
            THEN 1 ELSE 0
        END
    ) / NULLIF(COUNT(DISTINCT cb.player_id), 0), 2) AS potential_abuse_rate_pct
FROM campaign_bonus cb
LEFT JOIN player_revenue pr
    ON cb.player_id = pr.player_id
LEFT JOIN player_deposits pd
    ON cb.player_id = pd.player_id
GROUP BY campaign_name, campaign_type
ORDER BY potential_abuse_rate_pct DESC, estimated_ngr_after_bonus ASC;


--------------------------------------------------------------------------------
-- 6. A/B TEST RESULT SUMMARY
-- Purpose:
-- Summarize conversion, retention, revenue, and lift by test group.
--------------------------------------------------------------------------------

SELECT
    test_group,
    COUNT(*) AS assigned_players,
    SUM(deposit_converted) AS deposit_conversions,
    ROUND(100.0 * SUM(deposit_converted) / NULLIF(COUNT(*), 0), 2) AS deposit_conversion_rate_pct,
    SUM(retained_14d) AS retained_14d_players,
    ROUND(100.0 * SUM(retained_14d) / NULLIF(COUNT(*), 0), 2) AS retention_14d_rate_pct,
    ROUND(AVG(revenue_14d), 2) AS avg_revenue_14d,
    ROUND(SUM(revenue_14d), 2) AS total_revenue_14d
FROM ab_test_assignments
GROUP BY test_group
ORDER BY test_group;


--------------------------------------------------------------------------------
-- 7. A/B TEST LIFT CALCULATION
-- Purpose:
-- Compare Variant to Control in SQL.
--------------------------------------------------------------------------------

WITH group_summary AS (
    SELECT
        test_group,
        COUNT(*) AS users,
        SUM(deposit_converted) AS converted,
        1.0 * SUM(deposit_converted) / NULLIF(COUNT(*), 0) AS conversion_rate,
        AVG(revenue_14d) AS avg_revenue_14d
    FROM ab_test_assignments
    GROUP BY test_group
),

pivoted AS (
    SELECT
        MAX(CASE WHEN test_group = 'Control' THEN users END) AS control_users,
        MAX(CASE WHEN test_group = 'Control' THEN converted END) AS control_converted,
        MAX(CASE WHEN test_group = 'Control' THEN conversion_rate END) AS control_conversion_rate,
        MAX(CASE WHEN test_group = 'Control' THEN avg_revenue_14d END) AS control_avg_revenue,

        MAX(CASE WHEN test_group = 'Variant' THEN users END) AS variant_users,
        MAX(CASE WHEN test_group = 'Variant' THEN converted END) AS variant_converted,
        MAX(CASE WHEN test_group = 'Variant' THEN conversion_rate END) AS variant_conversion_rate,
        MAX(CASE WHEN test_group = 'Variant' THEN avg_revenue_14d END) AS variant_avg_revenue
    FROM group_summary
)

SELECT
    control_users,
    control_converted,
    ROUND(100.0 * control_conversion_rate, 2) AS control_conversion_rate_pct,

    variant_users,
    variant_converted,
    ROUND(100.0 * variant_conversion_rate, 2) AS variant_conversion_rate_pct,

    ROUND(100.0 * (variant_conversion_rate - control_conversion_rate), 2) AS absolute_lift_points,
    ROUND(100.0 * (variant_conversion_rate - control_conversion_rate) / NULLIF(control_conversion_rate, 0), 2) AS relative_lift_pct,

    ROUND(control_avg_revenue, 2) AS control_avg_revenue_14d,
    ROUND(variant_avg_revenue, 2) AS variant_avg_revenue_14d,
    ROUND(variant_avg_revenue - control_avg_revenue, 2) AS avg_revenue_lift
FROM pivoted;


--------------------------------------------------------------------------------
-- 8. DATA QUALITY CHECKS
-- Purpose:
-- Validate common issues before trusting any KPI report.
--------------------------------------------------------------------------------

-- 8A. Duplicate transaction IDs
SELECT
    transaction_id,
    COUNT(*) AS duplicate_count
FROM transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- 8B. Transactions with missing player IDs
SELECT *
FROM transactions
WHERE player_id IS NULL;

-- 8C. Transactions with negative values
SELECT *
FROM transactions
WHERE amount < 0;

-- 8D. Q1 report out-of-range transaction dates
SELECT *
FROM transactions
WHERE transaction_date < '2026-01-01'
   OR transaction_date >= '2026-04-01';

-- 8E. Sessions attached to players that do not exist
SELECT s.*
FROM sessions s
LEFT JOIN players p
    ON s.player_id = p.player_id
WHERE p.player_id IS NULL;

-- 8F. Bonus records attached to campaigns that do not exist
SELECT b.*
FROM bonuses b
LEFT JOIN campaigns c
    ON b.campaign_id = c.campaign_id
WHERE c.campaign_id IS NULL;


--------------------------------------------------------------------------------
-- 9. BUSINESS-FRIENDLY MONTHLY KPI SUMMARY
-- Purpose:
-- Final executive-style SQL output that could feed a dashboard.
--------------------------------------------------------------------------------

WITH monthly_sessions AS (
    SELECT
        DATE_TRUNC('month', activity_date) AS month,
        COUNT(DISTINCT player_id) AS active_players,
        COUNT(DISTINCT session_id) AS sessions,
        SUM(stake_amount) AS stakes,
        SUM(win_amount) AS winnings,
        SUM(stake_amount - win_amount) AS ggr
    FROM sessions
    WHERE activity_date >= '2026-01-01'
      AND activity_date < '2026-04-01'
    GROUP BY DATE_TRUNC('month', activity_date)
),

monthly_transactions AS (
    SELECT
        DATE_TRUNC('month', transaction_date) AS month,
        SUM(CASE WHEN transaction_type = 'deposit' AND amount >= 0 THEN amount ELSE 0 END) AS deposits,
        SUM(CASE WHEN transaction_type = 'withdrawal' AND amount >= 0 THEN amount ELSE 0 END) AS withdrawals
    FROM transactions
    WHERE transaction_date >= '2026-01-01'
      AND transaction_date < '2026-04-01'
      AND player_id IS NOT NULL
    GROUP BY DATE_TRUNC('month', transaction_date)
),

monthly_bonus AS (
    SELECT
        DATE_TRUNC('month', bonus_date) AS month,
        SUM(CASE WHEN bonus_status = 'Redeemed' THEN bonus_amount ELSE 0 END) AS bonus_cost
    FROM bonuses
    WHERE bonus_date >= '2026-01-01'
      AND bonus_date < '2026-04-01'
    GROUP BY DATE_TRUNC('month', bonus_date)
)

SELECT
    ms.month,
    ms.active_players,
    ms.sessions,
    ROUND(ms.stakes, 2) AS stakes,
    ROUND(ms.winnings, 2) AS winnings,
    ROUND(ms.ggr, 2) AS ggr,
    ROUND(COALESCE(mb.bonus_cost, 0), 2) AS bonus_cost,
    ROUND(ms.ggr - COALESCE(mb.bonus_cost, 0), 2) AS ngr,
    ROUND(COALESCE(mt.deposits, 0), 2) AS deposits,
    ROUND(COALESCE(mt.withdrawals, 0), 2) AS withdrawals
FROM monthly_sessions ms
LEFT JOIN monthly_transactions mt
    ON ms.month = mt.month
LEFT JOIN monthly_bonus mb
    ON ms.month = mb.month
ORDER BY ms.month;
