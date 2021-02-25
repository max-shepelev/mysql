DROP PROCEDURE IF EXISTS get_change_table;
DELIMITER $

CREATE PROCEDURE get_change_table(
    IN  _change_amount    INT
) 
BEGIN
    DECLARE variation_boundary  INT DEFAULT 10;
    DECLARE is_done             TINYINT(1) DEFAULT 0;
    DECLARE change_generated    INT DEFAULT 0;
    DECLARE total               INT DEFAULT 0;
    
    DROP TEMPORARY TABLE IF EXISTS generated_change;
    
    SET @rank_pos := 0;

    CREATE TEMPORARY TABLE Wallet AS 
        SELECT W.coin_id,
                W.coin_quantity,
                W.coin_value,
                (@rank_pos := @rank_pos + 1) AS rank_pos
        FROM (
            SELECT V.coin_id,
                    V.coin_quantity + COALESCE(Cust.coin_quantity, 0)
                    AS coin_quantity,
                    c.coin_value
            FROM VendingMachine V
                LEFT JOIN Customer Cust
                    ON V.coin_id = Cust.coin_id
                        INNER JOIN coins C
                            ON V.coin_id = C.coin_id
            ORDER BY C.coin_value DESC
        ) W
        WHERE W.coin_quantity > 0;
        
        CREATE TEMPORARY TABLE Wallet2 
            SELECT * FROM Wallet;
        CREATE TEMPORARY TABLE Wallet3 
            SELECT * FROM Wallet;
        CREATE TEMPORARY TABLE Wallet4 
            SELECT * FROM Wallet;
            
        CREATE TEMPORARY TABLE tmp AS
            SELECT _change_amount AS `change`,
                    coin_id, 
                    coin_value,
                    coin_quantity, 
                    -1 AS `level`,
                    NULL IS NOT NULL AS DFS_continues,
                    CAST('' AS CHAR(20)) AS grp
            FROM Wallet
            ORDER BY rank_pos ASC
            LIMIT 1;
       
        CREATE TEMPORARY TABLE generated_change LIKE tmp;
        CREATE TEMPORARY TABLE generated_level LIKE tmp;
        CREATE TEMPORARY TABLE generated_level2 LIKE tmp;

        WHILE NOT is_done DO
            TRUNCATE TABLE generated_level;
            TRUNCATE TABLE generated_level2;
            
            INSERT INTO generated_level
            SELECT *
            FROM tmp;
            
            INSERT INTO generated_level2
            SELECT *
            FROM tmp;
            
            INSERT INTO generated_change
            SELECT `change`,
                    coin_id, 
                    coin_value,
                    coin_quantity, 
                     `level`,
                     DFS_continues,
                     grp
            FROM tmp;

            SELECT COUNT(CASE WHEN `change` = 0 THEN 1 END), 
                    COUNT(*)
            INTO change_generated, total
            FROM tmp;

            TRUNCATE TABLE tmp;
            
            IF change_generated = 0 AND total > 0
            THEN
                
                INSERT INTO tmp
                SELECT 
                    `change`,
                    coin_id, 
                    coin_value,
                    coin_quantity, 
                    `level` + 1 AS `level`,
                    t1.DFS_continues,
                    t1.grp
                    FROM (
                        SELECT 
                            prev_coin.`change` - W.coin_value AS `change`,
                            W.coin_id, 
                            W.coin_value,
                            CASE WHEN W.coin_id = prev_coin.coin_id
                                THEN prev_coin.coin_quantity - 1
                                ELSE W.coin_quantity - 1
                            END coin_quantity,
                            `level`,
                            CASE WHEN prev_coin.coin_id = W.coin_id 
                                AND (prev_coin.`change` - W.coin_value)
                                    > COALESCE(W2.coin_value, 0) * variation_boundary
                                THEN 1
                                ELSE 0
                            END DFS_continues,
                            CONCAT(prev_coin.`change`,'|',prev_coin.coin_id,'|',prev_coin.coin_quantity) AS grp
                        FROM Wallet W
                            LEFT JOIN Wallet2 W2
                                ON W2.rank_pos = W.rank_pos + 1
                                    CROSS JOIN generated_level prev_coin
                        WHERE prev_coin.coin_value >= W.coin_value
                            AND prev_coin.`change` >= W.coin_value
                            AND (prev_coin.coin_id <> W.coin_id OR prev_coin.coin_quantity > 0 )
                    ) t1
                        INNER JOIN (
                            SELECT MAX(
                                CASE WHEN prev_coin.coin_id = W.coin_id 
                                    AND (prev_coin.`change` - W.coin_value)
                                        > COALESCE(W2.coin_value, 0) * variation_boundary
                                    THEN 1
                                    ELSE 0
                                    END
                            ) AS DFS_continues,
                            CONCAT(prev_coin.`change`,'|',prev_coin.coin_id,'|',prev_coin.coin_quantity) AS grp
                            FROM Wallet3 W
                                LEFT JOIN Wallet4 W2
                                    ON W2.rank_pos = W.rank_pos + 1
                                        CROSS JOIN generated_level2 prev_coin
                            WHERE prev_coin.coin_value >= W.coin_value
                                AND prev_coin.`change` >= W.coin_value
                                AND (prev_coin.coin_id <> W.coin_id OR prev_coin.coin_quantity > 0 )
                            GROUP BY CONCAT(prev_coin.`change`,'|',prev_coin.coin_id,'|',prev_coin.coin_quantity)
                        ) t2 
                            ON t1.grp = t2.grp
                            AND t1.DFS_continues = t2.DFS_continues
                            AND coin_quantity >= 0;


            ELSE
                SET is_done := 1;
                TRUNCATE TABLE generated_level;
                TRUNCATE TABLE generated_level2;
            END IF;
            
            
        END WHILE;
        
        SET is_done := 0;
        
        INSERT INTO tmp
        SELECT *
        FROM generated_change g
        WHERE g.`change` = 0 AND g.coin_quantity >= 0
        LIMIT 1;
        
        INSERT INTO generated_level 
        SELECT *
        FROM tmp;
        
        IF NOT EXISTS(
            SELECT * 
            FROM generated_level
        )THEN SET is_done = 0;
        END IF;
        
        WHILE NOT is_done DO
            INSERT INTO generated_level2
            SELECT 
                `prev`.`change`,
                `prev`.coin_id, 
                `prev`.coin_value,
                `prev`.coin_quantity, 
                `prev`.`level`,
                `prev`.DFS_continues,
                `prev`.grp
            FROM generated_level cur
                INNER JOIN generated_change `prev`
                    ON `prev`.`level` = cur.`level` - 1
                    AND `prev`.`change` = cur.`change` + cur.coin_value
                    AND `prev`.`level` <> -1;
            
            IF NOT EXISTS(
                SELECT * 
                FROM generated_level2
                LIMIT 1
            )
            THEN 
                SET is_done := 1;
            END IF;
            
            TRUNCATE TABLE generated_level;
            
            INSERT INTO generated_level 
            SELECT *
            FROM generated_level2;
            
            TRUNCATE TABLE generated_level2;
            
            INSERT INTO tmp
            SELECT *
            FROM generated_level;
            
        END WHILE;
    
        

        
        DROP TEMPORARY TABLE IF EXISTS generated_change;
    
        CREATE TEMPORARY TABLE generated_change
        SELECT coin_id,
                COUNT(*) AS coin_quantity
        FROM tmp
        GROUP BY coin_id;
        
        DROP TEMPORARY TABLE IF EXISTS Wallet;
        DROP TEMPORARY TABLE IF EXISTS Wallet2;
        DROP TEMPORARY TABLE IF EXISTS Wallet3;
        DROP TEMPORARY TABLE IF EXISTS Wallet4;
        DROP TEMPORARY TABLE IF EXISTS tmp;
        DROP TEMPORARY TABLE IF EXISTS generated_level;
        DROP TEMPORARY TABLE IF EXISTS generated_level2;
       
END$

DELIMITER ;