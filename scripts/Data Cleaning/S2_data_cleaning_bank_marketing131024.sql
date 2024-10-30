SELECT *
FROM BANK_marketing131024;

-- Buscar duplicados
SELECT job, marital, education, `default`, balance, housing, loan, contact, `day`, `month`, duration, campaign, pdays, previous, poutcome, deposit, COUNT(*) AS count
FROM BANK_marketing131024
GROUP BY job, marital, education, `default`, balance, housing, loan, contact, `day`, `month`, duration, campaign, pdays, previous, poutcome, deposit
HAVING COUNT(*) > 1;

SELECT *
FROM BANK_marketing131024
WHERE balance = 2343;

-- Revisamos Nulos y valores en blanco
-- Por columna edad
SELECT *
FROM BANK_marketing131024
WHERE age IS NULL or age = "";

-- Por columna job

SELECT *
FROM BANK_marketing131024
WHERE job IS NULL or job = "";

-- Por columna marital

SELECT *
FROM BANK_marketing131024
WHERE marital IS NULL or marital = "";

-- Por columna education

SELECT *
FROM BANK_marketing131024
WHERE education IS NULL or education = "";

-- Por columna default
SELECT *
FROM BANK_marketing131024
WHERE `default` IS NULL or `default` = "";


-- Por columna default
SELECT *
FROM BANK_marketing131024
WHERE balance IS NULL or balance = "";

-- Por columna housing
SELECT *
FROM BANK_marketing131024
WHERE housing IS NULL or housing = "";

-- Por columna loan
SELECT *
FROM BANK_marketing131024
WHERE loan IS NULL or loan = "";

-- Por columna contact
SELECT *
FROM BANK_marketing131024
WHERE contact IS NULL or contact = "";

-- Por columna day
SELECT *
FROM BANK_marketing131024
WHERE `day` IS NULL or `day` = "";

-- Por columna month
SELECT *
FROM BANK_marketing131024
WHERE `month` IS NULL or `month` = "";

-- Por columna campaign
SELECT *
FROM BANK_marketing131024
WHERE campaign IS NULL or campaign = "";

-- Por columna pdays
SELECT *
FROM BANK_marketing131024
WHERE pdays IS NULL or pdays = "";

-- Por columna previous
SELECT *
FROM BANK_marketing131024
WHERE previous IS NULL or previous = "";

-- Por columna poutcome
SELECT *
FROM BANK_marketing131024
WHERE poutcome IS NULL or poutcome = "";

-- Por columna deposit
SELECT *
FROM BANK_marketing131024
WHERE deposit IS NULL or deposit = "";

-- Comprobación antes de borrar duplicados

WITH RankedDuplicates AS (
    SELECT id, age, job, marital, education, `default`, balance, housing, loan, contact, `day`, `month`, duration, campaign, pdays, previous, poutcome, deposit,
        ROW_NUMBER() OVER (PARTITION BY age, job, marital, education, `default`, balance, housing, loan, contact, `day`, `month`, duration, campaign, pdays, previous, poutcome, deposit ORDER BY id) AS row_num
    FROM BANK_marketing131024
)
SELECT *
FROM RankedDuplicates
WHERE row_num > 1;

-- Procedemos a borrar las filas duplicadas

WITH RankedDuplicates AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY age, job, marital, education, `default`, balance, housing, loan, contact, `day`, `month`, duration, campaign, pdays, previous, poutcome, deposit ORDER BY id) AS row_num
    FROM BANK_marketing131024
)
DELETE FROM BANK_marketing131024
WHERE id IN (
    SELECT id
    FROM RankedDuplicates
    WHERE row_num > 1
);

-- Ahora necesitamos insertar nuevos datos en la columna Age
SELECT *
FROM BANK_marketing131024
WHERE age IS NULL or age = "";

--
WITH OrderedAges AS (
    SELECT job, marital, age, 
           ROW_NUMBER() OVER (PARTITION BY job, marital ORDER BY age) AS row_num,
           COUNT(*) OVER (PARTITION BY job, marital) AS total_count
    FROM BANK_marketing131024
    WHERE age IS NOT NULL
)
SELECT job, marital, 
       FLOOR(AVG(age)) AS median_age -- Truncar hacia abajo para un entero
FROM OrderedAges
WHERE row_num IN (FLOOR((total_count + 1) / 2), CEILING((total_count + 1) / 2))
GROUP BY job, marital;


