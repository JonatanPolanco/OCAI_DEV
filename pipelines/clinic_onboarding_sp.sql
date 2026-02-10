CREATE OR REPLACE FUNCTION medical.process_clinic_onboarding(p_onboarding_id INTEGER)
RETURNS JSONB AS $$
DECLARE
    r_onb RECORD;          
    v_location_id INTEGER;
    v_clinic_id INTEGER;
    v_specialty_id INTEGER;
    v_doctor_id INTEGER;
    v_template_id INTEGER;
    doctor_item JSONB;     
    question_text TEXT;    -- Nueva variable para el loop de preguntas
    q_order INTEGER := 1;  -- Contador para el orden de preguntas
BEGIN
    -- 1. Leer datos y BLOQUEAR duplicados (Solo procesa si está en 'Ready')
    SELECT * INTO r_onb 
    FROM medical.clinic_onboarding 
    WHERE id = p_onboarding_id AND onboarding_status = 'Ready';

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', true, 'message', 'Ya procesado o no encontrado');
    END IF;

    -- Marcamos inicio para evitar que otros procesos lo tomen
    UPDATE medical.clinic_onboarding SET onboarding_status = 'Processing' WHERE id = p_onboarding_id;

    -- 2. Crear Ubicación
    INSERT INTO medical.location (country, city, address)
    VALUES (r_onb.country, r_onb.city, r_onb.address)
    RETURNING id INTO v_location_id;

    -- 3. Crear Clínica
    INSERT INTO medical.clinic (clinic_name, phone_number, status)
    VALUES (r_onb.clinic_name, r_onb.clinic_phone, 'active')
    RETURNING id INTO v_clinic_id;

    -- 4. Crear Suscripción
    INSERT INTO medical.clinic_subscription (clinic_id, subscription_plan, start_date, status)
    VALUES (v_clinic_id, r_onb.subscription_plan, CURRENT_DATE, 'active');

    -- 5. Crear Sede
    INSERT INTO medical.clinic_branch (branch_name, branch_phone_number, location_id, clinic_id)
    VALUES (r_onb.branch_name, r_onb.clinic_phone, v_location_id, v_clinic_id);

    -- 6. Crear Horarios (Lunes a Viernes)
    INSERT INTO medical.clinic_working_hours (clinic_id, day_of_week, opening_time, closing_time)
    SELECT v_clinic_id, dia, r_onb.opening_time, r_onb.closing_time
    FROM generate_series(1, 5) AS dia;

    -- 7. Crear Plantilla de Evaluación
    INSERT INTO medical.clinic_evaluation_template (clinic_id, template_name, is_active)
    VALUES (v_clinic_id, r_onb.evaluation_template_name, true)
    RETURNING id INTO v_template_id;

    -- 8. 🔄 PROCESAR PREGUNTAS DEL EXCEL (Separadas por \n)
    IF r_onb.evaluation_questions IS NOT NULL THEN
        FOR question_text IN SELECT regexp_split_to_table(r_onb.evaluation_questions, '\n')
        LOOP
            IF length(trim(question_text)) > 0 THEN
                INSERT INTO medical.evaluation_question (template_id, question_text, question_order)
                VALUES (v_template_id, trim(question_text), q_order);
                q_order := q_order + 1;
            END IF;
        END LOOP;
    END IF;

    -- 9. 🔄 LOOP DE DOCTORES
    FOR doctor_item IN SELECT * FROM jsonb_array_elements(r_onb.doctors_list)
    LOOP
        INSERT INTO medical.specialty (name)
        VALUES (doctor_item->>'specialty')
        ON CONFLICT (name) DO NOTHING;
        
        SELECT id INTO v_specialty_id FROM medical.specialty WHERE name = doctor_item->>'specialty';

        INSERT INTO medical.doctor (first_name, last_name, clinic_id)
        VALUES (doctor_item->>'first_name', doctor_item->>'last_name', v_clinic_id) 
        RETURNING id INTO v_doctor_id;

        INSERT INTO medical.doctor_specialty (doctor_id, specialty_id, is_primary)
        VALUES (v_doctor_id, v_specialty_id, true)
        ON CONFLICT DO NOTHING;
    END LOOP;

    -- 10. Finalizar: Marcar como Completado
    UPDATE medical.clinic_onboarding
    SET onboarding_status = 'Completed', error_message = 'Clinic ID: ' || v_clinic_id
    WHERE id = p_onboarding_id;

    RETURN jsonb_build_object('success', true, 'clinic_id', v_clinic_id);

EXCEPTION WHEN OTHERS THEN
    UPDATE medical.clinic_onboarding
    SET onboarding_status = 'Error', error_message = SQLERRM
    WHERE id = p_onboarding_id;
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql;