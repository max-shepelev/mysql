DROP PROCEDURE IF EXISTS check_zero_equalmore;
DROP PROCEDURE IF EXISTS check_zero_more;
DELIMITER $

CREATE PROCEDURE check_zero_equalmore(
    val         INT,
    table_col   VARCHAR(50)
)
BEGIN
    DECLARE _error_message VARCHAR(100) 
        DEFAULT CONCAT('val >= 0 check constraint on ', table_col,' failed');
    IF val < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = _error_message;
    END IF;
END$

CREATE PROCEDURE check_zero_more(
    val         INT,
    table_col   VARCHAR(100)
)
BEGIN
    DECLARE _error_message VARCHAR(100) 
        DEFAULT CONCAT('val > 0 check constraint on ', table_col,' failed');
    IF val <= 0 THEN
        SIGNAL SQLSTATE '45001'
        SET MESSAGE_TEXT = _error_message;
    END IF;
END$

DROP TRIGGER IF EXISTS Products_before_insert$
DROP TRIGGER IF EXISTS Products_before_update$
DROP TRIGGER IF EXISTS Coins_before_insert$
DROP TRIGGER IF EXISTS Coins_before_update$
DROP TRIGGER IF EXISTS VendingMachine_before_insert$
DROP TRIGGER IF EXISTS VendingMachine_before_update$
DROP TRIGGER IF EXISTS Customer_before_insert$
DROP TRIGGER IF EXISTS Customer_before_update$

CREATE TRIGGER Products_before_insert BEFORE INSERT ON Products
FOR EACH ROW
BEGIN
    CALL check_zero_equalmore(NEW.product_quantity, 'Products.product_quantity');
    CALL check_zero_more(NEW.product_price, 'Products.product_price');
END$  
 
CREATE TRIGGER Products_before_update BEFORE UPDATE ON Products
FOR EACH ROW
BEGIN
    CALL check_zero_equalmore(NEW.product_quantity, 'Products.product_quantity');
    CALL check_zero_more(NEW.product_price, 'Products.product_price');
END$   

CREATE TRIGGER Coins_before_insert BEFORE INSERT ON COINS
FOR EACH ROW
BEGIN
    CALL check_zero_more(NEW.coin_value, 'Coins.coin_value');
END$  

CREATE TRIGGER Coins_before_update BEFORE UPDATE ON COINS
FOR EACH ROW
BEGIN
    CALL check_zero_more(NEW.coin_value, 'Coins.coin_value');
END$


CREATE TRIGGER VendingMachine_before_insert BEFORE INSERT ON VendingMachine
FOR EACH ROW
BEGIN
    CALL check_zero_equalmore(NEW.coin_quantity, 'VendingMachine.coin_quantity');
END$  

CREATE TRIGGER VendingMachine_before_update BEFORE UPDATE ON VendingMachine
FOR EACH ROW
BEGIN
    CALL check_zero_equalmore(NEW.coin_quantity, 'VendingMachine.coin_quantity');
END$  

CREATE TRIGGER Customer_before_insert BEFORE INSERT ON Customer
FOR EACH ROW
BEGIN
    CALL check_zero_equalmore(NEW.coin_quantity, 'Customer.coin_quantity');
END$  

CREATE TRIGGER Customer_before_update BEFORE UPDATE ON Customer
FOR EACH ROW
BEGIN
    CALL check_zero_equalmore(NEW.coin_quantity, 'Customer.coin_quantity');
END$     
DELIMITER ;


