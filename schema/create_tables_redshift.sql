-- schema/create_tables_redshift.sql
-- Redshift-style table definitions for the simulated player retention and churn SQL project.

DROP TABLE IF EXISTS ab_test_assignments;
DROP TABLE IF EXISTS bonuses;
DROP TABLE IF EXISTS campaigns;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS players;

CREATE TABLE players (
    player_id BIGINT PRIMARY KEY,
    registration_date DATE,
    country VARCHAR(10),
    acquisition_channel VARCHAR(50),
    initial_segment VARCHAR(30),
    age_band VARCHAR(20),
    account_status VARCHAR(30)
);

CREATE TABLE sessions (
    session_id BIGINT PRIMARY KEY,
    player_id BIGINT,
    activity_date DATE,
    game_type VARCHAR(50),
    session_minutes INTEGER,
    stake_amount DECIMAL(12,2),
    win_amount DECIMAL(12,2)
);

CREATE TABLE transactions (
    transaction_id BIGINT,
    player_id BIGINT,
    transaction_date DATE,
    transaction_type VARCHAR(30),
    amount DECIMAL(12,2),
    payment_method VARCHAR(50),
    notes VARCHAR(255)
);

CREATE TABLE campaigns (
    campaign_id BIGINT PRIMARY KEY,
    campaign_name VARCHAR(100),
    campaign_type VARCHAR(50),
    start_date DATE,
    end_date DATE
);

CREATE TABLE bonuses (
    bonus_id BIGINT PRIMARY KEY,
    player_id BIGINT,
    campaign_id BIGINT,
    bonus_date DATE,
    bonus_amount DECIMAL(12,2),
    bonus_status VARCHAR(30)
);

CREATE TABLE ab_test_assignments (
    player_id BIGINT,
    test_group VARCHAR(20),
    test_start_date DATE,
    deposit_converted INTEGER,
    retained_14d INTEGER,
    revenue_14d DECIMAL(12,2)
);
