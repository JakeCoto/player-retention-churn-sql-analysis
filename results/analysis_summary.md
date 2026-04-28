# Analysis Summary

## Project Purpose

I built this SQL-only project to demonstrate my ability to work through a realistic analyst workflow using SQL. The project is based on simulated iGaming-style player data and focuses on retention, churn risk, player value, campaign risk, A/B testing, and data quality validation.

## Main Analysis Areas

### 1. Player-Level KPI Base Table

The first query creates a player-level KPI view by joining player profiles to session, transaction, and bonus summaries.

This lets me analyze each player by:

- Total sessions
- Active days
- First and last activity dates
- Stakes
- Winnings
- GGR
- Deposits
- Withdrawals
- Redeemed bonus cost
- NGR
- Retention status
- Bonus abuse flag

### 2. Retention Status by Segment

I grouped players by segment to compare Active, At Risk, Churn Risk, and No Q1 Activity players.

The business value of this query is that it helps identify where retention efforts should be focused first.

### 3. Cohort Retention

I grouped players by registration month and measured whether they were active in January, February, and March 2026.

This shows whether newer or older registration cohorts are staying engaged over time.

### 4. High-Value Churn-Risk Players

I filtered for players with no recent activity and sorted them by estimated NGR.

This is useful because not all churn risk has the same business impact. A high-value inactive player should usually be prioritized over a low-value inactive player.

### 5. Bonus Abuse Risk

I compared bonus cost, deposits, and GGR to flag suspicious patterns.

The logic looks for players or campaigns where bonus usage is high relative to deposits and net revenue is negative.

### 6. A/B Test Analysis

I summarized Control and Variant groups by:

- Assigned players
- Deposit conversions
- Conversion rate
- 14-day retention
- Average 14-day revenue
- Total 14-day revenue

I also calculated absolute and relative lift between Variant and Control.

### 7. Data Quality Validation

Before trusting the results, I included checks for:

- Duplicate transaction IDs
- Missing player IDs
- Negative transaction amounts
- Out-of-range transaction dates
- Sessions tied to missing players
- Bonus records tied to missing campaigns

## Business Takeaway

The main takeaway from this project is that SQL analysis should not stop at producing numbers. A good analyst needs to validate the data, understand how metrics are defined, and connect the output back to a business decision.

In this project, that means using SQL to help answer questions like:

- Which players are likely to churn?
- Which player segments need retention attention?
- Are campaigns creating profitable behavior or just bonus-heavy activity?
- Did a test improve conversion enough to matter?
- Can the underlying data be trusted?

## Interview Talking Point

If I were explaining this in an interview, I would say:

'I built this project to show how I would use SQL in a real junior analyst role. I started by creating a player-level KPI base table, then used it to analyze retention status, cohort behavior, churn risk, bonus abuse patterns, and A/B test results. I also included data quality checks because I wanted the project to show not just that I can calculate KPIs, but that I can validate whether those KPIs are reliable.'
