SELECT
    IFNULL(pu.programa_unico_id,"sin registrar") AS cod_unico,
    IFNULL(pu.codigo, "sin registrar") AS cod_academico,
    IFNULL(p.codigo, "sin registrar") AS cod_contable,
    CASE
        WHEN c.nombre = 'Diplomado' THEN CONCAT_WS('-', 'D', p.id)
        WHEN c.nombre = 'Especialidad' THEN CONCAT_WS('-', 'E', p.id)
        WHEN c.nombre = 'Maestría'THEN CONCAT_WS('-', 'M', p.id)
    END AS id_portal,
    s.nombre AS sede,
    c.nombre AS tipo,
    IFNULL(au.nombre,"sin registrar") AS area,
    i2.abreviatura AS convenio,
    p.nombre_compuesto AS programa,
    IFNULL(pu.version,"sin registrar") AS version,
    IFNULL(pu.tiene_ceub,"sin registrar") AS tiene_ceub,
    IFNULL(pu.nomenclatura_hcu,"sin registrar") AS nomenclatura_hcu,
    IFNULL(pu.horas_academicas_ceub,"sin registrar") AS horas_academicas_ceub,
    IFNULL(pu.numero_creditos_ceub,"sin registrar") AS numero_creditos_ceub,
    IFNULL(su.nombre,"sin registrar") AS sede_universidad,
    CASE
        WHEN ep.parent_id = 1 THEN "Comercialización"
        WHEN ep.parent_id = 2 THEN "Desarrollo"
        WHEN ep.parent_id = 3 THEN "Culminado"
        ELSE "sin registrar"
    END AS fase,
    IFNULL(ep.nombre, "sin registrar") AS estado,
    DATE(p.fecha_registro) AS fecha_registro_prog_portal,
    p.fecha_inicio AS fecha_inicio_prog_portal,
    p.fecha_fin AS fecha_fin_prog_portal,
    pu.fecha_inicio AS fecha_inicio_prog_univ,
    pu.fecha_fin AS fecha_fin_prog_univ,
    IFNULL(pu.carga_horaria,"sin registrar") AS carga_horaria,
    COUNT(DISTINCT i.id) AS cant_registros,
    COUNT(DISTINCT CASE WHEN ea.id = 3 OR ea.id = 9 THEN i.id END) AS cant_inscritos,
    IFNULL(ult_mod.numero, 0) AS fase_actual,
    IFNULL(COUNT(DISTINCT mpu.id), 0) AS cant_modulos
FROM programas p
LEFT JOIN postgrados p2 ON p.idpostgrado = p2.id
LEFT JOIN categorias c ON p2.idcategoria = c.id
LEFT JOIN programa_universidad pu ON p.programa_universidad_id = pu.id
LEFT JOIN estados_programas ep ON p.estado_programa_id = ep.id
LEFT JOIN inscripciones i ON i.idprograma = p.id
LEFT JOIN modulo_programa_universidad mpu ON pu.id = mpu.programa_universidad_id
LEFT JOIN sede_universidad su ON pu.sede_universidad_id = su.id
LEFT JOIN areas_universidades au ON pu.area_universidad_id = au.id
LEFT JOIN estados_administrativos ea ON i.estado_administrativo_id = ea.id
INNER JOIN productionadminesamdb.instituciones i2 ON p.iduniversidad = i2.id
INNER JOIN productionadminesamdb.sedes s ON p.idsede = s.id
/* ── Último módulo ── */
LEFT JOIN (
    SELECT idprograma, numero
    FROM (
        SELECT
            pm.idprograma,
            pm.numero,
            ROW_NUMBER() OVER (PARTITION BY pm.idprograma ORDER BY im.fecha_registro DESC) AS rnk
        FROM productionacademicoesamdb.programa_modulos pm
        INNER JOIN productionacademicoesamdb.inscripcion_modulo im ON pm.id = im.programa_modulo_id
    ) ranked_modulos
    WHERE rnk = 1
) ult_mod ON ult_mod.idprograma = p.id
WHERE c.nombre REGEXP '^(Dip|Maes|Esp|Curso|Carrera|licenciatura|Téc)'
GROUP BY i2.abreviatura, s.nombre, c.nombre, pu.codigo, p.codigo, Id_Portal, p.nombre_compuesto, ep.parent_id, ep.nombre, p.estado_programa_id, p.fecha_inicio, p.fecha_fin, ult_mod.numero, fecha_registro_prog_portal
ORDER BY pu.programa_unico_id ASC