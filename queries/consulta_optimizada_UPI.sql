/* ══════════════════════════════════════════════════════════════════════════
   REPORTE UPI — CARTERA DE PARTICIPANTES
   Versión: 2.0  |  Refactorización: CTEs + reorganización de columnas
   ══════════════════════════════════════════════════════════════════════════
   ESTRUCTURA:
     CTE 1 · cte_plan_actualizado  → cuotas con descuentos desagregados
     CTE 2 · cte_pcpes             → montos del plan de cobros por concepto
     CTE 3 · cte_kardex            → kardex consolidado por cuota
     CTE 4 · cte_tram_personal     → pagos de trámites personales por inscripción
     CTE 5 · cte_promociones       → detalle de promociones
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
    JOIN inscripciones i ON i.id = pp.inscripcion_id
    JOIN plan_cobros_programa pcp ON pcp.id = i.plan_cobro_programa_id
    JOIN programas p ON p.id = i.idprograma
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
        SUM(IF(cp.concepto_pago_id = 312, cp.monto, 0)) AS pc_monto_cuota,
        SUM(IF(cp.concepto_pago_id = 314, cp.monto, 0)) AS pc_monto_servicio_plataforma,
        SUM(IF(cp.concepto_pago_id = 375, cp.monto, 0)) AS pc_monto_deuda_anterior,
        SUM(IF(cp.concepto_pago_id = 383, cp.monto, 0)) AS pc_monto_opcion_grado,
        SUM(IF(cp.concepto_pago_id = 388, cp.monto, 0)) AS pc_monto_recuperacion_asignatura,
        SUM(IF(cp.concepto_pago_id = 389, cp.monto, 0)) AS pc_monto_adicion_asignatura,
        SUM(IF(cp.concepto_pago_id = 313, cp.monto, 0)) AS pc_monto_diploma,
        SUM(IF(cp.concepto_pago_id = 278, cp.monto, 0)) AS pc_monto_certificacion
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
        pc.pc_monto_cuota,
        pc.pc_monto_servicio_plataforma,
        pc.pc_monto_deuda_anterior,
        pc.pc_monto_opcion_grado,
        pc.pc_monto_recuperacion_asignatura,
        pc.pc_monto_adicion_asignatura,
        /* Pagos efectivos de la cuota */
        SUM(IFNULL(dpi.monto, 0)) AS pagado,
        /* Saldo = monto – descuento – pagado */
        (pa.monto - pa.descuento_total - SUM(IFNULL(dpi.monto, 0))) AS saldo,
        /* Flags de plan */
        IF(UPPER(pa.plan_pago) LIKE '%CONTADO%', 1, 0) AS es_contado,
        /* Total formativo: pagos + regularizado + compensación (1, 2, 312, 389) */
        CASE WHEN pa.concepto_pago_id IN (1, 2, 312, 389)
             THEN IFNULL(SUM(IFNULL(dpi.monto, 0)), 0)
                  + IFNULL(pa.monto_regularizado, 0)
                  + IFNULL(pa.monto_compensacion, 0)
             ELSE 0
        END AS total_formativo_cuota,
        /* Total opcion de grado: pagos + regularizado + compensación (375, 383) */
        CASE WHEN pa.concepto_pago_id IN (375, 383)
             THEN IFNULL(SUM(IFNULL(dpi.monto, 0)), 0)
                  + IFNULL(pa.monto_regularizado, 0)
                  + IFNULL(pa.monto_compensacion, 0)
             ELSE 0
        END AS total_opcion_grado,
        /* Total otros conceptos: pagos + regularizado + compensación (314, 388) */
        CASE WHEN pa.concepto_pago_id IN (314, 388)
             THEN IFNULL(SUM(IFNULL(dpi.monto, 0)), 0)
                  + IFNULL(pa.monto_regularizado, 0)
                  + IFNULL(pa.monto_compensacion, 0)
             ELSE 0
        END AS total_otros_conceptos,
        /* Total diploma: pagos + regularizado + compensación (313, 278) */
        CASE WHEN pa.concepto_pago_id IN (313, 278)
        	 THEN IFNULL(SUM(IFNULL(dpi.monto, 0)), 0)
        	 	  + IFNULL(pa.monto_regularizado, 0)
        	 	  + IFNULL(pa.monto_compensacion, 0)
        	 ELSE 0
        END AS total_diploma,
        /* Cuota vencida: saldo > 0, concepto formativo, fecha límite en mes anterior */
        CASE WHEN (pa.monto - pa.descuento_total - SUM(IFNULL(dpi.monto, 0))) > 0
                  AND pa.fecha_pago < LAST_DAY(DATE_SUB(CURDATE(), INTERVAL 1 MONTH))
                  AND pa.concepto_pago_id IN (1, 2, 312, 314, 375, 383, 388, 389)
             THEN 1 ELSE 0
        END AS es_cuota_vencida,
        /* Cuota con saldo (independiente de fecha) */
        CASE WHEN (pa.monto - pa.descuento_total - SUM(IFNULL(dpi.monto, 0))) > 0
                  AND pa.concepto_pago_id IN (1, 2, 312, 314, 375, 383, 388, 389)
             THEN 1 ELSE 0
        END AS es_cuota_con_saldo,
        MAX(dpi.fecha_registro_pago) AS fecha_pago_max,
        MAX(dpi.id) AS id_dpi_max,
        /* Última fecha de pago por concepto (para columnas individuales en query principal) */
        MAX(CASE WHEN pa.concepto_pago_id = 1 THEN dpi.fecha_registro_pago END) AS fecha_ultimo_pago_matricula,
        MAX(CASE WHEN pa.concepto_pago_id = 2 THEN dpi.fecha_registro_pago END) AS fecha_ultimo_pago_colegiatura,
		MAX(CASE WHEN pa.concepto_pago_id = 312 THEN dpi.fecha_registro_pago END) AS fecha_ultimo_pago_cuota,
		MAX(CASE WHEN pa.concepto_pago_id = 314 THEN dpi.fecha_registro_pago END) AS fecha_ultimo_pago_servico_plataforma,
		MAX(CASE WHEN pa.concepto_pago_id = 375 THEN dpi.fecha_registro_pago END) AS fecha_ultimo_pago_deuda_anterior,
		MAX(CASE WHEN pa.concepto_pago_id = 383 THEN dpi.fecha_registro_pago END) AS fecha_ultimo_pago_opcion_grado,
		MAX(CASE WHEN pa.concepto_pago_id = 388 THEN dpi.fecha_registro_pago END) AS fecha_ultimo_pago_recuperacion_asignatura,
		MAX(CASE WHEN pa.concepto_pago_id = 389 THEN dpi.fecha_registro_pago END) AS fecha_ultimo_pago_adicion_asignatura,
        /* Última fecha de pago por concepto (para columnas individuales en query principal) */
        MIN(CASE WHEN pa.concepto_pago_id = 1 THEN dpi.fecha_registro_pago END) AS fecha_primer_pago_matricula,
		MIN(CASE WHEN pa.concepto_pago_id = 2 THEN dpi.fecha_registro_pago END) AS fecha_primer_pago_colegiatura,
        MIN(CASE WHEN pa.concepto_pago_id = 312 THEN dpi.fecha_registro_pago END) AS fecha_primer_pago_cuota,
		MIN(CASE WHEN pa.concepto_pago_id = 314 THEN dpi.fecha_registro_pago END) AS fecha_primer_pago_servico_plataforma,
		MIN(CASE WHEN pa.concepto_pago_id = 375 THEN dpi.fecha_registro_pago END) AS fecha_primer_pago_deuda_anterior,
		MIN(CASE WHEN pa.concepto_pago_id = 383 THEN dpi.fecha_registro_pago END) AS fecha_primer_pago_opcion_grado,
		MIN(CASE WHEN pa.concepto_pago_id = 388 THEN dpi.fecha_registro_pago END) AS fecha_primer_pago_recuperacion_asignatura,
		MIN(CASE WHEN pa.concepto_pago_id = 389 THEN dpi.fecha_registro_pago END) AS fecha_primer_pago_adicion_asignatura
	FROM cte_plan_actualizado pa
    JOIN cte_pcpes pc ON pc.id = pa.plan_pago_id
    LEFT JOIN detalle_pagos_inscripcion dpi ON dpi.cuota_id = pa.id AND dpi.estado = 1
    GROUP BY pa.id
),
/* ────────────────────────────────────────────────────────────────────────
   CTE 5 · Promociones con detalle por concepto
   ──────────────────────────────────────────────────────────────────────── */
