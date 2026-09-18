/* ══════════════════════════════════════════════════════════════════════════
   REPORTE UAP — CARTERA DE PARTICIPANTES
   Versión: 2.0  |  Refactorización: CTEs + reorganización de columnas
   ══════════════════════════════════════════════════════════════════════════
   ESTRUCTURA:
     CTE 1 · cte_plan_actualizado  → cuotas con descuentos desagregados
     CTE 2 · cte_pcpes             → montos del plan de cobros por concepto
     CTE 3 · cte_kardex            → kardex consolidado por cuota
     CTE 4 · cte_promociones       → detalle de promociones
     CTE 5 · cte_historial_estado  → última fecha de cambio de estado académico por inscripción
   ══════════════════════════════════════════════════════════════════════════ */
WITH
/* ────────────────────────────────────────────────────────────────────────
   CTE 1 · Plan de pagos con descuentos desagregados por tipo de motivo
   ──────────────────────────────────────────────────────────────────────── */
cte_plan_actualizado AS (
    SELECT
        pp.id,
        pp.nro_cuota,
        pp.fecha_pago,
        pp.concepto_pago_id,
        pp.inscripcion_id,
        pp.monto,
        i.estado_ins,
        pcp.id   AS plan_pago_id,
        pcp.nombre AS plan_pago,
        p.fecha_fin,
        SUM(IF(m.tipo_descuento_id = 1, ppd.monto, 0)) AS monto_regularizado,
        SUM(IF(m.tipo_descuento_id = 2, ppd.monto, 0)) AS monto_descuento,
        SUM(IF(m.tipo_descuento_id = 3, ppd.monto, 0)) AS monto_liquidado,
        SUM(IF(m.tipo_descuento_id = 4, ppd.monto, 0)) AS monto_compensacion,
        SUM(IFNULL(ppd.monto, 0)) AS descuento_total
    FROM plan_pagos pp
    JOIN  inscripciones i ON i.id = pp.inscripcion_id
    JOIN  plan_cobros_programa pcp ON pcp.id = i.plan_cobro_programa_id
    JOIN  programas p ON p.id = i.idprograma
    LEFT JOIN plan_pago_descuento ppd ON ppd.plan_pago_id = pp.id AND ppd.fecha_registro < CURRENT_DATE
    LEFT JOIN descuentos d ON d.id = ppd.descuento_id
    LEFT JOIN motivos m ON m.id = d.motivo_id
    WHERE pp.nro_cuota >= 1
    GROUP BY
        pp.id, pp.nro_cuota, pp.fecha_pago,
        pp.concepto_pago_id, pp.inscripcion_id,
        pp.monto, i.estado_ins,
        pcp.id, pcp.nombre, p.fecha_fin
),
/* ────────────────────────────────────────────────────────────────────────
   CTE 2 · Montos del plan de cobros agrupados por concepto
   ──────────────────────────────────────────────────────────────────────── */
cte_pcpes AS (
    SELECT
        pcp.id,
        SUM(IF(cp.concepto_pago_id = 1, cp.monto, 0)) AS pc_monto_matricula,
        SUM(IF(cp.concepto_pago_id = 2, cp.monto, 0)) AS pc_monto_colegiatura,
        SUM(IF(cp.concepto_pago_id = 3, cp.monto, 0)) AS pc_monto_titulacion
    FROM plan_cobros_programa pcp
    JOIN cobros_programa cp ON cp.plan_cobro_programa_id = pcp.id
    GROUP BY pcp.id
),
/* ────────────────────────────────────────────────────────────────────────
   CTE 3 · Kardex consolidado por cuota
   ──────────────────────────────────────────────────────────────────────── */
