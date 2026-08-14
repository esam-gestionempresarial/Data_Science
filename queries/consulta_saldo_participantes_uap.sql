select
	pu.codigo as cod_academico,
	IFNULL(CASE
		WHEN cu.nombre = 'Diplomado' THEN CONCAT_WS('-', 'D', i.idprograma)
        WHEN cu.nombre = 'Especialidad' THEN CONCAT_WS('-', 'E', i.idprograma)
        WHEN cu.nombre = 'Maestría' THEN CONCAT_WS('-', 'M', i.idprograma)
    END, "-") as id_portal,
	cu.nombre as tipo_programa,
	au.nombre as area_programa,
	pu.programa_nombre as programa,
	ipu.id as id_ins_uap,
	IFNULL(i.id, "-") as id_ins_portal,
	CONCAT_WS(' ', p.pri_apellido, p.seg_apellido, p.nombres) AS Alumno,
	IFNULL(p.num_doc, "-") as CI,
	SUM(CASE WHEN sp.concepto_id = 2 THEN sp.monto ELSE 0 END) AS Monto_Matricula,
	SUM(CASE WHEN sp.concepto_id = 3 THEN sp.monto ELSE 0 END) AS Monto_Colegiatura,
	SUM(CASE WHEN sp.concepto_id = 5 THEN sp.monto ELSE 0 END) AS Monto_Titulacion
from inscripcion_programa_universidad ipu
left join detalles_solicitudes_pagos dsp on ipu.id = dsp.inscripcion_programa_universidad_id
left join solicitudes_pagos sp on dsp.solicitud_pago_id = sp.id
left join detalles_plan_pagos_concepto_universidad dppcu on sp.detalle_plan_pago_concepto_universidad_id = dppcu.id
left join plan_pagos_concepto_universidad ppcu on dppcu.plan_pago_concepto_universidad_id = ppcu.id
left join programa_universidad pu on ipu.programa_universidad_id = pu.id
inner join categorias_universidades cu on cu.id = pu.categoria_universidad_id
left join sede_universidad su on pu.sede_universidad_id = su.id
left join inscripciones i on ipu.inscripcion_id = i.id
left join areas_universidades au on pu.area_universidad_id = au.id
left join productionadminesamdb.personas p on i.idestudiante = p.id 
where su.universidad_id = 49
GROUP BY ipu.id, i.id ORDER BY i.id DESC