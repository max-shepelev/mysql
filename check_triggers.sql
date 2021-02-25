DROP PROCEDURE IF EXISTS check_product;
DELIMITER $
CREATE PROCEDURE check_product (
    price INT,
    quantity INT
) 
BEGIN
    
    IF price <= 0 THEN
        SIGNAL SQLSTATE '45000'
	    SET MESSAGE_TEXT = 'check constraint on Products.product_price failed';
    END IF;
    
    IF quantity < 0 THEN
        SIGNAL SQLSTATE '45001'
        SET MESSAGE_TEXT = 'check constraint on Products.product_quantity failed';
    END IF;
END$

DROP TRIGGER IF EXISTS Products_before_insert$
DROP TRIGGER IF EXISTS Products_before_update$

CREATE TRIGGER Products_before_insert BEFORE INSERT ON Products
FOR EACH ROW
BEGIN
    CALL check_product(NEW.product_price, NEW.product_quantity);
END$  
 
CREATE TRIGGER Products_before_update BEFORE UPDATE ON Products
FOR EACH ROW
BEGIN
    CALL check_product(NEW.product_price, NEW.product_quantity);
END$   
DELIMITER ;