cte_kardex AS (
    SELECT
        pa.id,
        pa.nro_cuota,
        pa.fecha_pago AS fecha_limite_pago,
        pa.concepto_pago_id,
        pa.inscripcion_id,
        pa.plan_pago,
        pa.monto,
        pa.monto_descuento,
        pa.monto_regularizado,
        pa.monto_compensacion,
        pa.monto_liquidado,
        pc.pc_monto_matricula,
        pc.pc_monto_colegiatura,
        pc.pc_monto_titulacion,
        /* Pagos efectivos de la cuota */
        SUM(IFNULL(dpi.monto, 0)) AS pagado,
        /* Saldo = monto – descuento – pagado */
        (pa.monto - pa.descuento_total - SUM(IFNULL(dpi.monto, 0))) AS saldo,
        /* Flags de plan */
        IF(UPPER(pa.plan_pago) LIKE '%CONTADO%', 1, 0) AS es_contado,
        /* Total formativo: pagos + regularizado + compensación (solo conceptos 1 y 2) */
        CASE WHEN pa.concepto_pago_id IN (1, 2)
             THEN IFNULL(SUM(IFNULL(dpi.monto, 0)), 0)
                  + IFNULL(pa.monto_regularizado, 0)
                  + IFNULL(pa.monto_compensacion, 0)
             ELSE 0
        END AS total_formativo_cuota,
        /* Cuota vencida: saldo > 0, concepto formativo, fecha límite en mes anterior */
        CASE WHEN (pa.monto - pa.descuento_total - SUM(IFNULL(dpi.monto, 0))) > 0
                  AND pa.fecha_pago < LAST_DAY(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
                  AND pa.concepto_pago_id IN (1, 2)
             THEN 1 ELSE 0
        END AS es_cuota_vencida,
        /* Cuota con saldo (independiente de fecha) */
        CASE WHEN (pa.monto - pa.descuento_total - SUM(IFNULL(dpi.monto, 0))) > 0
                  AND pa.concepto_pago_id IN (1, 2)
             THEN 1 ELSE 0
        END AS es_cuota_con_saldo,
        MAX(dpi.fecha_registro_pago) AS fecha_pago_max,
        MAX(dpi.id) AS id_dpi_max,
        /* Última fecha de pago por concepto (para columnas individuales en query principal) */
        MAX(CASE WHEN pa.concepto_pago_id = 1 THEN dpi.fecha_registro_pago END) AS fecha_ultimo_pago_matricula,
        MAX(CASE WHEN pa.concepto_pago_id = 2 THEN dpi.fecha_registro_pago END) AS fecha_ultimo_pago_colegiatura,
		MAX(CASE WHEN pa.concepto_pago_id = 3 THEN dpi.fecha_registro_pago END) AS fecha_ultimo_pago_titulacion,
        /* Última fecha de pago por concepto (para columnas individuales en query principal) */
        MIN(CASE WHEN pa.concepto_pago_id = 1 THEN dpi.fecha_registro_pago END) AS fecha_primer_pago_matricula,
        MIN(CASE WHEN pa.concepto_pago_id = 2 THEN dpi.fecha_registro_pago END) AS fecha_primer_pago_colegiatura,
        MIN(CASE WHEN pa.concepto_pago_id = 3 THEN dpi.fecha_registro_pago END) AS fecha_primer_pago_titulacion    
	FROM cte_plan_actualizado pa
    JOIN cte_pcpes pc ON pc.id = pa.plan_pago_id
    LEFT JOIN detalle_pagos_inscripcion dpi ON dpi.cuota_id = pa.id AND dpi.estado = 1
    GROUP BY pa.id
),
/* ────────────────────────────────────────────────────────────────────────
   CTE 4 · Promociones con detalle por concepto
   ──────────────────────────────────────────────────────────────────────── */
cte_promociones AS (
    SELECT
        p4.id,
        p4.nombre,
        p4.descripcion,
        MAX(IF(dp.concepto_id = 1, dp.isporcentaje, NULL)) AS mat_isporcent,
        MAX(IF(dp.concepto_id = 1, dp.valor_descuento, NULL)) AS mat_valor,
        MAX(IF(dp.concepto_id = 2, dp.isporcentaje, NULL)) AS col_isporcent,
        MAX(IF(dp.concepto_id = 2, dp.valor_descuento, NULL)) AS col_valor
    FROM promociones p4
    JOIN detalle_promociones dp ON dp.promocion_id = p4.id
    GROUP BY p4.id, p4.nombre, p4.descripcion
),
/* ────────────────────────────────────────────────────────────────────────
   CTE 5 · Última fecha de cambio de estado académico por inscripción
   Corrección: GROUP BY para evitar multiplicación de filas en el JOIN principal
   ──────────────────────────────────────────────────────────────────────── */
cte_historial_estado AS (
    SELECT
        inscripcion_id,
        MAX(fecha_cambio) AS fecha_cambio
    FROM historial_estados_academicos
    GROUP BY inscripcion_id
)
/* ══════════════════════════════════════════════════════════════════════════
   QUERY PRINCIPAL
   Orden de columnas:
     § 1 · Datos del Programa
     § 2 · Datos del Participante
     § 3 · Kardex / Historial de Pagos
     § 4 · Estados
   ══════════════════════════════════════════════════════════════════════════ */
SELECT
    /* ── § 1 · DATOS DEL PROGRAMA ─────────────────────────────────────── */
    IFNULL(pu.codigo, 'sin definir') AS Cod_Academico,
    CASE
        WHEN c.nombre = 'Diplomado'    THEN CONCAT_WS('-', 'D', p.id)
        WHEN c.nombre = 'Especialidad' THEN CONCAT_WS('-', 'E', p.id)
        WHEN c.nombre = 'Maestría'     THEN CONCAT_WS('-', 'M', p.id)
    END AS Id_Portal,
    IFNULL(p.codigo, 'sin definir') AS Cod_Contable,
    p.nombre_compuesto AS Programa,
    p.gestion AS Gestion,
    c.nombre AS Tipo,
    s.nombre AS Sede,
    i2.abreviatura AS Convenio,
    /* ── § 2 · DATOS DEL PARTICIPANTE ────────────────────────────────── */
    i.id AS Id_Inscripcion,
    CONCAT_WS(' ', p3.pri_apellido, p3.seg_apellido, p3.nombres) AS Alumno,
    p3.num_doc AS CI,
    IF(i.es_regularizado = 1, 'REGULARIZADO', 'NORMAL') AS Es_Regularizado,
    /* ── § 3 · KARDEX / HISTORIAL DE PAGOS ───────────────────────────── */
    IFNULL(kardex.plan_pago, '-') AS Plan_Pago,
    IF(MAX(kardex.es_contado) = 1, 'Contado', 'Crédito') AS Tipo_Plan_Pago,
    IFNULL(kardex.pc_monto_matricula, 0) AS PC_Monto_Matricula,
    IFNULL(kardex.pc_monto_colegiatura, 0) AS pc_monto_colegiatura,
    IFNULL(kardex.pc_monto_titulacion, 0) AS PC_Monto_Titulacion,
    IFNULL(prom.descripcion, '-') AS Desc_Promocion,
    /* Matrícula */
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 1 THEN kardex.pagado ELSE 0 END), 0) AS Pago_Matricula,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 1 AND kardex.monto_descuento != 0 THEN kardex.monto_descuento ELSE 0 END), 0) AS Descuento_Matricula,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 1 AND kardex.monto_regularizado != 0 THEN kardex.monto_regularizado ELSE 0 END), 0) AS Regularizado_Matricula,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 1 AND kardex.monto_compensacion != 0 THEN kardex.monto_compensacion ELSE 0 END), 0) AS Compensacion_Matricula,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 1 AND kardex.monto_liquidado != 0 THEN kardex.monto_liquidado ELSE 0 END), 0) AS Liquidado_Matricula,
    DATE(IFNULL(MAX(kardex.fecha_primer_pago_matricula), '1900-01-01')) AS Fecha_Primer_Pago_Matricula,
    /* Colegiatura */
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 2 THEN kardex.pagado ELSE 0 END), 0) AS Pago_Colegiatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 2 AND kardex.monto_descuento != 0 THEN kardex.monto_descuento ELSE 0 END), 0) AS Descuento_Colegiatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 2 AND kardex.monto_regularizado != 0 THEN kardex.monto_regularizado ELSE 0 END), 0) AS Regularizado_Colegiatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 2 AND kardex.monto_compensacion != 0 THEN kardex.monto_compensacion ELSE 0 END), 0) AS Compensacion_Colegiatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 2 AND kardex.monto_liquidado != 0 THEN kardex.monto_liquidado ELSE 0 END), 0) AS Liquidado_Colegiatura,
    DATE(IFNULL(MAX(kardex.fecha_primer_pago_colegiatura), '1900-01-01')) AS Fecha_Primer_Pago_Colegiatura,
    /* Certificación / Titulación */
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 3 THEN kardex.pagado ELSE 0 END), 0) AS Pago_Certificacion,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 3 AND kardex.monto_descuento != 0 THEN kardex.monto_descuento    ELSE 0 END), 0) AS Descuento_Certificacion,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 3 AND kardex.monto_regularizado != 0 THEN kardex.monto_regularizado ELSE 0 END), 0) AS Regularizacion_Certificacion,
    DATE(IFNULL(MAX(kardex.fecha_ultimo_pago_titulacion), '1900-01-01')) AS Fecha_Ultimo_Pago_Titulacion,
    /* Totales y saldos */
    IFNULL(SUM(kardex.total_formativo_cuota), 0) AS Monto_Pagado_Fase_Formativa,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 3
                    THEN IFNULL(kardex.pagado, 0) + IFNULL(kardex.monto_regularizado, 0)
                    ELSE 0 END), 0) AS Monto_Pagado_Certificacion,
    IFNULL(SUM(CASE WHEN kardex.saldo > 0 THEN
                    CASE
                        WHEN kardex.es_contado = 1 AND kardex.concepto_pago_id  = 2 THEN kardex.saldo
                        WHEN kardex.es_contado = 0 AND kardex.concepto_pago_id IN (1,2) THEN kardex.saldo
                        ELSE 0
                    END ELSE 0 END), 0) AS Saldo_Pendiente_Fase_Formativa,
    IFNULL(SUM(CASE WHEN kardex.saldo > 0 AND kardex.concepto_pago_id = 3
                    THEN kardex.saldo ELSE 0 END), 0) AS Saldo_Pendiente_Titulacion,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id IN (1,2)
                    THEN IFNULL(kardex.pagado, 0) ELSE 0 END), 0) AS Monto_MatCol_Ingresado,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id IN (1,2)
                    THEN IFNULL(kardex.monto_liquidado, 0) ELSE 0 END), 0) AS Monto_Total_Liquidado,
    DATE(IFNULL(MAX(kardex.fecha_pago_max), '1900-01-01')) AS Fecha_Ultimo_Pago,
    IFNULL(MAX(det_pag.id), '-') AS Id_Detalle_Pago,
    IFNULL(CASE
        WHEN MAX(det_pag.concepto_pago_id) = 1 THEN 'Matricula'
        WHEN MAX(det_pag.concepto_pago_id) = 2 THEN 'Colegiatura'
        WHEN MAX(det_pag.concepto_pago_id) = 3 THEN 'Titulacion'
    END, 'sin definir') AS Concepto_Ultimo_Pago,
    /* ── § 4 · ESTADOS ───────────────────────────────────────────────── */
    /* Estados desde el portal (valores registrados en BD) */
    IFNULL(ei.nombre, 'sin definir') AS Estado_Ins_Portal,
    IFNULL(ea3.nombre, 'sin definir') AS Estado_Admin_Portal,
    IFNULL(ea.nombre, 'sin definir') AS Estado_Acad_Portal,
    DATE(IFNULL(hea.fecha_cambio, '1900-01-01')) AS Fecha_Cambio_Estado,
    /* Estado Cartera Sistema: 7 niveles */
    CASE
        WHEN IFNULL(SUM(IFNULL(kardex.pagado, 0) + IFNULL(kardex.monto_liquidado, 0) + IFNULL(kardex.monto_regularizado, 0) + IFNULL(kardex.monto_compensacion, 0)), 0) = 0 THEN 'Sin cartera asignada'
        WHEN COUNT(CASE WHEN kardex.saldo > 0 AND kardex.concepto_pago_id IN (1, 2) THEN 1 END) = 0 AND i.estado_ins != 2 AND i.estado_ins != 3 THEN 'Exento de deuda'
        WHEN COUNT(CASE WHEN kardex.saldo > 0 AND kardex.concepto_pago_id IN (1, 2) THEN 1 END) = 0 AND i.estado_ins = 2 THEN 'Liquidado'
        WHEN COUNT(CASE WHEN kardex.saldo > 0 AND kardex.concepto_pago_id IN (1, 2) THEN 1 END) = 0 AND i.estado_ins = 3 THEN 'Liquidado'
        WHEN COUNT(CASE WHEN kardex.saldo > 0
                              AND kardex.fecha_limite_pago < LAST_DAY(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
                              AND kardex.concepto_pago_id IN (1, 2) THEN 1 END) = 0 THEN 'Vigente'
        WHEN COUNT(CASE WHEN kardex.saldo > 0
                              AND kardex.fecha_limite_pago < LAST_DAY(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
                              AND kardex.concepto_pago_id IN (1, 2) THEN 1 END) BETWEEN 1 AND 2 THEN 'Retrasado'
        WHEN COUNT(CASE WHEN kardex.saldo > 0
                              AND kardex.fecha_limite_pago < LAST_DAY(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
                              AND kardex.concepto_pago_id IN (1, 2) THEN 1 END) >= 3
                              OR p.fecha_fin <= CURDATE() THEN 'Riesgo de incobrabilidad'
        WHEN COUNT(CASE WHEN kardex.saldo > 0
                              AND kardex.fecha_limite_pago < LAST_DAY(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
                              AND kardex.concepto_pago_id IN (1, 2) THEN 1 END) >= 3 THEN 'En mora'
        ELSE 'Sin clasificar'
    END AS Estado_Cartera_Portal
FROM inscripciones i
INNER JOIN programas p ON p.id = i.idprograma
INNER JOIN postgrados p2 ON p2.id = p.idpostgrado
INNER JOIN categorias c ON c.id = p2.idcategoria
LEFT JOIN estados_academicos ea ON ea.id = i.estado_academico_id
LEFT JOIN estados_academicos ea2 ON ea2.id = ea.estado_academico_padre_id
LEFT JOIN estados_administrativos ea3 ON ea3.id = i.estado_administrativo_id
INNER JOIN productionadminesamdb.personas p3 ON p3.id = i.idestudiante
LEFT JOIN programa_universidad pu ON pu.id = p.programa_universidad_id
INNER JOIN productionadminesamdb.sedes s ON s.id = p.idsede
INNER JOIN estados_inscripcion ei ON ei.id = i.estado_ins
INNER JOIN productionadminesamdb.instituciones i2 ON i2.id = p.iduniversidad
/* Kardex consolidado desde CTEs */
LEFT JOIN cte_kardex kardex ON kardex.inscripcion_id = i.id
/* Detalle del último pago (para Id_Detalle_Pago y Concepto_Ultimo_Pago) */
LEFT JOIN detalle_pagos_inscripcion det_pag ON det_pag.id = kardex.id_dpi_max
/* Promociones */
LEFT JOIN cte_promociones prom ON prom.id = i.promocion_id
/* Última fecha de cambio de estado académico */
LEFT  JOIN cte_historial_estado hea ON hea.inscripcion_id = i.id
WHERE ei.id IN (0, 1, 2, 3, 4, 5)
  AND c.nombre IN ('Diplomado', 'Especialidad', 'Maestría')
  AND s.id IN (107,24,31,30,32,42,29,33,28,53,27)
  AND (p.iduniversidad IN (20) OR p.iduniversidad IS NULL)
GROUP BY i.id