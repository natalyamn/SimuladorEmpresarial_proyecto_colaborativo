CREATE TABLE BANK_marketing_backup_211024 AS
SELECT * FROM BANK_marketing211024;

SELECT id, count(id)
FROM EquipB.BANK_marketing211024
GROUP BY id 
HAVING count(id) > 1;

SELECT *
FROM EquipB.BANK_marketing211024
WHERE id is NULL;

SELECT *
FROM EquipB.BANK_marketing211024
WHERE id is NULL;

SELECT 
    SUM(CASE WHEN id IS NULL OR "" THEN 1 ELSE 0 END) AS null_id,
    SUM(CASE WHEN age IS NULL OR ""THEN 1 ELSE 0 END) AS null_age,
    SUM(CASE WHEN job IS NULL OR ""THEN 1 ELSE 0 END) AS null_job,
    SUM(CASE WHEN marital IS NULL OR ""THEN 1 ELSE 0 END) AS null_marital,
    SUM(CASE WHEN education IS NULL OR ""THEN 1 ELSE 0 END) AS null_education,
    SUM(CASE WHEN `default` IS NULL OR ""THEN 1 ELSE 0 END) AS null_default,
    SUM(CASE WHEN balance IS NULL OR ""THEN 1 ELSE 0 END) AS null_balance,
    SUM(CASE WHEN housing IS NULL OR ""THEN 1 ELSE 0 END) AS null_housing,
    SUM(CASE WHEN loan IS NULL OR ""THEN 1 ELSE 0 END) AS null_loan,
    SUM(CASE WHEN contact IS NULL OR ""THEN 1 ELSE 0 END) AS null_contact,
    SUM(CASE WHEN `day` IS NULL OR ""THEN 1 ELSE 0 END) AS null_day,
    SUM(CASE WHEN `month` IS NULL OR ""THEN 1 ELSE 0 END) AS null_month,
    SUM(CASE WHEN duration IS NULL OR ""THEN 1 ELSE 0 END) AS null_duration,
    SUM(CASE WHEN campaign IS NULL OR ""THEN 1 ELSE 0 END) AS null_campaign,
    SUM(CASE WHEN pdays IS NULL OR ""THEN 1 ELSE 0 END) AS null_pdays,
    SUM(CASE WHEN previous IS NULL OR ""THEN 1 ELSE 0 END) AS null_previous,
    SUM(CASE WHEN poutcome IS NULL OR ""THEN 1 ELSE 0 END) AS null_poutcome,
    SUM(CASE WHEN deposit IS NULL OR ""THEN 1 ELSE 0 END) AS null_deposit
FROM BANK_marketing211024;

-- IMPUTACIONES DE NULOS:

-- AGE:

SELECT AVG(age), job, marital
FROM BANK_marketing211024
GROUP BY job, marital;

UPDATE BANK_marketing211024 AS b
SET age = (
    SELECT ROUND(avg_age)
    FROM (
        SELECT AVG(age) AS avg_age, job, marital
        FROM BANK_marketing211024
        WHERE age IS NOT NULL
        GROUP BY job, marital
    ) AS avg_table
    WHERE avg_table.job = b.job
      AND avg_table.marital = b.marital
)
WHERE b.age IS NULL;

-- MARITAL:

WITH marital_mode AS (
    SELECT job, 
           marital, 
           ROW_NUMBER() OVER (PARTITION BY job ORDER BY COUNT(*) DESC) AS rank_marital
    FROM BANK_marketing211024
    WHERE marital IS NOT NULL
    GROUP BY job, marital
)
SELECT job, marital
FROM marital_mode
WHERE rank_marital = 1;

START TRANSACTION;

UPDATE BANK_marketing211024 AS b
SET marital = (
    SELECT marital
    FROM (
        SELECT job, 
               marital, 
               ROW_NUMBER() OVER (PARTITION BY job ORDER BY COUNT(*) DESC) AS rank_marital
        FROM BANK_marketing211024
        WHERE marital IS NOT NULL
        GROUP BY job, marital
    ) AS marital_mode
    WHERE marital_mode.rank_marital = 1
      AND marital_mode.job = b.job
)
WHERE b.marital IS NULL;

-- Comprovamos si es correcto
SELECT COUNT(*) AS null_marital_count
FROM BANK_marketing211024
WHERE marital IS NULL;

-- Conformamos la transación
COMMIT;

-- En caso necesario se puede revertir con:
-- ROLLBACK;

-- EDUCATION:

