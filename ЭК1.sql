drop table if exists emp_log;
drop table if exists emp;
drop table if exists dep;

create table dep(
    id int primary key,
    name varchar(100)
);


create table emp(
    id int primary key,
    DEP_ID_FK int,
    active int,
    FIO varchar(100),
    birthdate date,
    constraint fk_emp_dep_id foreign key (dep_id_fk) 
        references dep(id)
);


create table emp_log(
    ID int primary key,
    REGDATE date,
    RECORD_TYPE int,
    EMP_ID_FK int,
    constraint fk_emp_log_emp_id foreign key (emp_id_fk) 
        references emp(id)
);

insert into dep(id, name)
values(1, 'sales'),
(2,'hr'),
(3,'IT');


insert into emp(id, dep_id_fk, active, fio, birthdate)
values
(1, 1, 1, 'Pavel', '2000-03-01'),
(2, 1, 1, 'Darya', '2001-03-22'),
(3, 1, 1, 'Anastasia', '2002-04-25'),
(4, 1, 0, 'Demosfen', '2003-06-07'),
(5, 1, 1, 'Olga', '2004-07-15'),
(6, 2, 1, 'Valdo', '2005-05-03'),
(7, 2, 0, 'Vadim', '2006-08-01'),
(8, 3, 1, 'Alex', '2007-10-11'),
(9, 3, 0, 'Irene', '2008-11-01'),
(10, 2, 1, 'Forest', '2009-12-22'),
(11, 2, 1, 'Pavel', '2010-01-24'),
(12, 3, 0, 'Plum', '1967-08-05'),
(13, 3, 1, 'Mary', '1994-05-06'),
(14, 1, 1, 'Polina', '2000-01-01'),
(15, 3, 0, 'Polvo', '1967-08-05'),
(16, 2, 1, 'Cain', '1994-05-06'),
(17, 1, 1, 'Aurora', '2000-01-01');


insert into emp_log(ID, REGDATE, RECORD_TYPE, EMP_ID_FK)
values
(1, '2019-03-02', 0, 1),
(2, '2019-04-01', 0, 2),
(3, '2019-05-29', 0, 3),
(4, '2019-06-25', 0, 4),
(5, '2019-05-01', 0, 5),
(6, '2019-04-01', 0, 6),
(7, '2019-05-01', 0, 7),
(8, '2019-05-01', 0, 8),
(9, '2019-05-01', 0, 9),
(10, '2019-07-01', 0, 10),
(11, '2020-08-01', 0, 11),
(12, '2020-09-01', 0, 12),
(13, '2020-02-01', 0, 13),
(14, '2020-10-01', 0, 14),
(15, '2021-10-01', 0, 15),
(16, '2021-10-01', 0, 16),
(17, '2021-01-01', 0, 17),

(18, '2021-01-01', 1, 1),
(19, '2020-03-01', 1, 3),
(20, '2020-04-01', 1, 4),
(21, '2020-10-01', 1, 5),
(22, '2020-10-01', 1, 6),
(24, '2020-03-01', 1, 8),
(25, '2020-01-01', 1, 9),
(26, '2021-05-01', 1, 10),
(27, '2021-02-01', 1, 11),
(28, '2021-05-01', 1, 12),
(29, '2021-05-25', 1, 17);


SET @cur_date := '2021-03-02';

SELECT t1.`year` AS 'Год',
        t1.`month` AS 'Месяц',
        t1.dep_name AS 'Отдел', 
        t1.birthdays_num AS 'Кол-во д/р',
        t1.birthdays_num - COALESCE(t2.birthdays_num, 0) AS 'Дельта'
