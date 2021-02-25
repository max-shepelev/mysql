DROP PROCEDURE IF EXISTS products_sell;
DELIMITER $

CREATE PROCEDURE products_sell(
    IN  _product_name    CHAR(50)
) 
BEGIN
    DECLARE product_price     INT DEFAULT NULL;
    DECLARE change_amount     INT DEFAULT NULL;
    DECLARE _error_message    VARCHAR(100);
    DECLARE _errno            INT;
    DECLARE _msg              TEXT;
    DECLARE _sqlstate         INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET CURRENT DIAGNOSTICS CONDITION 1
            _errno = MYSQL_ERRNO,
            _msg = MESSAGE_TEXT,
            _sqlstate = RETURNED_SQLSTATE;
            SELECT _errno, _sqlstate, 'products_sell' AS _proc,  _msg;
            
        DROP TEMPORARY TABLE IF EXISTS generated_change;
        ROLLBACK;
    END;
    
    /* Having serializable level is debatable. Read commited should suffice*/
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    START TRANSACTION;
            
            SELECT P.product_price
            INTO product_price
            FROM Products P
            WHERE P.product_name = _product_name
                AND P.product_quantity > 0;
	   
            IF product_price IS NULL THEN
                SET _error_message = CONCAT('Product (', _product_name, ') is missing');
                SIGNAL SQLSTATE '45002'
                SET MESSAGE_TEXT = _error_message;
            END IF;
 
            SELECT SUM(C.coin_value * Cust.coin_quantity)
                    - product_price
            INTO change_amount
            FROM Customer Cust
                INNER JOIN Coins C
                    ON Cust.coin_id = C.coin_id;              

            IF change_amount IS NULL OR change_amount < 0 THEN
             SET _error_message = CONCAT('Not enough money to purchase (', _product_name, ')');
                SIGNAL SQLSTATE '45002'
                SET MESSAGE_TEXT = _error_message;
            END IF;

            CALL get_change_table(change_amount);
            
            UPDATE VendingMachine V
                INNER JOIN (
                    SELECT V.coin_id,
                            V.coin_quantity 
                                - COALESCE(Ch.coin_quantity,   0)    
                                + COALESCE(Cust.coin_quantity, 0) 
                            AS coin_quantity,
                            CASE WHEN Ch.coin_id IS NULL
                                THEN @ret_count
                                ELSE @ret_count := @ret_count + 1
                            END coins_returned
                    FROM VendingMachine V
                        LEFT JOIN generated_change AS Ch
                            ON V.coin_id = Ch.coin_id
                                LEFT JOIN Customer Cust
                                    ON V.coin_id = Cust.coin_id
                                        CROSS JOIN (SELECT @ret_count := 0) ret
                ) new_coins
                ON V.coin_id = new_coins.coin_id          
            SET V.coin_quantity = new_coins.coin_quantity
            WHERE (new_coins.coins_returned > 0 OR change_amount = 0);
            
            IF ROW_COUNT() = 0 THEN
                SET _error_message = 'Not enough coins to get change';
                SIGNAL SQLSTATE '45002'
                    SET MESSAGE_TEXT = _error_message;
            END IF;
            
            TRUNCATE TABLE Customer;
			  
            UPDATE Products P
            SET product_quantity = product_quantity - 1
            WHERE P.product_name = _product_name;
            
            DROP TEMPORARY TABLE IF EXISTS generated_change;
	    COMMIT;
        SELECT 1;
END$

DELIMITER ;