WITH ModeEducation AS (
    SELECT job, marital, education,
           COUNT(*) AS freq
    FROM BANK_marketing211024
    WHERE education IS NOT NULL
    GROUP BY job, marital, education
),
RankedEducation AS (
    SELECT job, marital, education,
           ROW_NUMBER() OVER (PARTITION BY job, marital ORDER BY freq DESC) AS ranked_row
    FROM ModeEducation
)
SELECT bm.id, bm.job, bm.marital, bm.education AS original_education, re.education AS new_education
FROM BANK_marketing211024 bm
LEFT JOIN (
    SELECT job, marital, education
    FROM RankedEducation
    WHERE ranked_row = 1
) re
ON bm.job = re.job
AND bm.marital = re.marital
WHERE bm.education IS NULL;

-- Procedemos a actualizar la columna education

WITH ModeEducation AS (
    SELECT job, marital, education,
           COUNT(*) AS freq
    FROM BANK_marketing211024
    WHERE education IS NOT NULL
    GROUP BY job, marital, education
),
RankedEducation AS (
    SELECT job, marital, education,
           ROW_NUMBER() OVER (PARTITION BY job, marital ORDER BY freq DESC) AS ranked_row
    FROM ModeEducation
)
UPDATE BANK_marketing211024 bm
SET education = (
    SELECT re.education
    FROM (
        SELECT job, marital, education
        FROM RankedEducation
        WHERE ranked_row = 1
    ) re
    WHERE bm.job = re.job
    AND bm.marital = re.marital
)
WHERE bm.education IS NULL;

-- HOUSING: 

-- Identificamos la moda en cada grupo
SELECT housing, COUNT(*)
FROM BANK_marketing211024
GROUP BY housing;

SELECT age, job, education, marital, COUNT(*)
FROM BANK_marketing211024
GROUP BY age, job, education, marital
HAVING COUNT(*) > 1;

WITH HousingMode AS (
    SELECT LOWER(TRIM(age)) AS age, LOWER(TRIM(job)) AS job, LOWER(TRIM(education)) AS education, LOWER(TRIM(marital)) AS marital, housing,
           COUNT(housing) AS count_housing
    FROM BANK_marketing211024
    WHERE housing IS NOT NULL
    GROUP BY LOWER(TRIM(age)), LOWER(TRIM(job)), LOWER(TRIM(education)), LOWER(TRIM(marital)), housing
),
RankedHousing AS (
    SELECT age, job, education, marital, housing,
           ROW_NUMBER() OVER (PARTITION BY age, job, education, marital ORDER BY count_housing DESC) AS rn
    FROM HousingMode
)
SELECT * FROM RankedHousing WHERE rn = 1;

-- Actualizamos
WITH HousingMode AS (
    SELECT LOWER(TRIM(age)) AS age, LOWER(TRIM(job)) AS job, LOWER(TRIM(education)) AS education, LOWER(TRIM(marital)) AS marital, housing,
           COUNT(housing) AS count_housing
    FROM BANK_marketing211024
    WHERE housing IS NOT NULL
    GROUP BY LOWER(TRIM(age)), LOWER(TRIM(job)), LOWER(TRIM(education)), LOWER(TRIM(marital)), housing
),
RankedHousing AS (
    SELECT age, job, education, marital, housing,
           ROW_NUMBER() OVER (PARTITION BY age, job, education, marital ORDER BY count_housing DESC) AS rn
    FROM HousingMode
)
UPDATE BANK_marketing211024
SET housing = (
    SELECT housing
    FROM RankedHousing
    WHERE LOWER(TRIM(BANK_marketing211024.age)) = RankedHousing.age
      AND LOWER(TRIM(BANK_marketing211024.job)) = RankedHousing.job
      AND LOWER(TRIM(BANK_marketing211024.education)) = RankedHousing.education
      AND LOWER(TRIM(BANK_marketing211024.marital)) = RankedHousing.marital
      AND RankedHousing.rn = 1
)
WHERE housing IS NULL;

-- Quedan 2 nulos sin imputar

SELECT age, job, education, marital
FROM BANK_marketing211024
WHERE housing IS NULL;

SELECT age, job, education, marital
FROM BANK_marketing211024
WHERE age = 43 AND job = 'admin.' AND education ='secondary';

-- Solo hay los dos registros con housing null con estas caracteristicas por lo que decido 
-- repetir la operacion de imputacion eliminando el requisito de education

WITH HousingMode AS (
    SELECT LOWER(TRIM(age)) AS age, LOWER(TRIM(job)) AS job, LOWER(TRIM(marital)) AS marital, housing,
           COUNT(housing) AS count_housing
    FROM BANK_marketing211024
    WHERE housing IS NOT NULL
    GROUP BY LOWER(TRIM(age)), LOWER(TRIM(job)), LOWER(TRIM(marital)), housing
),
RankedHousing AS (
    SELECT age, job, marital, housing,
           ROW_NUMBER() OVER (PARTITION BY age, job, marital ORDER BY count_housing DESC) AS rn
    FROM HousingMode
)
UPDATE BANK_marketing211024
SET housing = (
    SELECT housing
    FROM RankedHousing
    WHERE LOWER(TRIM(BANK_marketing211024.age)) = RankedHousing.age
      AND LOWER(TRIM(BANK_marketing211024.job)) = RankedHousing.job
      AND LOWER(TRIM(BANK_marketing211024.marital)) = RankedHousing.marital
      AND RankedHousing.rn = 1
)
WHERE housing IS NULL;

