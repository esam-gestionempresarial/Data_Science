SELECT
    IFNULL(pu.programa_unico_id,"SIN ASIGNAR") AS cod_unico,
    IFNULL(pu.codigo, "SIN ASIGNAR") AS cod_academico,
    CASE
        WHEN c.nombre = 'Diplomado'   THEN CONCAT_WS('-', 'D', p.id)
        WHEN c.nombre = 'Especialidad' THEN CONCAT_WS('-', 'E', p.id)
        WHEN c.nombre = 'Maestría'    THEN CONCAT_WS('-', 'M', p.id)
    END AS Id_Esam,
    s.nombre AS sede,
    c.nombre AS tipo,
    i2.abreviatura AS convenio,
    p.nombre_compuesto AS programa,
    CASE
        WHEN ep.parent_id = 1 THEN "Comercialización"
        WHEN ep.parent_id = 2 THEN "Desarrollo"
        WHEN ep.parent_id = 3 THEN "Culminado"
    END AS fase,
    ep.nombre AS estado,
    p.fecha_inicio,
    p.fecha_fin,
    COUNT(DISTINCT i.id) AS cant_registros,
    COUNT(DISTINCT CASE WHEN i.estado_ins = 1 THEN i.id END) AS cant_inscritos,
    IFNULL(ult_mod.numero, 0) AS fase_actual,
    IFNULL(COUNT(DISTINCT mpu.id), 0) AS cant_modulos
FROM programas p
LEFT JOIN postgrados p2 ON p.idpostgrado = p2.id
LEFT JOIN categorias c ON p2.idcategoria = c.id
LEFT JOIN programa_universidad pu ON p.programa_universidad_id = pu.id
LEFT JOIN estados_programas ep ON p.estado_programa_id = ep.id
INNER JOIN inscripciones i ON i.idprograma = p.id
LEFT JOIN modulo_programa_universidad mpu ON pu.id = mpu.programa_universidad_id
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
WHERE c.nombre REGEXP '^(Dip|Maes|Esp)'
GROUP BY i2.abreviatura, s.nombre, c.nombre, pu.codigo, Id_Esam, p.nombre_compuesto, ep.parent_id, ep.nombre, p.estado_programa_id, p.fecha_inicio, p.fecha_fin, ult_mod.numero
ORDER BY pu.programa_unico_id ASC