-- Ahora que tenemos la media de cada uno, veamos primero como quedaría el resultado
WITH MedianAges AS (
    SELECT job, marital, 
           FLOOR(AVG(age)) AS median_age -- Truncate to integer
    FROM (
        SELECT job, marital, age, 
               ROW_NUMBER() OVER (PARTITION BY job, marital ORDER BY age) AS row_num,
               COUNT(*) OVER (PARTITION BY job, marital) AS total_count
        FROM BANK_marketing131024
        WHERE age IS NOT NULL
    ) OrderedAges
    WHERE row_num IN (FLOOR((total_count + 1) / 2), CEILING((total_count + 1) / 2))
    GROUP BY job, marital
)
SELECT bm.id, bm.job, bm.marital, bm.age, ma.median_age
FROM BANK_marketing131024 bm
LEFT JOIN MedianAges ma
ON bm.job = ma.job AND bm.marital = ma.marital
WHERE bm.age IS NULL;

-- Procedemos a actualizarla, 10 rows affected!
WITH MedianAges AS (
    SELECT job, marital, 
           FLOOR(AVG(age)) AS median_age -- Truncate to integer
    FROM (
        SELECT job, marital, age, 
               ROW_NUMBER() OVER (PARTITION BY job, marital ORDER BY age) AS row_num,
               COUNT(*) OVER (PARTITION BY job, marital) AS total_count
        FROM BANK_marketing131024
        WHERE age IS NOT NULL
    ) OrderedAges
    WHERE row_num IN (FLOOR((total_count + 1) / 2), CEILING((total_count + 1) / 2))
    GROUP BY job, marital
)
UPDATE BANK_marketing131024 bm
SET age = (
    SELECT ma.median_age
    FROM MedianAges ma
    WHERE bm.job = ma.job AND bm.marital = ma.marital
)
WHERE bm.age IS NULL;

SELECT age, count(*)
FROM BANK_marketing
group by age;

-- Obtenemos la moda de marital de cada trabajo

WITH marital_mode AS (
    SELECT job, 
           marital, 
           ROW_NUMBER() OVER (PARTITION BY job ORDER BY COUNT(*) DESC) AS rank_marital
    FROM BANK_marketing131024
    WHERE marital IS NOT NULL
    GROUP BY job, marital
)
SELECT job, marital
FROM marital_mode
WHERE rank_marital = 1;

-- Obtenemos la media de edad por departamento
SELECT job, AVG(age) AS avg_age
FROM BANK_marketing131024
GROUP BY job;

-- Revisamos los nulls que teniamos que cambiar
SELECT *
FROM BANK_marketing131024
WHERE marital IS NULL or marital = "";

-- Antes de editar la base de datos comprobamos el resultado

WITH marital_mode AS (
    SELECT job, 
           marital, 
           ROW_NUMBER() OVER (PARTITION BY job ORDER BY COUNT(*) DESC) AS rank_marital
    FROM BANK_marketing131024
    WHERE marital IS NOT NULL
    GROUP BY job, marital
)
SELECT bm.id, bm.age, bm.job, bm.marital AS current_marital, mm.marital AS new_marital
FROM BANK_marketing131024 bm
LEFT JOIN marital_mode mm
    ON bm.job = mm.job
    AND mm.rank_marital = 1
WHERE bm.marital IS NULL;

-- Procedemos a realizar el cambio, efectivamente solo se han cambiado las 5 columnas que buscabamos
WITH marital_mode AS (
    SELECT job, 
           marital, 
           ROW_NUMBER() OVER (PARTITION BY job ORDER BY COUNT(*) DESC) AS rank_marital
    FROM BANK_marketing131024
    WHERE marital IS NOT NULL
    GROUP BY job, marital
)
UPDATE BANK_marketing131024 bm
SET bm.marital = (
    SELECT mm.marital 
    FROM marital_mode mm
    WHERE bm.job = mm.job 
      AND mm.rank_marital = 1
)
WHERE bm.marital IS NULL;

SELECT marital, count(*)
FROM BANK_marketing131024
GROUP BY marital;

-- Revisamos los nulls que teniamos que cambiar en la columna EDUCATION
SELECT *
FROM BANK_marketing131024
WHERE education IS NULL or education = "";

-- Ahora vamos a modificar la columna education
SELECT education, COUNT(*)
FROM BANK_marketing131024
GROUP BY education;

SELECT *
FROM BANK_marketing131024
WHERE education IS NULL or education = "";

