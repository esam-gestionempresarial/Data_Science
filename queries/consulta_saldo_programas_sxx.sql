SELECT
    pu.codigo AS cod_academico,
    CASE cu.id
        WHEN 1 THEN 'DIPLOMADO'
        WHEN 2 THEN 'ESPECIALIDAD'
        WHEN 3 THEN 'MAESTRÍA'
        ELSE 'OTRO'
    END AS tipo_programa,
    -- Tarifa esperada según tipo
    51 AS tarifa_actual_inscripcion,
    CASE cu.id
        WHEN 1 THEN 150
        WHEN 2 THEN 200
        WHEN 3 THEN 300
        ELSE 0
    END AS tarifa_actual_matricula,
    -- ── INSCRITOS ──────────────────────────────────────────
    COUNT(DISTINCT base.ipu_id) AS total_inscritos,
    -- ── INSCRIPCIÓN ────────────────────────────────────────
    COUNT(DISTINCT CASE WHEN ins_pagado > 0 THEN base.ipu_id END) AS ins_cant_pagaron,
    COUNT(DISTINCT CASE WHEN ins_pagado = 0 THEN base.ipu_id END) AS ins_cant_por_pagar,
    SUM(ins_pagado) AS ins_monto_pagado,
    COUNT(DISTINCT CASE WHEN ins_pagado = 0 THEN base.ipu_id END) * 51 AS ins_monto_por_pagar,
    -- ── MATRÍCULA ──────────────────────────────────────────
    COUNT(DISTINCT CASE WHEN mat_pagado > 0 THEN base.ipu_id END) AS mat_cant_pagaron,
    COUNT(DISTINCT CASE WHEN mat_pagado = 0 THEN base.ipu_id END) AS mat_cant_por_pagar,
    SUM(mat_pagado) AS mat_monto_pagado,
    COUNT(DISTINCT CASE WHEN mat_pagado = 0 THEN base.ipu_id END) * CASE cu.id WHEN 1 THEN 150 WHEN 2 THEN 200 WHEN 3 THEN 300 ELSE 0 END AS mat_monto_por_pagar,
    -- ── TOTALES GENERALES ──────────────────────────────────
    SUM(ins_pagado) + SUM(mat_pagado) AS 'total_pagado(ins+mat)',
    (COUNT(DISTINCT CASE WHEN ins_pagado = 0 THEN base.ipu_id END) * 51) + (COUNT(DISTINCT CASE WHEN mat_pagado = 0 THEN base.ipu_id END) * CASE cu.id WHEN 1 THEN 150 WHEN 2 THEN 200 WHEN 3 THEN 300 ELSE 0 END) AS 'total_por_pagar(ins+mat)'
FROM (
    -- Subquery: kardex ya resuelto, uno por inscrito
    SELECT
        ipu.id AS ipu_id,
        ipu.programa_universidad_id,
        SUM(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 1 THEN ppue.monto_total ELSE 0 END) AS ins_pagado,
        SUM(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 2 THEN ppue.monto_total ELSE 0 END) AS mat_pagado
    FROM inscripcion_programa_universidad ipu
    INNER JOIN plan_pagos_universidad_estudiantes ppue ON ppue.inscripcion_programa_universidad_id = ipu.id
    INNER JOIN pagos_universidad_estudiantes pue ON pue.plan_pagos_universidad_estudiantes_id = ppue.id
    INNER JOIN plan_pagos_concepto_universidad ppcu ON ppcu.id = ppue.plan_pagos_concepto_universidad_id
    GROUP BY ipu.id, ipu.programa_universidad_id
) base
INNER JOIN programa_universidad pu  ON pu.id  = base.programa_universidad_id
INNER JOIN sede_universidad su ON su.id  = pu.sede_universidad_id
INNER JOIN categorias_universidades cu ON cu.id  = pu.categoria_universidad_id
WHERE su.universidad_id = 9
GROUP BY pu.codigo, cu.id
ORDER BY pu.codigo