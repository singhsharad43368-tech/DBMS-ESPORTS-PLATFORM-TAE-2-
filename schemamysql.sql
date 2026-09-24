-- ============================================================
-- E-Sports Tournament & Competitive Gaming Platform
-- TAE-2 : Database Schema (MySQL)
-- Student : Dhananjay Singh [P13]
-- Target  : MySQL 8.0+ (Workbench)
-- ============================================================
DROP DATABASE IF EXISTS esports_platform;
CREATE DATABASE esports_platform;
USE esports_platform;

-- ============================================================
-- 1. PLAYER
-- ============================================================
CREATE TABLE PLAYER (
    Player_ID           VARCHAR(10)     PRIMARY KEY,
    First_Name          VARCHAR(50)     NOT NULL,
    Last_Name           VARCHAR(50)     NOT NULL,
    Gamer_Handle_IGN    VARCHAR(30)     NOT NULL UNIQUE,
    Gender              VARCHAR(10),
    DOB                 DATE,
    Email               VARCHAR(100)    NOT NULL UNIQUE,
    Phone               VARCHAR(15),
    Country             VARCHAR(50)     NOT NULL,
    MMR_Rating          INT             NOT NULL CHECK (MMR_Rating >= 0),
    
    CONSTRAINT chk_gender CHECK (Gender IN ('Male', 'Female', 'Other') OR Gender IS NULL)
) ENGINE=InnoDB;