WITH AverageAges AS (
    SELECT job, marital, 
           ROUND(AVG(age), 0) AS avg_age -- Redondear la media de edad a un entero
    FROM BANK_marketing131024
    WHERE age IS NOT NULL
    GROUP BY job, marital
)
SELECT bm.id, bm.job, bm.marital, bm.education, aa.avg_age
FROM BANK_marketing131024 bm
LEFT JOIN AverageAges aa
ON bm.job = aa.job AND bm.marital = aa.marital
WHERE bm.education IS NULL;

-- Procedemos a ver el resultado

WITH ModeEducation AS (
    SELECT job, marital, education,
           COUNT(*) AS freq
    FROM BANK_marketing131024
    WHERE education IS NOT NULL
    GROUP BY job, marital, education
),
RankedEducation AS (
    SELECT job, marital, education,
           ROW_NUMBER() OVER (PARTITION BY job, marital ORDER BY freq DESC) AS ranked_row
    FROM ModeEducation
)
SELECT bm.id, bm.job, bm.marital, bm.education AS original_education, re.education AS new_education
FROM BANK_marketing131024 bm
LEFT JOIN (
    SELECT job, marital, education
    FROM RankedEducation
    WHERE ranked_row = 1
) re
ON bm.job = re.job
AND bm.marital = re.marital
WHERE bm.education IS NULL;

-- Procedemos a actualizar la columna education correctamente, 7 rows affected!

WITH ModeEducation AS (
    SELECT job, marital, education,
           COUNT(*) AS freq
    FROM BANK_marketing131024
    WHERE education IS NOT NULL
    GROUP BY job, marital, education
),
RankedEducation AS (
    SELECT job, marital, education,
           ROW_NUMBER() OVER (PARTITION BY job, marital ORDER BY freq DESC) AS ranked_row
    FROM ModeEducation
)
UPDATE BANK_marketing131024 bm
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

-- Revisamos la columna Housing
SELECT *
FROm BANK_marketing131024
WHERE  housing IS NULL or housing = "";

-- Identificamos la moda en cada grupo
SELECT housing, COUNT(*)
FROM BANK_marketing131024
GROUP BY housing;

SELECT age, job, education, marital, COUNT(*)
FROM BANK_marketing131024
GROUP BY age, job, education, marital
HAVING COUNT(*) > 1;

WITH HousingMode AS (
    SELECT LOWER(TRIM(age)) AS age, LOWER(TRIM(job)) AS job, LOWER(TRIM(education)) AS education, LOWER(TRIM(marital)) AS marital, housing,
           COUNT(housing) AS count_housing
    FROM BANK_marketing131024
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
    FROM BANK_marketing131024
    WHERE housing IS NOT NULL
    GROUP BY LOWER(TRIM(age)), LOWER(TRIM(job)), LOWER(TRIM(education)), LOWER(TRIM(marital)), housing
),
RankedHousing AS (
    SELECT age, job, education, marital, housing,
           ROW_NUMBER() OVER (PARTITION BY age, job, education, marital ORDER BY count_housing DESC) AS rn
    FROM HousingMode
)
UPDATE BANK_marketing131024
SET housing = (
    SELECT housing
    FROM RankedHousing
    WHERE LOWER(TRIM(BANK_marketing131024.age)) = RankedHousing.age
      AND LOWER(TRIM(BANK_marketing131024.job)) = RankedHousing.job
      AND LOWER(TRIM(BANK_marketing131024.education)) = RankedHousing.education
      AND LOWER(TRIM(BANK_marketing131024.marital)) = RankedHousing.marital
      AND RankedHousing.rn = 1
)
WHERE housing IS NULL;



SELECT *
FROM BANK_marketing131024;



-- Revisamos que no hayan espacios

SELECT id, job, marital, education
FROM BANK_marketing131024
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
FROM BANK_marketing131024;

-- Reemplazamos los valores a boolean
UPDATE BANK_marketing131024
SET `default` = CASE WHEN `default` = 'yes' THEN 1 ELSE 0 END,
    housing = CASE WHEN housing = 'yes' THEN 1 ELSE 0 END,
    loan = CASE WHEN loan = 'yes' THEN 1 ELSE 0 END,
    deposit = CASE WHEN deposit = 'yes' THEN 1 ELSE 0 END;
    
-- Reemplazamos el formato de las columnas
ALTER TABLE BANK_marketing131024
MODIFY COLUMN `default` TINYINT(1),
MODIFY COLUMN housing TINYINT(1),
MODIFY COLUMN loan TINYINT(1),
MODIFY COLUMN deposit TINYINT(1);




