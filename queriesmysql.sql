-- =============================================================================
-- FILE: queries.sql
-- PROJECT: Esports Platform Database Management System
-- SECTIONS INCLUDED: 
--   3. Advanced SQL Queries
--   4. Database Objects (Views, Stored Procedure, Trigger)
--   5. Performance Tuning & Indexing
-- =============================================================================

USE esports_platform;

-- =============================================================================
-- SECTION 3: ADVANCED SQL QUERIES
-- =============================================================================

-- 3.1 Multi-Table Inner Join & Left Join with Aggregation
-- Description: Top performing players per team with their total earnings and average KDA
SELECT 
    p.Player_ID,
    p.IGN,
    p.Country,
    t.Team_Name,
    gt.Game_Title,
    COUNT(te.Entry_ID) AS Total_Matches,
    ROUND(AVG(mp.KDA_Ratio), 2) AS Avg_KDA,
    COALESCE(SUM(pp.Prize_Amount), 0) AS Total_Earnings
FROM player p
JOIN tournament_entry te ON p.Player_ID = te.Player_ID
JOIN team_roster t ON te.Team_ID = t.Team_ID
JOIN match_schedule ms ON te.Match_ID = ms.Match_ID
JOIN competitive_league cl ON ms.League_ID = cl.League_ID
JOIN game_title gt ON cl.Game_ID = gt.Game_ID
LEFT JOIN match_performance mp ON te.Entry_ID = mp.Entry_ID
LEFT JOIN prize_payout pp ON te.Entry_ID = pp.Entry_ID
GROUP BY p.Player_ID, p.IGN, p.Country, t.Team_Name, gt.Game_Title
HAVING Total_Earnings > 10000
ORDER BY Total_Earnings DESC;


-- 3.2 Self Join
-- Description: Pairs of distinct players from the same country who hold the same VIP Pass Tier
SELECT 
    p1.IGN AS Player_1,
    p2.IGN AS Player_2,
    p1.Country,
    vp.Pass_Tier
FROM player p1
JOIN player p2 ON p1.Country = p2.Country 
              AND p1.Pass_ID = p2.Pass_ID 
              AND p1.Player_ID < p2.Player_ID
JOIN vip_pass vp ON p1.Pass_ID = vp.Pass_ID
ORDER BY p1.Country, vp.Pass_Tier;


-- 3.3 Correlated Subquery
-- Description: Find players whose MMR Rating is above the average MMR of their specific country
SELECT 
    p1.Player_ID,
    p1.IGN,
    p1.Country,
    p1.MMR_Rating
FROM player p1
WHERE p1.MMR_Rating > (
    SELECT AVG(p2.MMR_Rating)
    FROM player p2
    WHERE p2.Country = p1.Country
)
ORDER BY p1.Country, p1.MMR_Rating DESC;


-- 3.4 Aggregate Query with GROUP BY + HAVING
-- Description: Leagues with more than 10 anticheat violations detected
SELECT 
    cl.League_ID,
    cl.League_Name,
    gt.Game_Title,
    COUNT(av.Violation_ID) AS Total_Violations,
    GROUP_CONCAT(DISTINCT av.Cheat_Type SEPARATOR ', ') AS Detected_Cheats
FROM competitive_league cl
JOIN game_title gt ON cl.Game_ID = gt.Game_ID
JOIN match_schedule ms ON cl.League_ID = ms.League_ID
JOIN tournament_entry te ON ms.Match_ID = te.Match_ID
JOIN anticheat_violation av ON te.Entry_ID = av.Entry_ID
GROUP BY cl.League_ID, cl.League_Name, gt.Game_Title
HAVING Total_Violations > 10
ORDER BY Total_Violations DESC;


-- =============================================================================
-- SECTION 4: DATABASE OBJECTS (VIEWS, PROCEDURES, TRIGGERS)
-- =============================================================================

-- 4.1 Reporting View 1: Player Performance & Loyalty Overview
CREATE OR REPLACE VIEW vw_player_performance_overview AS
SELECT 
    p.Player_ID,
    p.IGN,
    p.Country,
    vp.Pass_Tier,
    COUNT(te.Entry_ID) AS Total_Matches_Played,
    ROUND(AVG(mp.KDA_Ratio), 2) AS Avg_KDA,
    ROUND(AVG(mp.Combat_Score), 2) AS Avg_Combat_Score,
    ROUND(AVG(mp.Headshot_Pct), 2) AS Avg_Headshot_Pct