cte_promociones AS (
    SELECT
        p4.id,
        p4.nombre,
        p4.descripcion,
        MAX(IF(dp.concepto_id = 1, dp.isporcentaje,    NULL)) AS mat_isporcent,
        MAX(IF(dp.concepto_id = 1, dp.valor_descuento, NULL)) AS mat_valor,
        MAX(IF(dp.concepto_id = 2, dp.isporcentaje,    NULL)) AS col_isporcent,
        MAX(IF(dp.concepto_id = 2, dp.valor_descuento, NULL)) AS col_valor,
        MAX(IF(dp.concepto_id = 312, dp.isporcentaje,    NULL)) AS cuo_isporcent,
        MAX(IF(dp.concepto_id = 312, dp.valor_descuento, NULL)) AS cuo_valor,
        MAX(IF(dp.concepto_id = 314, dp.isporcentaje,    NULL)) AS ser_isporcent,
        MAX(IF(dp.concepto_id = 314, dp.valor_descuento, NULL)) AS ser_valor,
        MAX(IF(dp.concepto_id = 375, dp.isporcentaje,    NULL)) AS deu_isporcent,
        MAX(IF(dp.concepto_id = 375, dp.valor_descuento, NULL)) AS deu_valor,
        MAX(IF(dp.concepto_id = 383, dp.isporcentaje,    NULL)) AS gra_isporcent,
        MAX(IF(dp.concepto_id = 383, dp.valor_descuento, NULL)) AS gra_valor,
        MAX(IF(dp.concepto_id = 388, dp.isporcentaje,    NULL)) AS adc_isporcent,
        MAX(IF(dp.concepto_id = 388, dp.valor_descuento, NULL)) AS adc_valor,
        MAX(IF(dp.concepto_id = 389, dp.isporcentaje,    NULL)) AS rec_isporcent,
        MAX(IF(dp.concepto_id = 389, dp.valor_descuento, NULL)) AS rec_valor
    FROM promociones p4
    JOIN detalle_promociones dp ON dp.promocion_id = p4.id
    GROUP BY p4.id, p4.nombre, p4.descripcion
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
    IFNULL(pu.programa_unico_id,"SIN ASIGNAR") AS Cod_Unico,
	IFNULL(pu.codigo, 'sin definir') AS Cod_Academico,
    IFNULL(	CASE
        		WHEN c.nombre = 'Diplomado'    THEN CONCAT_WS('-', 'D', p.id)
        		WHEN c.nombre = 'Especialidad' THEN CONCAT_WS('-', 'E', p.id)
        		WHEN c.nombre = 'Maestría'     THEN CONCAT_WS('-', 'M', p.id)
    	   	END,'sin definir') AS Id_Portal,
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
    /* ── § 3 · KARDEX / HISTORIAL DE PAGOS ───────────────────────────── */
    IFNULL(kardex.plan_pago, '-') AS Plan_Pago,
    IF(MAX(kardex.es_contado) = 1, 'Contado', 'Crédito') AS Tipo_Plan_Pago,
    IFNULL(kardex.pc_monto_matricula, 0) AS pc_monto_matricula,
    IFNULL(kardex.pc_monto_colegiatura, 0) AS pc_monto_colegiatura,
    IFNULL(kardex.pc_monto_cuota, 0) AS pc_monto_cuota,
    IFNULL(kardex.pc_monto_servicio_plataforma, 0) AS pc_monto_servicio_plataforma,
    IFNULL(kardex.pc_monto_deuda_anterior, 0) AS pc_monto_deuda_anterior,
    IFNULL(kardex.pc_monto_opcion_grado, 0) AS pc_monto_opcion_grado,
    IFNULL(kardex.pc_monto_recuperacion_asignatura, 0) AS pc_monto_recuperacion_asignatura,
    IFNULL(kardex.pc_monto_adicion_asignatura, 0) AS pc_monto_adicion_asignatura,
    IFNULL(prom.descripcion, '-') AS Desc_Promocion,
    /* Matricula */
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 1 THEN kardex.pagado ELSE 0 END), 0) AS Pago_Mensualidad_Mat,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 1 AND kardex.monto_descuento != 0 THEN kardex.monto_descuento ELSE 0 END), 0) AS Descuento_Mensualidad_Mat,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 1 AND kardex.monto_regularizado != 0 THEN kardex.monto_regularizado ELSE 0 END), 0) AS Regularizado_Mensualidad_Mat,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 1 AND kardex.monto_compensacion != 0 THEN kardex.monto_compensacion ELSE 0 END), 0) AS Compensacion_Mensualidad_Mat,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 1 AND kardex.monto_liquidado != 0 THEN kardex.monto_liquidado ELSE 0 END), 0) AS Liquidado_Mensualidad_Mat,
    DATE(IFNULL(MAX(kardex.fecha_ultimo_pago_matricula), '1900-01-01')) AS fecha_ultimo_pago_mensualidad_Mat,
    /* Colegiatura */
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 2 THEN kardex.pagado ELSE 0 END), 0) AS Pago_Formacion_Col,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 2 AND kardex.monto_descuento != 0 THEN kardex.monto_descuento ELSE 0 END), 0) AS Descuento_Formacion_Col,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 2 AND kardex.monto_regularizado != 0 THEN kardex.monto_regularizado ELSE 0 END), 0) AS Regularizado_Formacion_Col,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 2 AND kardex.monto_compensacion != 0 THEN kardex.monto_compensacion ELSE 0 END), 0) AS Compensacion_Formacion_Col,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 2 AND kardex.monto_liquidado != 0 THEN kardex.monto_liquidado ELSE 0 END), 0) AS Liquidado_Formacion_Col,
    DATE(IFNULL(MAX(kardex.fecha_ultimo_pago_colegiatura), '1900-01-01')) AS fecha_ultimo_pago_formacion_Col,
    /* Cuota */
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 312 THEN kardex.pagado ELSE 0 END), 0) AS Pago_Formacion_Cuota,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 312 AND kardex.monto_descuento != 0 THEN kardex.monto_descuento ELSE 0 END), 0) AS Descuento_Formacion_Cuota,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 312 AND kardex.monto_regularizado != 0 THEN kardex.monto_regularizado ELSE 0 END), 0) AS Regularizado_Formacion_Cuota,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 312 AND kardex.monto_compensacion != 0 THEN kardex.monto_compensacion ELSE 0 END), 0) AS Compensacion_Formacion_Cuota,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 312 AND kardex.monto_liquidado != 0 THEN kardex.monto_liquidado ELSE 0 END), 0) AS Liquidado_Formacion_Cuota,
    DATE(IFNULL(MAX(kardex.fecha_ultimo_pago_cuota), '1900-01-01')) AS fecha_ultimo_pago_formacion_Cuota,
    /* Servicio Plataforma */
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 314 THEN kardex.pagado ELSE 0 END), 0) AS Pago_Servicio_Plataforma,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 314 AND kardex.monto_descuento != 0 THEN kardex.monto_descuento ELSE 0 END), 0) AS Descuento_Servicio_Plataforma,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 314 AND kardex.monto_regularizado != 0 THEN kardex.monto_regularizado ELSE 0 END), 0) AS Regularizado_Servicio_Plataforma,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 314 AND kardex.monto_compensacion != 0 THEN kardex.monto_compensacion ELSE 0 END), 0) AS Compensacion_Servicio_Plataforma,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 314 AND kardex.monto_liquidado != 0 THEN kardex.monto_liquidado ELSE 0 END), 0) AS Liquidado_Servicio_Plataforma,
    DATE(IFNULL(MAX(kardex.fecha_ultimo_pago_servico_plataforma), '1900-01-01')) AS fecha_ultimo_pago_Servicio_Plataforma,
    /* Deuda Anterior */
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 375 THEN kardex.pagado ELSE 0 END), 0) AS Pago_Deuda_Anterior,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 375 AND kardex.monto_descuento != 0 THEN kardex.monto_descuento ELSE 0 END), 0) AS Descuento_Deuda_Anterior,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 375 AND kardex.monto_regularizado != 0 THEN kardex.monto_regularizado ELSE 0 END), 0) AS Regularizado_Deuda_Anterior,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 375 AND kardex.monto_compensacion != 0 THEN kardex.monto_compensacion ELSE 0 END), 0) AS Compensacion_Deuda_Anterior,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 375 AND kardex.monto_liquidado != 0 THEN kardex.monto_liquidado ELSE 0 END), 0) AS Liquidado_Deuda_Anterior,
    DATE(IFNULL(MAX(kardex.fecha_ultimo_pago_deuda_anterior), '1900-01-01')) AS fecha_ultimo_pago_Deuda_Anterior,
    /* Opcion de Grado */
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 383 THEN kardex.pagado ELSE 0 END), 0) AS Pago_Opcion_Grado,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 383 AND kardex.monto_descuento != 0 THEN kardex.monto_descuento ELSE 0 END), 0) AS Descuento_Opcion_Grado,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 383 AND kardex.monto_regularizado != 0 THEN kardex.monto_regularizado ELSE 0 END), 0) AS Regularizado_Opcion_Grado,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 383 AND kardex.monto_compensacion != 0 THEN kardex.monto_compensacion ELSE 0 END), 0) AS Compensacion_Opcion_Grado,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 383 AND kardex.monto_liquidado != 0 THEN kardex.monto_liquidado ELSE 0 END), 0) AS Liquidado_Opcion_Grado,
    DATE(IFNULL(MAX(kardex.fecha_ultimo_pago_opcion_grado), '1900-01-01')) AS fecha_ultimo_pago_Opcion_Grado,
    /* Recuperacion de Asignatura */
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 388 THEN kardex.pagado ELSE 0 END), 0) AS Pago_Recuperacion_Asignatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 388 AND kardex.monto_descuento != 0 THEN kardex.monto_descuento ELSE 0 END), 0) AS Descuento_Recuperacion_Asignatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 388 AND kardex.monto_regularizado != 0 THEN kardex.monto_regularizado ELSE 0 END), 0) AS Regularizado_Recuperacion_Asignatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 388 AND kardex.monto_compensacion != 0 THEN kardex.monto_compensacion ELSE 0 END), 0) AS Compensacion_Recuperacion_Asignatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 388 AND kardex.monto_liquidado != 0 THEN kardex.monto_liquidado ELSE 0 END), 0) AS Liquidado_Recuperacion_Asignatura,
    DATE(IFNULL(MAX(kardex.fecha_ultimo_pago_recuperacion_asignatura), '1900-01-01')) AS fecha_ultimo_pago_Recuperacion_Asignatura,
    /* Adicion de Asignatura */
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 389 THEN kardex.pagado ELSE 0 END), 0) AS Pago_Adicion_Asignatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 389 AND kardex.monto_descuento != 0 THEN kardex.monto_descuento ELSE 0 END), 0) AS Descuento_Adicion_Asignatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 389 AND kardex.monto_regularizado != 0 THEN kardex.monto_regularizado ELSE 0 END), 0) AS Regularizado_Adicion_Asignatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 389 AND kardex.monto_compensacion != 0 THEN kardex.monto_compensacion ELSE 0 END), 0) AS Compensacion_Adicion_Asignatura,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id = 389 AND kardex.monto_liquidado != 0 THEN kardex.monto_liquidado ELSE 0 END), 0) AS Liquidado_Adicion_Asignatura,
    DATE(IFNULL(MAX(kardex.fecha_ultimo_pago_adicion_asignatura), '1900-01-01')) AS fecha_ultimo_pago_Adicion_Asignatura,
    /* Totales y saldos */
    IFNULL(SUM(kardex.total_formativo_cuota), 0) AS Monto_Pagado_Fase_Formativa,
    IFNULL(SUM(kardex.total_opcion_grado), 0) AS Monto_Pagado_Opcion_Grado,
    IFNULL(SUM(kardex.total_otros_conceptos), 0) AS Monto_Pagado_Otros_Conceptos,
    IFNULL(SUM(CASE WHEN kardex.saldo > 0 THEN
                    CASE
                        WHEN kardex.es_contado = 1 AND kardex.concepto_pago_id IN (1, 2, 312, 389) THEN kardex.saldo 
                        WHEN kardex.es_contado = 0 AND kardex.concepto_pago_id IN (1, 2, 312, 389) THEN kardex.saldo
                        ELSE 0
                    END ELSE 0 END), 0) AS Saldo_Pendiente_Fase_Formativa,
    IFNULL(SUM(CASE WHEN kardex.saldo > 0 THEN
                    CASE
                        WHEN kardex.es_contado = 1 AND kardex.concepto_pago_id IN (383) THEN kardex.saldo 
                        WHEN kardex.es_contado = 0 AND kardex.concepto_pago_id IN (383) THEN kardex.saldo
                        ELSE 0
                    END ELSE 0 END), 0) AS Saldo_Opcion_Grado,
    IFNULL(SUM(CASE WHEN kardex.concepto_pago_id IN (1, 2, 312, 314, 375, 383, 388, 389)
                    THEN IFNULL(kardex.monto_liquidado, 0) ELSE 0 END), 0) AS Monto_Total_Liquidado,
    DATE(IFNULL(MAX(kardex.fecha_pago_max), '1900-01-01')) AS Fecha_Ultimo_Pago,
    IFNULL(CASE
        WHEN MAX(det_pag.concepto_pago_id) = 1 THEN 'Matricula'
        WHEN MAX(det_pag.concepto_pago_id) = 2 THEN 'Colegiatura'
        WHEN MAX(det_pag.concepto_pago_id) = 312 THEN 'Cuota'
       	WHEN MAX(det_pag.concepto_pago_id) = 314 THEN 'Servicio Plataforma'
        WHEN MAX(det_pag.concepto_pago_id) = 375 THEN 'Deuda Anterior'
        WHEN MAX(det_pag.concepto_pago_id) = 383 THEN 'Opcion de Grado'
        WHEN MAX(det_pag.concepto_pago_id) = 388 THEN 'Adicion de Asignatura'
        WHEN MAX(det_pag.concepto_pago_id) = 389 THEN 'Recuperacion de Asignatura'
    END, 'sin definir') AS Concepto_Ultimo_Pago,
    /* ── § 4 · ESTADOS ───────────────────────────────────────────────── */
    CASE i.estado_administrativo_id
        WHEN 1 THEN 'Prospecto'
        WHEN 2 THEN 'Preinscrito'
        WHEN 3 THEN 'Inscrito'
        WHEN 4 THEN 'Inscrito Transferido'
        WHEN 5 THEN 'Retirado'
        WHEN 6 THEN 'Retirado Cambiado'
        WHEN 7 THEN 'Observado'
        ELSE 'Otro'
    END AS Estado_Administrativo,
    IFNULL(ea.nombre, 'sin definir') AS Estado_Academico,
    ei.nombre AS Estado_Portal,
    /* Estado Cartera: basado en cuotas vencidas vs saldo */
    CASE
        WHEN SUM(kardex.es_cuota_vencida) = 0 AND SUM(kardex.es_cuota_con_saldo) > 0 THEN 'Vigente'
        WHEN SUM(kardex.es_cuota_con_saldo) = 0 AND i.estado_ins != 2 THEN 'Exento de deuda'
        WHEN SUM(kardex.es_cuota_con_saldo) = 0 AND i.estado_ins = 2 THEN 'Liquidado'
        WHEN SUM(kardex.es_cuota_vencida) BETWEEN 1 AND 2 THEN 'Retrasado'
        WHEN SUM(kardex.es_cuota_vencida) >= 3 AND p.fecha_fin <= CURDATE() THEN 'Riesgo de incobrabilidad'
        WHEN SUM(kardex.es_cuota_vencida) >= 3 AND p.fecha_fin  > CURDATE() THEN 'En mora'
        ELSE 'Sin cartera asignada'
    END AS Estado_Cartera,
    IFNULL(SUM(kardex.total_diploma), 0) AS Monto_Pagado_Diploma,
    IFNULL(SUM(CASE WHEN kardex.saldo > 0 THEN
                    CASE
                        WHEN kardex.es_contado = 1 AND kardex.concepto_pago_id IN (278, 313) THEN kardex.saldo 
                        WHEN kardex.es_contado = 0 AND kardex.concepto_pago_id IN (278, 313) THEN kardex.saldo
                        ELSE 0
                    END ELSE 0 END), 0) AS Saldo_Diploma
FROM inscripciones i
INNER JOIN programas p ON p.id = i.idprograma
INNER JOIN postgrados p2 ON p2.id = p.idpostgrado
INNER JOIN categorias c ON c.id = p2.idcategoria
LEFT JOIN estados_academicos ea ON ea.id = i.estado_academico_id
LEFT JOIN estados_academicos ea2 ON ea2.id = ea.estado_academico_padre_id
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
WHERE s.id IN (24,27,28,29,30,31,32,33,42,53,107, /* Sedes DBS */
				1,2,3,4,5,6,7,8,14,15,16,18,20,22,23,25,26,37,50,51,52,80,125,127,128,129,132,134, /* Sedes Esam */
				82,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,102,103,104,105,106,108,109,115,116,117,118,119,120,121,122,123,124,126)  /* Sedes UPI */
  AND i2.id IN (301,307) /* Convenio UPI */
GROUP BY i.id