-- ============================================================
-- 2. VIP_PASS  (1:1 with PLAYER)
-- ============================================================
CREATE TABLE VIP_PASS (
    Pass_ID             VARCHAR(10)     PRIMARY KEY,
    Player_ID           VARCHAR(10)     NOT NULL UNIQUE,
    Pass_Tier           VARCHAR(20)     NOT NULL,
    Start_Date          DATE            NOT NULL,
    Expiry_Date         DATE            NOT NULL,
    Pass_Status         VARCHAR(20)     NOT NULL DEFAULT 'Active',
    Reward_Points       INT             NOT NULL DEFAULT 0 CHECK (Reward_Points >= 0),

    CONSTRAINT fk_vip_player 
        FOREIGN KEY (Player_ID) REFERENCES PLAYER(Player_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT chk_pass_tier 
        CHECK (Pass_Tier IN ('Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond')),

    CONSTRAINT chk_pass_status 
        CHECK (Pass_Status IN ('Active', 'Expired', 'Cancelled'))
) ENGINE=InnoDB;

-- ============================================================
-- 3. GAME_TITLE
-- ============================================================
CREATE TABLE GAME_TITLE (
    Game_ID             VARCHAR(10)     PRIMARY KEY,
    Game_Title          VARCHAR(100)    NOT NULL UNIQUE,
    Publisher           VARCHAR(100)    NOT NULL,
    Genre               VARCHAR(30)     NOT NULL,
    Max_Team_Size       INT             NOT NULL CHECK (Max_Team_Size > 0),
    Ruleset_Ver         VARCHAR(15)     NOT NULL
) ENGINE=InnoDB;

-- ============================================================
-- 4. COMPETITIVE_LEAGUE
-- ============================================================
CREATE TABLE COMPETITIVE_LEAGUE (
    League_ID           VARCHAR(10)     PRIMARY KEY,
    Game_ID             VARCHAR(10)     NOT NULL,
    League_Name         VARCHAR(150)    NOT NULL,
    Season_Year         INT             NOT NULL CHECK (Season_Year >= 2020),
    Total_Prize_Pool    DECIMAL(12,2)   NOT NULL CHECK (Total_Prize_Pool >= 0),
    Sponsor_Name        VARCHAR(100),

    CONSTRAINT fk_league_game 
        FOREIGN KEY (Game_ID) REFERENCES GAME_TITLE(Game_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 5. TEAM_ROSTER
-- ============================================================
CREATE TABLE TEAM_ROSTER (
    Team_ID             VARCHAR(10)     PRIMARY KEY,
    Team_Name           VARCHAR(100)    NOT NULL UNIQUE,
    Team_Tag            VARCHAR(10)     NOT NULL UNIQUE,
    Captain_Player_ID   VARCHAR(10)     NOT NULL,
    Region              VARCHAR(30)     NOT NULL,
    Created_Date        DATE            NOT NULL,

    CONSTRAINT fk_team_captain 
        FOREIGN KEY (Captain_Player_ID) REFERENCES PLAYER(Player_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 6. MATCH_SCHEDULE
-- ============================================================
-- ============================================================
-- 6. MATCH_SCHEDULE (Fixed without Error 3813)
-- ============================================================
CREATE TABLE MATCH_SCHEDULE (
    Match_ID            VARCHAR(10)     PRIMARY KEY,
    League_ID           VARCHAR(10)     NOT NULL,
    Team_A_ID           VARCHAR(10)     NOT NULL,
    Team_B_ID           VARCHAR(10)     NOT NULL,
    Server_Region       VARCHAR(30)     NOT NULL,
    Scheduled_Time      DATETIME        NOT NULL,
    Match_Status        VARCHAR(20)     NOT NULL DEFAULT 'Scheduled',

    CONSTRAINT fk_match_league 
        FOREIGN KEY (League_ID) REFERENCES COMPETITIVE_LEAGUE(League_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_match_team_a 
        FOREIGN KEY (Team_A_ID) REFERENCES TEAM_ROSTER(Team_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_match_team_b 
        FOREIGN KEY (Team_B_ID) REFERENCES TEAM_ROSTER(Team_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT chk_match_status 
        CHECK (Match_Status IN ('Scheduled', 'Live', 'Completed', 'Cancelled', 'Postponed'))
) ENGINE=InnoDB;

-- Trigger to guarantee Team_A_ID and Team_B_ID are never equal
DELIMITER //
CREATE TRIGGER trg_chk_different_teams_insert
BEFORE INSERT ON MATCH_SCHEDULE
FOR EACH ROW
BEGIN
    IF NEW.Team_A_ID = NEW.Team_B_ID THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Team_A_ID and Team_B_ID cannot be the same team.';
    END IF;
END //


DELIMITER ;

-- ============================================================
-- 7. TOURNAMENT_ENTRY
-- ============================================================
CREATE TABLE TOURNAMENT_ENTRY (
    Entry_ID            VARCHAR(10)     PRIMARY KEY,
    Player_ID           VARCHAR(10)     NOT NULL,
    Team_ID             VARCHAR(10)     NOT NULL,
    Match_ID            VARCHAR(10)     NOT NULL,
    Entry_Date          DATE            NOT NULL,
    Seed_Rank           INT             NOT NULL CHECK (Seed_Rank > 0),
    Entry_Status        VARCHAR(20)     NOT NULL DEFAULT 'Confirmed',

    CONSTRAINT fk_entry_player 
        FOREIGN KEY (Player_ID) REFERENCES PLAYER(Player_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_entry_team 
        FOREIGN KEY (Team_ID) REFERENCES TEAM_ROSTER(Team_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_entry_match 
        FOREIGN KEY (Match_ID) REFERENCES MATCH_SCHEDULE(Match_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT chk_entry_status 
        CHECK (Entry_Status IN ('Confirmed', 'Waitlist', 'Withdrawn', 'Disqualified')),

    -- Composite uniqueness to prevent duplicate entries
    UNIQUE KEY uk_player_match (Player_ID, Match_ID)
) ENGINE=InnoDB;

-- ============================================================
-- 8. PRIZE_PAYOUT  (1:1 with TOURNAMENT_ENTRY)
-- ============================================================
CREATE TABLE PRIZE_PAYOUT (
    Payout_ID           VARCHAR(10)     PRIMARY KEY,
    Entry_ID            VARCHAR(10)     NOT NULL UNIQUE,
    Placement_Rank      INT             NOT NULL CHECK (Placement_Rank > 0),
    Prize_Amount        DECIMAL(10,2)   NOT NULL CHECK (Prize_Amount >= 0),
    Tax_Deducted        DECIMAL(10,2)   NOT NULL DEFAULT 0 CHECK (Tax_Deducted >= 0),

    CONSTRAINT fk_payout_entry 
        FOREIGN KEY (Entry_ID) REFERENCES TOURNAMENT_ENTRY(Entry_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 9. PAYOUT_TRANSACTION  (1:1 with PRIZE_PAYOUT)
-- ============================================================

CREATE TABLE PAYOUT_TRANSACTION (
    Txn_ID              VARCHAR(10)     PRIMARY KEY,
    Payout_ID           VARCHAR(10)     NOT NULL UNIQUE,
    Payment_Date        DATE            NOT NULL,
    Amount_Paid         DECIMAL(10,2)   NOT NULL CHECK (Amount_Paid >= 0),
    Payment_Method      VARCHAR(30)     NOT NULL,
    Txn_Ref_Hash        VARCHAR(64)     NOT NULL UNIQUE,
    Txn_Status          VARCHAR(20)     NOT NULL DEFAULT 'Pending',

    CONSTRAINT fk_txn_payout 
        FOREIGN KEY (Payout_ID) REFERENCES PRIZE_PAYOUT(Payout_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT chk_payment_method 
        CHECK (Payment_Method IN ('UPI', 'Bank', 'Wallet', 'Crypto', 'PayPal')),

    CONSTRAINT chk_txn_status 
        CHECK (Txn_Status IN ('Pending', 'SUCCESS', 'Paid', 'Failed', 'Cancelled'))
) ENGINE=InnoDB;

-- ============================================================
-- 10. MATCH_PERFORMANCE
-- ============================================================
-- Drop if a broken instance exists
-- DROP TABLE IF EXISTS MATCH_PERFORMANCE;
USE esports_platform;

-- Drop existing table
-- DROP TABLE IF EXISTS MATCH_PERFORMANCE;

-- Create table matching the exact CSV structure shown in your screenshot
CREATE TABLE MATCH_PERFORMANCE (
    Perf_ID         VARCHAR(10)     PRIMARY KEY,
    Match_ID        VARCHAR(10)     NOT NULL,
    Player_ID       VARCHAR(10)     NOT NULL,
    KDA_Ratio       DECIMAL(5,2)    NOT NULL CHECK (KDA_Ratio >= 0),
    Combat_Score    DECIMAL(10,2)   NULL,             -- NOT NULL CHECK (Combat_Score >= 0),
    Headshot_Pct    DECIMAL(5,2)    NOT NULL CHECK (Headshot_Pct BETWEEN 0 AND 100),
    Outcome         VARCHAR(10)     NULL,

    CONSTRAINT fk_perf_match 
        FOREIGN KEY (Match_ID) REFERENCES match_schedule(Match_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_perf_player 
        FOREIGN KEY (Player_ID) REFERENCES player(Player_ID)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
-- SELECT * FROM MATCH_PERFORMANCE;
USE esports_platform;
-- Verify import
SELECT COUNT(*) FROM match_performance;








-- ============================================================
-- 11. ANTICHEAT_VIOLATION
-- ============================================================
-- SELECT * FROM ANTICHEAT_VIOLATION;
CREATE TABLE ANTICHEAT_VIOLATION (
    Violation_ID        VARCHAR(10)     PRIMARY KEY,
    Perf_ID             VARCHAR(10)     NOT NULL,
    Cheat_Type          VARCHAR(50)     NOT NULL,
    Flag_Confidence_Pct DECIMAL(5,2)    NOT NULL CHECK (Flag_Confidence_Pct BETWEEN 0 AND 100),
    Action_Taken        VARCHAR(30),
    Logged_Time         DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_violation_perf 
        FOREIGN KEY (Perf_ID) REFERENCES MATCH_PERFORMANCE(Perf_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT chk_cheat_type 
        CHECK (Cheat_Type IN ('Aimbot', 'Wallhack', 'TriggerBot', 'SpeedHack', 'Other')),

    CONSTRAINT chk_action_taken 
        CHECK (Action_Taken IN ('Warning', 'Temp Ban', 'Permanent Ban', 'Under Review', 'None') 
               OR Action_Taken IS NULL)
) ENGINE=InnoDB;

-- ============================================================
-- INDEXES (Basic useful indexes - more will be added in Performance phase)
-- ============================================================
CREATE INDEX idx_player_mmr         ON PLAYER(MMR_Rating);
CREATE INDEX idx_player_country     ON PLAYER(Country);
CREATE INDEX idx_match_status       ON MATCH_SCHEDULE(Match_Status);
CREATE INDEX idx_match_time         ON MATCH_SCHEDULE(Scheduled_Time);
CREATE INDEX idx_entry_player       ON TOURNAMENT_ENTRY(Player_ID);
CREATE INDEX idx_perf_player        ON MATCH_PERFORMANCE(Player_ID);
CREATE INDEX idx_violation_type     ON ANTICHEAT_VIOLATION(Cheat_Type);

-- ============================================================
-- END OF SCHEMA
-- ============================================================
select * from PLAYER;
SHOW TABLES;

SELECT 'game_title' AS Table_Name, COUNT(*) AS Total_Rows FROM game_title
UNION ALL SELECT 'vip_pass', COUNT(*) FROM vip_pass
UNION ALL SELECT 'team_roster', COUNT(*) FROM team_roster
UNION ALL SELECT 'player', COUNT(*) FROM player
UNION ALL SELECT 'competitive_league', COUNT(*) FROM competitive_league
UNION ALL SELECT 'match_schedule', COUNT(*) FROM match_schedule
UNION ALL SELECT 'tournament_entry', COUNT(*) FROM tournament_entry
UNION ALL SELECT 'prize_payout', COUNT(*) FROM prize_payout
UNION ALL SELECT 'payout_transaction', COUNT(*) FROM payout_transaction
UNION ALL SELECT 'match_performance', COUNT(*) FROM match_performance
UNION ALL SELECT 'anticheat_violation', COUNT(*) FROM anticheat_violation;


SET GLOBAL foreign_key_checks = 0;
SET UNIQUE_CHECKS = 0;

SELECT * FROM player;

SHOW TABLES;


USE esports_platform;

-- Temporarily disable foreign key checks and strict mode
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS = 0;
SET SQL_MODE = '';

SHOW WARNINGS;

