SELECT
  IFNULL(pu.programa_unico_id,"SIN ASIGNAR") AS Cod_Unico,
  COALESCE(pu.codigo, '') AS Cod_Academico,
  CASE
	  WHEN cat.nombre = 'Diplomado' THEN CONCAT_WS('-', 'D', prog.id)
      WHEN cat.nombre = 'Especialidad' THEN CONCAT_WS('-', 'E', prog.id)
      WHEN cat.nombre = 'Maestría' THEN CONCAT_WS('-', 'M', prog.id)
  END AS Id_Portal,
  prog.nombre_compuesto AS Programa,
  prog.gestion AS Gestion,
  cat.nombre AS Tipo,
  s.nombre AS Sede,
  i.id AS id_ins_potal,
  ipu.id AS id_ins_SXX,
  p.num_doc AS ci,
  CONCAT_WS(' ', p.nombres, p.pri_apellido, p.seg_apellido) AS Alumno,
  pu.notas_importadas AS notasImportadas,
  ipu.codigo_empastado AS codigoEmpastado,
  -- módulos (alimentan DNA y programacionCompleta)
  COALESCE(mods.total, 0) AS modulosRequeridos,
  COALESCE(prg.programados, 0) AS modulosProgramados,
  CASE
    WHEN COALESCE(mods.total, 0) > 0
     AND COALESCE(prg.programados, 0) = mods.total THEN 1 ELSE 0
  END AS programacionCompleta,
  -- ── Estado Académico Portal (mapearEstadoAcademicoESAM) ──
  CASE
    WHEN eac.nombre IS NULL OR TRIM(eac.nombre) = '' THEN 'Sin estado'
    WHEN LOWER(TRIM(eac.nombre)) IN ('elaboracion trabajo','elaboracion de trabajo','concluido aprobado',
      'aprobado trabajo final','entrega de trabajo','pre-defensa','defensa final'
    ) THEN 'Concluido'
    WHEN LOWER(TRIM(eac.nombre)) IN ('vigente','en desarrollo') THEN 'En Desarrollo'
    WHEN LOWER(TRIM(eac.nombre)) = 'en desarrollo - nivelacion' THEN 'En Desarrollo - Nivelación'
    WHEN LOWER(TRIM(eac.nombre)) IN ('abandono','abandono academico') THEN 'Abandono académico'
    WHEN LOWER(TRIM(eac.nombre)) = 'reprobado' THEN 'Reprobado'
    ELSE eac.nombre
  END AS Estado_Acad_Portal,
  -- ── Estado Académico DNA (solo rama notas_importadas = 1) ──
  CASE
    WHEN pu.notas_importadas <> 1 THEN 'Pendiente (notas no importadas)'
    WHEN COALESCE(mods.total, 0) = 0 THEN '-'
    WHEN COALESCE(prg.programados, 0) < mods.total THEN '-'   -- faltan módulos por programar
    WHEN COALESCE(prg.reprobadas, 0) > 0 THEN 'Abandono académico'
    ELSE 'Concluido'
  END AS Estado_Acad_Sistema
FROM inscripcion_programa_universidad ipu
INNER JOIN inscripciones i ON i.id = ipu.inscripcion_id
INNER JOIN programa_universidad pu ON pu.id = ipu.programa_universidad_id
LEFT JOIN programas prog ON prog.id = i.idprograma
LEFT JOIN postgrados pg ON pg.id = prog.idpostgrado
LEFT JOIN categorias cat ON cat.id = pg.idcategoria
LEFT JOIN estados_academicos eac ON eac.id = i.estado_academico_id
LEFT JOIN productionadminesamdb.personas p ON p.id = i.idestudiante
LEFT JOIN productionadminesamdb.sedes s ON s.id = prog.idsede
-- total de módulos del programa universidad (módulos requeridos)
LEFT JOIN (
  SELECT programa_universidad_id, COUNT(*) AS total
  FROM modulo_programa_universidad
  WHERE eliminado_en IS NULL
  GROUP BY programa_universidad_id
) mods ON mods.programa_universidad_id = pu.id
-- programaciones del estudiante + cuántas reprobadas/sin nota
LEFT JOIN (
  SELECT
    inscripcion_programa_universidad_id,
    COUNT(*) AS programados,
    SUM(CASE WHEN nota_final IS NULL OR nota_final < 71 THEN 1 ELSE 0 END) AS reprobadas
  FROM programacion_modulo_universidad
  WHERE eliminado_en IS NULL
  GROUP BY inscripcion_programa_universidad_id
) prg ON prg.inscripcion_programa_universidad_id = ipu.id
WHERE ipu.estado = 'inscrito'			
  AND i.estado_ins IN (0, 1, 2, 3, 4, 5)
  AND cat.nombre IN ('Diplomado', 'Especialidad', 'Maestría')
  AND pu.notas_importadas=1
ORDER BY i.fecha_registro DESC;