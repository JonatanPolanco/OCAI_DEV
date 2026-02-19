-- Vista: v_agent_context
-- Proporciona contexto completo de la clínica para el agente de IA
-- Incluye: clínica, sede, doctores, horarios, especialidades, preguntas de evaluación

DROP VIEW IF EXISTS medical.v_agent_context CASCADE;

CREATE VIEW medical.v_agent_context AS
SELECT
    -- Información de la clínica
    c.id AS clinic_id,
    c.clinic_name,
    c.phone_number AS clinic_phone,
    c.status AS clinic_status,

    -- Información de la sede principal
    cb.id AS branch_id,
    cb.branch_name,
    cb.branch_phone_number,

    -- Ubicación
    l.country,
    l.city,
    l.address,

    -- Horarios de atención (agregados como JSON)
    (
        SELECT json_agg(
            json_build_object(
                'day_of_week', cwh.day_of_week,
                'day_name', CASE cwh.day_of_week
                    WHEN 1 THEN 'Lunes'
                    WHEN 2 THEN 'Martes'
                    WHEN 3 THEN 'Miércoles'
                    WHEN 4 THEN 'Jueves'
                    WHEN 5 THEN 'Viernes'
                    WHEN 6 THEN 'Sábado'
                    WHEN 7 THEN 'Domingo'
                END,
                'opening_time', cwh.opening_time::text,
                'closing_time', cwh.closing_time::text
            ) ORDER BY cwh.day_of_week
        )
        FROM medical.clinic_working_hours cwh
        WHERE cwh.clinic_id = c.id
    ) AS working_hours,

    -- Doctores con sus especialidades (agregados como JSON)
    (
        SELECT json_agg(
            json_build_object(
                'doctor_id', d.id,
                'first_name', d.first_name,
                'last_name', d.last_name,
                'full_name', d.first_name || ' ' || d.last_name,
                'specialties', (
                    SELECT json_agg(
                        json_build_object(
                            'specialty_id', s.id,
                            'specialty_name', s.name,
                            'is_primary', ds.is_primary
                        )
                    )
                    FROM medical.doctor_specialty ds
                    JOIN medical.specialty s ON ds.specialty_id = s.id
                    WHERE ds.doctor_id = d.id
                )
            )
        )
        FROM medical.doctor d
        WHERE d.clinic_id = c.id
    ) AS doctors,

    -- Plantilla de evaluación activa
    cet.id AS evaluation_template_id,
    cet.template_name AS evaluation_template_name,

    -- Preguntas de evaluación (agregadas como JSON)
    (
        SELECT json_agg(
            json_build_object(
                'question_id', eq.id,
                'question_text', eq.question_text,
                'question_order', eq.question_order
            ) ORDER BY eq.question_order
        )
        FROM medical.evaluation_question eq
        WHERE eq.template_id = cet.id
          AND eq.is_active = true
    ) AS evaluation_questions,

    -- Información de suscripción
    cs.subscription_plan,
    cs.status AS subscription_status,
    cs.start_date AS subscription_start,
    cs.end_date AS subscription_end,

    -- Timestamps
    c.created_at AS clinic_created_at,
    c.updated_at AS clinic_updated_at

FROM medical.clinic c

-- Join con sede principal (primera sede o la que tenga el mismo teléfono)
LEFT JOIN medical.clinic_branch cb ON cb.clinic_id = c.id
LEFT JOIN medical.location l ON cb.location_id = l.id

-- Join con plantilla de evaluación activa
LEFT JOIN medical.clinic_evaluation_template cet ON cet.clinic_id = c.id
    AND cet.is_active = true

-- Join con suscripción activa
LEFT JOIN medical.clinic_subscription cs ON cs.clinic_id = c.id
    AND cs.status = 'active'

WHERE c.status = 'active'
-- Priorizar la sede principal o la primera sede
AND cb.id = (
    SELECT MIN(cb2.id)
    FROM medical.clinic_branch cb2
    WHERE cb2.clinic_id = c.id
);

-- Índice para mejorar performance de búsqueda por teléfono
CREATE INDEX IF NOT EXISTS idx_clinic_phone_number ON medical.clinic(phone_number);

-- Comentario en la vista
COMMENT ON VIEW medical.v_agent_context IS
'Vista que proporciona contexto completo de la clínica para el agente de IA.
Incluye información de clínica, sede, ubicación, horarios, doctores, especialidades y evaluaciones.
Usar: SELECT * FROM medical.v_agent_context WHERE clinic_phone = ''+573001234567'';';

-- Ejemplo de uso
-- SELECT * FROM medical.v_agent_context WHERE clinic_phone = '+573001234567';

-- Para ver el JSON formateado de doctores:
-- SELECT clinic_name, jsonb_pretty(doctors::jsonb) FROM medical.v_agent_context WHERE clinic_phone = '+573001234567';

-- Para ver el JSON formateado de horarios:
-- SELECT clinic_name, jsonb_pretty(working_hours::jsonb) FROM medical.v_agent_context WHERE clinic_phone = '+573001234567';