-- DEFAULT:

-- Imputamos los nulls de default teniendo en cuenta job, marital, housing y loan

WITH DefaultMode AS (
    SELECT LOWER(TRIM(job)) AS job, 
           LOWER(TRIM(marital)) AS marital, 
           LOWER(TRIM(housing)) AS housing, 
           LOWER(TRIM(loan)) AS loan, 
           `default`,
           COUNT(`default`) AS count_default
    FROM BANK_marketing211024
    WHERE `default` IS NOT NULL
    GROUP BY LOWER(TRIM(job)), LOWER(TRIM(marital)), LOWER(TRIM(housing)), LOWER(TRIM(loan)), `default`
),
RankedDefault AS (
    SELECT job, marital, housing, loan, `default`,
           ROW_NUMBER() OVER (PARTITION BY job, marital, housing, loan ORDER BY count_default DESC) AS rn
    FROM DefaultMode
)
SELECT b.job, b.marital, b.housing, b.loan, b.default AS original_default, r.default AS new_default
FROM BANK_marketing211024 b
LEFT JOIN RankedDefault r
  ON LOWER(TRIM(b.job)) = r.job
  AND LOWER(TRIM(b.marital)) = r.marital
  AND LOWER(TRIM(b.housing)) = r.housing
  AND LOWER(TRIM(b.loan)) = r.loan
WHERE b.default IS NULL
  AND r.rn = 1;
  
-- Todos paracen No, cosa lógica teniendo en cuenta que solo hay un 1,5% de YES y son 15 registros
-- Imputamos los 14 NO

WITH DefaultMode AS (
    SELECT LOWER(TRIM(job)) AS job, 
           LOWER(TRIM(marital)) AS marital, 
           LOWER(TRIM(housing)) AS housing, 
           LOWER(TRIM(loan)) AS loan, 
           `default`,
           COUNT(`default`) AS count_default
    FROM BANK_marketing211024
    WHERE `default` IS NOT NULL
    GROUP BY LOWER(TRIM(job)), LOWER(TRIM(marital)), LOWER(TRIM(housing)), LOWER(TRIM(loan)), `default`
),
RankedDefault AS (
    SELECT job, marital, housing, loan, `default`,
           ROW_NUMBER() OVER (PARTITION BY job, marital, housing, loan ORDER BY count_default DESC) AS rn
    FROM DefaultMode
)
UPDATE BANK_marketing211024
SET `default`= (
    SELECT `default`
    FROM RankedDefault
    WHERE LOWER(TRIM(BANK_marketing211024.job)) = RankedDefault.job
      AND LOWER(TRIM(BANK_marketing211024.marital)) = RankedDefault.marital
      AND LOWER(TRIM(BANK_marketing211024.housing)) = RankedDefault.housing
      AND LOWER(TRIM(BANK_marketing211024.loan)) = RankedDefault.loan
      AND RankedDefault.rn = 1
)
WHERE `default` IS NULL;

-- REVISION DEL DATASET I CAMBIO DE TIPOS DE VARIABLES

-- Revisamos que no hayan espacios

SELECT id, job, marital, education
FROM BANK_marketing211024
WHERE job != TRIM(job)
   OR marital != TRIM(marital)
   OR education != TRIM(education)
   OR `default` != TRIM(`default`)
   OR housing != TRIM(housing)
   OR loan != TRIM(loan)
   OR contact != TRIM(contact)
   OR `month` != TRIM(`month`)
   OR poutcome != TRIM(poutcome)
   OR deposit != TRIM(deposit);
   
-- Queremos cambiar 4 columnas a booleans
SELECT DISTINCT `default`, housing, loan, deposit
FROM BANK_marketing211024;

-- Reemplazamos los valores a boolean
UPDATE BANK_marketing211024
SET `default` = CASE WHEN `default` = 'yes' THEN 1 ELSE 0 END,
    housing = CASE WHEN housing = 'yes' THEN 1 ELSE 0 END,
    loan = CASE WHEN loan = 'yes' THEN 1 ELSE 0 END,
    deposit = CASE WHEN deposit = 'yes' THEN 1 ELSE 0 END;
    
-- Reemplazamos el formato de las columnas
ALTER TABLE BANK_marketing211024
MODIFY COLUMN `default` TINYINT(1),
MODIFY COLUMN housing TINYINT(1),
MODIFY COLUMN loan TINYINT(1),
MODIFY COLUMN deposit TINYINT(1);

