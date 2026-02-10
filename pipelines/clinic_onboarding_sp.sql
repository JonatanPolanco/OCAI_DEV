CREATE OR REPLACE FUNCTION medical.process_clinic_onboarding(p_onboarding_id INTEGER)
RETURNS JSONB AS $$
DECLARE
    r_onb RECORD;          -- Para leer la fila de onboarding
    v_location_id INTEGER;
    v_clinic_id INTEGER;
    v_specialty_id INTEGER;
    v_doctor_id INTEGER;
    v_template_id INTEGER;
    doctor_item JSONB;     -- Variable temporal para el loop del JSON
BEGIN
    -- 1. Leer datos de la tabla de onboarding
    SELECT * INTO r_onb 
    FROM medical.clinic_onboarding 
    WHERE id = p_onboarding_id;

    -- Validaciones básicas
    IF r_onb IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'ID no encontrado');
    END IF;

    IF r_onb.onboarding_status = 'Completed' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Ya fue procesado');
    END IF;

    -- INICIO DE TRANSACCIÓN IMPLÍCITA -------------------------

    -- 2. Crear Ubicación (location)
    INSERT INTO medical.location (country, city, address)
    VALUES (r_onb.country, r_onb.city, r_onb.address)
    RETURNING id INTO v_location_id;

    -- 3. Crear Clínica (clinic)
    INSERT INTO medical.clinic (clinic_name, phone_number, status)
    VALUES (r_onb.clinic_name, r_onb.clinic_phone, 'active')
    RETURNING id INTO v_clinic_id;

    -- 4. Crear Suscripción (clinic_subscription)
    INSERT INTO medical.clinic_subscription (clinic_id, subscription_plan, start_date, status)
    VALUES (v_clinic_id, r_onb.subscription_plan, CURRENT_DATE, 'active');

    -- 5. Crear Sede (clinic_branch)
    INSERT INTO medical.clinic_branch (branch_name, branch_phone_number, location_id, clinic_id)
    VALUES (r_onb.branch_name, r_onb.clinic_phone, v_location_id, v_clinic_id);

    -- 6. Crear Horarios (clinic_working_hours)
    -- Generamos Lunes(1) a Viernes(5) automáticamente
    INSERT INTO medical.clinic_working_hours (clinic_id, day_of_week, opening_time, closing_time)
    SELECT v_clinic_id, dia, r_onb.opening_time, r_onb.closing_time
    FROM generate_series(1, 5) AS dia;

    -- 7. Crear Plantilla de Evaluación (clinic_evaluation_template)
    INSERT INTO medical.clinic_evaluation_template (clinic_id, template_name, is_active)
    VALUES (v_clinic_id, r_onb.evaluation_template_name, true)
    RETURNING id INTO v_template_id;

    -- (Opcional) Crear preguntas por defecto para esa plantilla
    INSERT INTO medical.evaluation_question (template_id, question_text, question_order)
    VALUES 
    (v_template_id, '¿Cuál es el motivo principal de su consulta?', 1),
    (v_template_id, '¿Desde cuándo presenta los síntomas?', 2);

    -- 8. 🔄 LOOP DE DOCTORES (Procesar JSON)
    -- Recorremos la lista JSONB insertando doctores y especialidades
    FOR doctor_item IN SELECT * FROM jsonb_array_elements(r_onb.doctors_list)
    LOOP
        -- A. Gestionar Especialidad (Upsert manual)
        -- Intentamos insertar, si existe no hace nada (gracias al índice único del Paso 1)
        INSERT INTO medical.specialty (name)
        VALUES (doctor_item->>'specialty')
        ON CONFLICT (name) DO NOTHING;
        
        -- Recuperamos el ID (sea nuevo o viejo)
        SELECT id INTO v_specialty_id FROM medical.specialty WHERE name = doctor_item->>'specialty';

        -- B. Crear Doctor
        INSERT INTO medical.doctor (first_name, last_name, clinic_id)
        VALUES (
            doctor_item->>'first_name',
            doctor_item->>'last_name',
            v_clinic_id
        ) RETURNING id INTO v_doctor_id;

        -- C. Vincular Doctor-Especialidad
        INSERT INTO medical.doctor_specialty (doctor_id, specialty_id, is_primary)
        VALUES (v_doctor_id, v_specialty_id, true)
        ON CONFLICT DO NOTHING;
        
    END LOOP;

    -- 9. Finalizar: Marcar como Completado
    UPDATE medical.clinic_onboarding
    SET onboarding_status = 'Completed', error_message = NULL
    WHERE id = p_onboarding_id;

    RETURN jsonb_build_object('success', true, 'clinic_id', v_clinic_id, 'message', 'Onboarding exitoso');

EXCEPTION WHEN OTHERS THEN
    -- Si algo falla, guardamos el error en la tabla
    UPDATE medical.clinic_onboarding
    SET onboarding_status = 'Error', error_message = SQLERRM
    WHERE id = p_onboarding_id;

    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql;