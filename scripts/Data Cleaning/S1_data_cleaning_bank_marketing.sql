-- Procedemos a borrar el duplicado
WITH RankedDuplicates AS (
SELECT id, age, job, marital, education, `default`, balance, housing, loan, contact, `day`, `month`, duration, campaign, pdays, previous, poutcome, deposit,
	ROW_NUMBER() OVER (PARTITION BY age, job, marital, education, `default`, balance, housing, loan, contact, `day`, `month`, duration, campaign, pdays, previous, poutcome, deposit ORDER BY id) AS row_num
FROM 
    BANK_marketing
)
SELECT id
FROM RankedDuplicates
WHERE row_num > 1;

-- Obtenemos la moda de marital de cada trabajo

WITH marital_mode AS (
    SELECT job, 
           marital, 
           ROW_NUMBER() OVER (PARTITION BY job ORDER BY COUNT(*) DESC) AS rank_marital
    FROM BANK_marketing
    WHERE marital IS NOT NULL
    GROUP BY job, marital
)
SELECT job, marital
FROM marital_mode
WHERE rank_marital = 1;

-- Obtenemos la media de edad por departamento
SELECT job, AVG(age) AS avg_age
FROM BANK_marketing
GROUP BY job;

-- Revisamos los nulls que teniamos que cambiar
SELECT *
FROM BANK_marketing
WHERE marital IS NULL or marital = "";

-- Antes de editar la base de datos comprobamos el resultado

WITH marital_mode AS (
    SELECT job, 
           marital, 
           ROW_NUMBER() OVER (PARTITION BY job ORDER BY COUNT(*) DESC) AS rank_marital
    FROM BANK_marketing
    WHERE marital IS NOT NULL
    GROUP BY job, marital
)
SELECT bm.id, bm.age, bm.job, bm.marital AS current_marital, mm.marital AS new_marital
FROM BANK_marketing bm
LEFT JOIN marital_mode mm
    ON bm.job = mm.job
    AND mm.rank_marital = 1
WHERE bm.marital IS NULL;

-- Procedemos a realizar el cambio, efectivamente solo se han cambiado las 5 columnas que buscabamos
WITH marital_mode AS (
    SELECT job, 
           marital, 
           ROW_NUMBER() OVER (PARTITION BY job ORDER BY COUNT(*) DESC) AS rank_marital
    FROM BANK_marketing
    WHERE marital IS NOT NULL
    GROUP BY job, marital
)
UPDATE BANK_marketing bm
SET bm.marital = (
    SELECT mm.marital 
    FROM marital_mode mm
    WHERE bm.job = mm.job 
      AND mm.rank_marital = 1
)
WHERE bm.marital IS NULL;

SELECT marital, count(*)
FROM BANK_marketing
GROUP BY marital;


-- Ahora necesitamos insertar nuevos datos en la columna Age
SELECT *
FROM BANK_marketing
WHERE age IS NULL or age = "";

--
WITH OrderedAges AS (
    SELECT job, marital, age, 
           ROW_NUMBER() OVER (PARTITION BY job, marital ORDER BY age) AS row_num,
           COUNT(*) OVER (PARTITION BY job, marital) AS total_count
    FROM BANK_marketing
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
        FROM BANK_marketing
        WHERE age IS NOT NULL
    ) OrderedAges
    WHERE row_num IN (FLOOR((total_count + 1) / 2), CEILING((total_count + 1) / 2))
    GROUP BY job, marital
)
SELECT bm.id, bm.job, bm.marital, bm.age, ma.median_age
FROM BANK_marketing bm
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
        FROM BANK_marketing
        WHERE age IS NOT NULL
    ) OrderedAges
    WHERE row_num IN (FLOOR((total_count + 1) / 2), CEILING((total_count + 1) / 2))
    GROUP BY job, marital
)
UPDATE BANK_marketing bm
SET age = (
    SELECT ma.median_age
    FROM MedianAges ma
    WHERE bm.job = ma.job AND bm.marital = ma.marital
)
WHERE bm.age IS NULL;

SELECT age, count(*)
FROM BANK_marketing
group by age;

-- Ahora vamos a modificar la columna education
SELECT education, COUNT(*)
FROM BANK_marketing
GROUP BY education;

SELECT *
FROM BANK_marketing
WHERE education IS NULL or education = "";

WITH AverageAges AS (
    SELECT job, marital, 
           ROUND(AVG(age), 0) AS avg_age -- Redondear la media de edad a un entero
    FROM BANK_marketing
    WHERE age IS NOT NULL
    GROUP BY job, marital
)
SELECT bm.id, bm.job, bm.marital, bm.education, aa.avg_age
FROM BANK_marketing bm
LEFT JOIN AverageAges aa
ON bm.job = aa.job AND bm.marital = aa.marital
WHERE bm.education IS NULL;

-- Procedemos a ver el resultado

WITH ModeEducation AS (
    SELECT job, marital, education,
           COUNT(*) AS freq
    FROM BANK_marketing
    WHERE education IS NOT NULL
    GROUP BY job, marital, education
),
RankedEducation AS (
    SELECT job, marital, education,
           ROW_NUMBER() OVER (PARTITION BY job, marital ORDER BY freq DESC) AS ranked_row
    FROM ModeEducation
)
SELECT bm.id, bm.job, bm.marital, bm.education AS original_education, re.education AS new_education
FROM BANK_marketing bm
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
    FROM BANK_marketing
    WHERE education IS NOT NULL
    GROUP BY job, marital, education
),
RankedEducation AS (
    SELECT job, marital, education,
           ROW_NUMBER() OVER (PARTITION BY job, marital ORDER BY freq DESC) AS ranked_row
    FROM ModeEducation
)
UPDATE BANK_marketing bm
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


-- Revisamos que no hayan espacios
SELECT *
FROM BANK_marketing;

SELECT id, job, marital, education
FROM BANK_marketing
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
FROM BANK_marketing;

-- Reemplazamos los valores a boolean
UPDATE BANK_marketing
SET `default` = CASE WHEN `default` = 'yes' THEN 1 ELSE 0 END,
    housing = CASE WHEN housing = 'yes' THEN 1 ELSE 0 END,
    loan = CASE WHEN loan = 'yes' THEN 1 ELSE 0 END,
    deposit = CASE WHEN deposit = 'yes' THEN 1 ELSE 0 END;
    
-- Reemplazamos el formato de las columnas
ALTER TABLE BANK_marketing
MODIFY COLUMN `default` TINYINT(1),
MODIFY COLUMN housing TINYINT(1),
MODIFY COLUMN loan TINYINT(1),
MODIFY COLUMN deposit TINYINT(1);

    
    SELECT *
    FROM BANK_marketing

















