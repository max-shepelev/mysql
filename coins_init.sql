DROP TABLE IF EXISTS VendingMachine;
DROP TABLE IF EXISTS Customer;
DROP TABLE IF EXISTS Coins;
DROP TABLE IF EXISTS Products;

CREATE TABLE Coins(
	coin_id		INT AUTO_INCREMENT,
	coin_value	INT NOT NULL,
	coin_name	VARCHAR(50) NOT NULL,
    
    CONSTRAINT PK_Coins_coinID PRIMARY KEY(coin_id),
    INDEX IX_Coins_coinValue (coin_value)
);

CREATE TABLE VendingMachine(
	coin_id			INT,
	coin_quantity	INT NOT NULL DEFAULT 0,
    
    CONSTRAINT PK_VendingMachine_coinId PRIMARY KEY(coin_id),
    CONSTRAINT FK_VendingMachine_coinId FOREIGN KEY(coin_id)
		REFERENCES Coins(coin_id)
);

CREATE TABLE Customer(
	coin_id			INT,
	coin_quantity	INT NOT NULL DEFAULT 0,
    
    CONSTRAINT PK_Customer_coinId PRIMARY KEY(coin_id),
    CONSTRAINT FK_Customer_coinId FOREIGN KEY(coin_id)
		REFERENCES Coins(coin_id)
);

CREATE TABLE Products(
	product_id			INT AUTO_INCREMENT,
    product_name		VARCHAR(50) NOT NULL UNIQUE,
    product_price		INT NOT NULL,
    product_quantity	INT NOT NULL DEFAULT 0,
    
    CONSTRAINT PK_Products_productId PRIMARY KEY(product_id DESC)
);


INSERT INTO Coins(
    coin_value, 
    coin_name
)
VALUES
(10, 'RUB'),
(5, 'RUB'),
(2, 'RUB'),
(1, 'RUB');

INSERT INTO VendingMachine(
    coin_id,
    coin_quantity
)
VALUES 
(1, 2000),
(2, 2000),
(3, 2000),
(4, 2000);

INSERT INTO Products(
    product_name,
    product_price,
    product_quantity
)
VALUES
('Tea',              25,    5),
('Cappuccino',       39,    3),
('Cocoa',            23,    10),
('Hot Chocolate',    31,    8);

