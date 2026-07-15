select
	pu.codigo as cod_academico,
	cu.nombre as tipo_programa,
	ipu.id as id_ins_sxx,
	IFNULL(i.id, "-") as id_ins_portal,
	IFNULL(p.num_doc, "-") as CI,
	SUM(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 1 THEN ppue.monto_total ELSE 0 END) AS Moto_Ins,
	MAX(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 1 THEN ppue.cite_codigo ELSE '-' END) AS Cite_Ins,
	SUM(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 2 THEN ppue.monto_total ELSE 0 END) AS Monto_Mat,
	MAX(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 2 THEN ppue.cite_codigo ELSE '-' END) AS Cite_Mat,
	SUM(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 3 THEN ppue.monto_total ELSE 0 END) AS Monto_Col,
	MAX(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 3 THEN ppue.cite_codigo ELSE '-' END) AS Cite_Col,
	SUM(CASE WHEN ppue.estado = 'COMPLETADO' and ppcu.concepto_universidad_id = 4 THEN ppue.monto_total ELSE 0 END) AS Monto_Cert,
	MAX(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 4 THEN ppue.cite_codigo ELSE '-' END) AS Cite_Cert,
	SUM(CASE WHEN ppue.estado = 'COMPLETADO' and ppcu.concepto_universidad_id = 6 THEN ppue.monto_total ELSE 0 END) AS Monto_Folder,
	MAX(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 6 THEN ppue.cite_codigo ELSE '-' END) AS Cite_Folder,
	SUM(CASE WHEN ppue.estado = 'COMPLETADO' and ppcu.concepto_universidad_id = 8 THEN ppue.monto_total ELSE 0 END) AS Monto_Tram_Acelerado,
	MAX(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 8 THEN ppue.cite_codigo ELSE '-' END) AS Cite_Tra_Acelerado,
	SUM(CASE WHEN ppue.estado = 'COMPLETADO' and ppcu.concepto_universidad_id = 9 THEN ppue.monto_total ELSE 0 END) AS Monto_Tit_Acad_Ext,
	MAX(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 9 THEN ppue.cite_codigo ELSE '-' END) AS Cite_Tit_Acad_Ext,
	SUM(CASE WHEN ppue.estado = 'COMPLETADO' and ppcu.concepto_universidad_id = 10 THEN ppue.monto_total ELSE 0 END) AS Monto_CI_Nac_Ext,
	MAX(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 10 THEN ppue.cite_codigo ELSE '-' END) AS Cite_CI_Nac_Ext,
	SUM(CASE WHEN ppue.estado = 'COMPLETADO' and ppcu.concepto_universidad_id = 11 THEN ppue.monto_total ELSE 0 END) AS Monto_Cert_Nac_Ext,
	MAX(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 11 THEN ppue.cite_codigo ELSE '-' END) AS Cite_Cert_Nac_Ext,
	SUM(CASE WHEN ppue.estado = 'COMPLETADO' and ppcu.concepto_universidad_id = 12 THEN ppue.monto_total ELSE 0 END) AS Monto_Revalidacion,
	MAX(CASE WHEN ppue.estado = 'COMPLETADO' AND ppcu.concepto_universidad_id = 12 THEN ppue.cite_codigo ELSE '-' END) AS Cite_Revalidacion
from inscripcion_programa_universidad ipu
left join programa_universidad pu on ipu.programa_universidad_id = pu.id
inner join categorias_universidades cu on cu.id = pu.categoria_universidad_id
left join sede_universidad su on pu.sede_universidad_id = su.id
right join plan_pagos_universidad_estudiantes ppue on ppue.inscripcion_programa_universidad_id = ipu.id
right join pagos_universidad_estudiantes pue on pue.plan_pagos_universidad_estudiantes_id = ppue.id
right join plan_pagos_concepto_universidad ppcu on ppcu.id = ppue.plan_pagos_concepto_universidad_id
left join inscripciones i on i.id = ipu.inscripcion_id
left join productionadminesamdb.personas p on p.id = i.idestudiante 
where su.universidad_id = 9 #and ppue.cite_codigo like '%/06/2026'
GROUP BY ipu.id, i.id ORDER BY i.id DESC