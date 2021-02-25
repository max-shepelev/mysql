DROP PROCEDURE IF EXISTS customer_ins;
DELIMITER $

CREATE PROCEDURE customer_ins(
    _coin_id     INT
) 
BEGIN
    DECLARE _errno      INT;
    DECLARE _msg        TEXT;
    DECLARE _sqlstate   INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET CURRENT DIAGNOSTICS CONDITION 1
            _errno = MYSQL_ERRNO, _msg = MESSAGE_TEXT, _sqlstate = RETURNED_SQLSTATE;
            SELECT _errno, _sqlstate, 'customer_ins' AS _proc,  _msg;
    END;
    
    INSERT INTO Customer(coin_id, coin_quantity)
    SELECT _coin_id, 1
    ON DUPLICATE KEY
        UPDATE coin_quantity = coin_quantity + 1;

END$

DELIMITER ;