FROM(
    SELECT `year`,
             MAX(`month`) AS `month`,
             dates_n_dep.dep_name, 
             COUNT(birthdate) AS birthdays_num,
             m_num
    FROM(
        SELECT EXTRACT(YEAR FROM dt) AS `year`, 
                    MONTHNAME(dt) AS `month`,
                    dep.name AS dep_name,
                    LAST_day(dt) AS eof_month,
                    EXTRACT(MONTH FROM dt) AS m_num
        FROM(
            SELECT DATE_ADD(first_date, INTERVAL months.m_num MONTH) as dt, m_num
            FROM (
                SELECT @m_num := @m_num + 1 AS m_num,
                MONTHNAME(str_to_date(@m_num,'%m')) AS m_name
                FROM (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1,
                    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t2,
                    (SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 ) t3,
                    (SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 ) t4,
                    (SELECT @m_num := 0) numbers
            ) months, 
            (
            SELECT DATE_SUB(MAKEDATE(YEAR(MIN(REGDATE)), 1), INTERVAL 1 MONTH) AS first_date
            FROM emp_log
            WHERE REGDATE <= @cur_date
            ) t
            WHERE EXTRACT(YEAR FROM DATE_ADD(first_date, INTERVAL months.m_num MONTH)) <= EXTRACT(YEAR FROM @cur_date)
        ) all_dates
            CROSS JOIN dep
    ) dates_n_dep
        LEFT JOIN(
            SELECT emp.id AS emp_id,
                MAX(emp.birthdate) AS birthdate,
                MAX(dep.name) AS dep_name,
                MIN(emp_log.REGDATE) AS hire_date,
                CASE WHEN COUNT(*) = 1 
                    THEN NULL 
                    ELSE MAX(emp_log.REGDATE)
                END fire_date
            FROM emp_log
                INNER JOIN emp 
                    ON emp.id = emp_log.EMP_ID_FK
                        INNER JOIN dep
                            ON dep.id = emp.DEP_ID_FK
            GROUP BY emp.id
        ) hired_n_fired
            ON EXTRACT(MONTH FROM hired_n_fired.birthdate) = m_num
            AND hired_n_fired.dep_name = dates_n_dep.dep_name
            AND EXTRACT(YEAR FROM hired_n_fired.hire_date) <= `year`
            AND (
                hired_n_fired.fire_date IS NULL 
                OR EXTRACT(YEAR FROM hired_n_fired.fire_date) > `year`
            )
    GROUP BY `year`, m_num, dates_n_dep.dep_name
) t1 
    LEFT JOIN 
        (
    SELECT `year`,
             MAX(`month`) AS `month`,
             dates_n_dep.dep_name, 
             COUNT(birthdate) AS birthdays_num,
             m_num
    FROM(
        SELECT EXTRACT(YEAR FROM dt) AS `year`, 
                    MONTHNAME(dt) AS `month`,
                    dep.name AS dep_name,
                    LAST_day(dt) AS eof_month,
                    EXTRACT(MONTH FROM dt) AS m_num
        FROM(
            SELECT DATE_ADD(first_date, INTERVAL months.m_num MONTH) as dt, m_num
            FROM (
                SELECT @m_num2 := @m_num2 + 1 AS m_num,
                MONTHNAME(str_to_date(@m_num2,'%m')) AS m_name
                FROM (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t1,
                    (SELECT 0 UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) t2,
                    (SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 ) t3,
                    (SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 ) t4,
                    (SELECT @m_num2 := 0) numbers
            ) months, 
            (
            SELECT DATE_SUB(MAKEDATE(YEAR(MIN(REGDATE)), 1), INTERVAL 1 MONTH) AS first_date
            FROM emp_log
            WHERE REGDATE <= @cur_date
            ) t
            WHERE EXTRACT(YEAR FROM DATE_ADD(first_date, INTERVAL months.m_num MONTH)) <= EXTRACT(YEAR FROM @cur_date)
        ) all_dates
            CROSS JOIN dep
    ) dates_n_dep
        LEFT JOIN(
            SELECT emp.id AS emp_id,
                MAX(emp.birthdate) AS birthdate,
                MAX(dep.name) AS dep_name,
                MIN(emp_log.REGDATE) AS hire_date,
                CASE WHEN COUNT(*) = 1 
                    THEN NULL 
                    ELSE MAX(emp_log.REGDATE)
                END fire_date
            FROM emp_log
                INNER JOIN emp 
                    ON emp.id = emp_log.EMP_ID_FK
                        INNER JOIN dep
                            ON dep.id = emp.DEP_ID_FK
            GROUP BY emp.id
        ) hired_n_fired
            ON EXTRACT(MONTH FROM hired_n_fired.birthdate) = m_num
            AND hired_n_fired.dep_name = dates_n_dep.dep_name
            AND EXTRACT(YEAR FROM hired_n_fired.hire_date) <= `year`
            AND (
                hired_n_fired.fire_date IS NULL 
                OR EXTRACT(YEAR FROM hired_n_fired.fire_date) > `year`
            )
    GROUP BY `year`, m_num, dates_n_dep.dep_name
) t2
    ON t1.`year` = t2.`year` + 1
    AND t1.`month` = t2.`month`
    AND t1.dep_name = t2.dep_name
ORDER BY t1.`year`, t1.m_num, t1.dep_name


