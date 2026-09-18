/*
    Previamente conectarse a la base de datos mediante el siguiente comando SSH:
    ssh -i .\sis_ge_pagos -L 3308:localhost:3307 -p 2289 israel-marcani@node-ge.esam.edu.bo -N
    Consulta para obtener el estado de investigación y el estado de titulación de cada persona.
    Se realiza un LEFT JOIN entre las tablas de investigaciones y titulaciones, asegurando que se obtenga
    la última titulación registrada para cada persona.
*/
SELECT
    i.inscripcion_universidad_id AS id_ins_sxx,
    i.estado AS estado_investigacion,
    t.estado AS estado_titulacion,
FROM db_esam_dna.investigaciones i
LEFT JOIN db_esam_dna.titulaciones t
    ON t.persona_id = i.persona_id
   AND t.created_at = (
        SELECT MAX(t2.created_at)
        FROM db_esam_dna.titulaciones t2
        WHERE t2.persona_id = i.persona_id
   )
ORDER BY i.persona_id;