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
    
    DROP TEMPORARY TABLE IF EXISTS Wallet;
    DROP TEMPORARY TABLE IF EXISTS Wallet2;
    DROP TEMPORARY TABLE IF EXISTS generated_change;
    DROP TEMPORARY TABLE IF EXISTS generated_level;
    DROP TEMPORARY TABLE IF EXISTS generated_level2;
    DROP TEMPORARY TABLE IF EXISTS tmp;

    
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
        
        CREATE TEMPORARY TABLE tmp (
            `change`        INT, 
            coin_id         INT, 
            coin_value      INT, 
            coin_quantity   INT, 
            `level`         INT, 
            DFS_continues   INT, 
            grp             varchar(20000)
        );

        INSERT INTO tmp 
        SELECT _change_amount,
                    coin_id, 
                    coin_value,
                    coin_quantity, 
                    -1 AS `level`,
                    NULL IS NOT NULL AS DFS_continues,
                    '' AS grp
        FROM Wallet
        ORDER BY rank_pos ASC
        LIMIT 1;        
         
        CREATE TEMPORARY TABLE Wallet2 
            SELECT * FROM Wallet;
            
        CREATE TEMPORARY TABLE generated_change LIKE tmp;
        CREATE TEMPORARY TABLE generated_level  LIKE tmp;
        CREATE TEMPORARY TABLE generated_level2 (DFS_continues INT, grp varchar(20000));

        
        WHILE NOT is_done DO
            TRUNCATE TABLE generated_level;
            TRUNCATE TABLE generated_level2;
            
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
            
            IF change_generated = 0 AND total > 0
            THEN
                
                INSERT INTO generated_level
                SELECT 
                    prev_coin.`change` AS `change`,
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
                    prev_coin.grp AS grp
                FROM Wallet W
                    LEFT JOIN Wallet2 W2
                        ON W2.rank_pos = W.rank_pos + 1
                            CROSS JOIN tmp prev_coin
                WHERE prev_coin.coin_value >= W.coin_value
                    AND prev_coin.`change` >= W.coin_value
                    AND (prev_coin.coin_id <> W.coin_id OR prev_coin.coin_quantity > 0 );
                    
                INSERT INTO generated_level2
                SELECT 
                    MAX(DFS_continues) AS DFS_continues,
                    prev_coin.grp AS grp
                FROM generated_level prev_coin
                GROUP BY prev_coin.grp;
                
                
                TRUNCATE TABLE tmp;
                
                INSERT INTO tmp
                SELECT 
                    t1.`change` - t1.coin_value,
                    coin_id, 
                    coin_value,
                    coin_quantity, 
                    `level` + 1 AS `level`,
                    t1.DFS_continues,
                    CONCAT(t1.grp, coin_id, '|' ) AS grp
                FROM generated_level t1
                    INNER JOIN generated_level2 t2
                        ON t1.grp = t2.grp
                        AND t1.DFS_continues = t2.DFS_continues
                        AND coin_quantity >= 0;


            ELSE
                SET is_done := 1;
            END IF;
            
            
        END WHILE;
        

        DROP TEMPORARY TABLE IF EXISTS tmp;
        CREATE TEMPORARY TABLE tmp (coin_id CHAR(255));
        
        IF EXISTS(
            SELECT grp AS data
            FROM generated_change g 
            WHERE g.`change` = 0 AND g.coin_quantity >= 0 
            LIMIT 1
        ) THEN 
             SET @S1 = CONCAT("INSERT INTO tmp (coin_id) VALUES ('",REPLACE((
                SELECT grp AS data
                FROM generated_change g 
                WHERE g.`change` = 0 AND g.coin_quantity >= 0 
                LIMIT 1
            ), "|", "'),('"),"');");
            PREPARE stmt1 FROM @s1;
            EXECUTE stmt1;
        END IF;        
        
        DROP TEMPORARY TABLE IF EXISTS generated_change;
        
        CREATE TEMPORARY TABLE generated_change (coin_id INT, coin_quantity INT) AS
        SELECT CAST(coin_id AS UNSIGNED) coin_id,
            COUNT(*) AS coin_quantity
        FROM tmp
        WHERE coin_id <> ''
        GROUP BY tmp.coin_id;
                
        DROP TEMPORARY TABLE IF EXISTS Wallet;
        DROP TEMPORARY TABLE IF EXISTS Wallet2;
        DROP TEMPORARY TABLE IF EXISTS generated_level;
        DROP TEMPORARY TABLE IF EXISTS generated_level2;
        DROP TEMPORARY TABLE IF EXISTS tmp;
END$

DELIMITER ;