FROM player p
JOIN vip_pass vp ON p.Pass_ID = vp.Pass_ID
LEFT JOIN tournament_entry te ON p.Player_ID = te.Player_ID
LEFT JOIN match_performance mp ON te.Entry_ID = mp.Entry_ID
GROUP BY p.Player_ID, p.IGN, p.Country, vp.Pass_Tier;


-- 4.2 Reporting View 2: Financial Payout Status & Payment Method Summary
CREATE OR REPLACE VIEW vw_payout_financial_summary AS
SELECT 
    pt.Payment_Method,
    pt.Txn_Status,
    COUNT(pt.Txn_ID) AS Total_Transactions,
    SUM(pp.Prize_Amount) AS Total_Payout_Amount,
    ROUND(AVG(pp.Prize_Amount), 2) AS Avg_Payout_Amount
FROM payout_transaction pt
JOIN prize_payout pp ON pt.Payout_ID = pp.Payout_ID
GROUP BY pt.Payment_Method, pt.Txn_Status;


-- 4.3 Stored Procedure with Input Parameter
-- Description: Retrieve full tournament activity and financial details for a specific Player ID
DELIMITER //
CREATE PROCEDURE sp_get_player_full_profile(IN p_player_id VARCHAR(10))
BEGIN
    SELECT 
        p.Player_ID,
        p.IGN,
        t.Team_Name,
        ms.Match_ID,
        ms.Server_Region,
        COALESCE(mp.KDA_Ratio, 0) AS KDA_Ratio,
        COALESCE(pp.Prize_Amount, 0) AS Prize_Money,
        COALESCE(pt.Txn_Status, 'No Payout') AS Payout_Status
    FROM player p
    JOIN tournament_entry te ON p.Player_ID = te.Player_ID
    JOIN team_roster t ON te.Team_ID = t.Team_ID
    JOIN match_schedule ms ON te.Match_ID = ms.Match_ID
    LEFT JOIN match_performance mp ON te.Entry_ID = mp.Entry_ID
    LEFT JOIN prize_payout pp ON te.Entry_ID = pp.Entry_ID
    LEFT JOIN payout_transaction pt ON pp.Payout_ID = pt.Payout_ID
    WHERE p.Player_ID = p_player_id;
END //
DELIMITER ;


-- 4.4 Trigger: Business Rule Validation & Auditing
-- Description: Prevent invalid negative numbers in match performance metrics
DELIMITER //
CREATE TRIGGER trg_check_performance_validity
BEFORE INSERT ON match_performance
FOR EACH ROW
BEGIN
    IF NEW.KDA_Ratio < 0 OR NEW.Combat_Score < 0 OR NEW.Headshot_Pct < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Data Validation Error: KDA, Combat Score, and Headshot Pct must be non-negative numbers.';
    END IF;
END //
DELIMITER ;


-- =============================================================================
-- SECTION 5: PERFORMANCE TUNING & INDEXING
-- =============================================================================

-- Step 1: Run EXPLAIN before indexing to inspect query execution plan
EXPLAIN SELECT * FROM tournament_entry WHERE Player_ID = 'P0476';
EXPLAIN SELECT * FROM player WHERE Country = 'India' AND MMR_Rating > 2000;

-- Step 2: Create targeted Indexes on frequently queried Foreign Keys and Filter Columns
CREATE INDEX idx_tournament_entry_player ON tournament_entry(Player_ID);
CREATE INDEX idx_tournament_entry_match ON tournament_entry(Match_ID);
CREATE INDEX idx_player_country_mmr ON player(Country, MMR_Rating);
CREATE INDEX idx_match_schedule_league ON match_schedule(League_ID);

-- Step 3: Run EXPLAIN after indexing to confirm index usage and performance gain
EXPLAIN SELECT * FROM tournament_entry WHERE Player_ID = 'P0476';
EXPLAIN SELECT * FROM player WHERE Country = 'India' AND MMR_Rating > 2000;



-- TEST STORED PROCEDURE
CALL sp_get_player_full_profile('P0476');
-- TEST VIEWS
SELECT * FROM vw_player_performance_overview LIMIT 10;
SELECT * FROM vw_payout_financial_summary;