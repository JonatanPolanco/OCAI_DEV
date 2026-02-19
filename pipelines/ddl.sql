-- Creación del esquema médico
CREATE SCHEMA medical;
SET search_path TO medical;


-- Tabla de ubicaciones
CREATE TABLE location (
    id SERIAL PRIMARY KEY,
    country VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de clínicas
CREATE TABLE clinic (
    id SERIAL PRIMARY KEY,
    clinic_name VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    status VARCHAR(50) NOT NULL CHECK (status IN ('active', 'inactive', 'maintenance')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE clinic_subscription (
    id SERIAL PRIMARY KEY,
    clinic_id INTEGER NOT NULL REFERENCES clinic(id) ON DELETE CASCADE,
    subscription_plan VARCHAR(100) NOT NULL,  -- e.g., "Basic", "Premium", "Enterprise"
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(50) NOT NULL CHECK (status IN ('active', 'inactive', 'pending', 'cancelled')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Tabla de sucursales de clínicas
CREATE TABLE clinic_branch (
    id SERIAL PRIMARY KEY,
    branch_name VARCHAR(255) NOT NULL,
    branch_phone_number VARCHAR(20) NOT NULL,
    location_id INTEGER NOT NULL REFERENCES location(id) ON DELETE RESTRICT,
    clinic_id INTEGER NOT NULL REFERENCES clinic(id) ON DELETE CASCADE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(location_id, clinic_id)
);

-- Tabla de historial de chat
CREATE TABLE chat_history (
    id SERIAL PRIMARY KEY,  
    session_id VARCHAR(100) NOT NULL,
    message JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);



-- Tabla de pacientes
CREATE TABLE patient (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone_number_str VARCHAR(20) NOT NULL,
    related_party_phone_number VARCHAR(20),
    birth_date DATE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_source VARCHAR(100) NOT NULL DEFAULT 'ai_agent',
    UNIQUE(first_name, last_name, phone_number_str)
);


-- Tabla de doctores
CREATE TABLE doctor (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    clinic_id INTEGER NOT NULL REFERENCES clinic(id) ON DELETE RESTRICT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE medical.specialty (
    id SERIAL PRIMARY KEY,
    name VARCHAR NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);

CREATE TABLE medical.doctor_specialty (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER NOT NULL REFERENCES medical.doctor(id) ON DELETE CASCADE,
    specialty_id INTEGER NOT NULL REFERENCES medical.specialty(id) ON DELETE CASCADE,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    UNIQUE(doctor_id, specialty_id)
);

-- Tabla de citas
CREATE TABLE appointment (
    id SERIAL PRIMARY KEY,
    chat_history_id INTEGER REFERENCES chat_history(id) ON DELETE CASCADE,
    patient_id INTEGER NOT NULL REFERENCES patient(id) ON DELETE RESTRICT,
    doctor_id INTEGER NOT NULL REFERENCES doctor(id) ON DELETE RESTRICT,
    clinic_id INTEGER NOT NULL REFERENCES clinic(id) ON DELETE RESTRICT,
    appointment_timestamp TIMESTAMP NOT NULL,
    status VARCHAR(50) NOT NULL CHECK (status IN ('scheduled', 'rescheduled', 'confirmed', 'cancelled', 'completed')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_source VARCHAR(100) NOT NULL DEFAULT 'ai_agent',
    UNIQUE(patient_id, appointment_timestamp)
);


-- Tabla de facturación
CREATE TABLE patient_billing (
    id SERIAL PRIMARY KEY,
    appointment_id INTEGER NOT NULL UNIQUE REFERENCES appointment(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    status VARCHAR(50) NOT NULL CHECK (status IN ('unpaid', 'paid', 'refunded', 'disputed')),
    billing_type VARCHAR(50) NOT NULL,
    platform_name VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de plantillas de evaluación de clínicas
CREATE TABLE medical.clinic_evaluation_template (
    id SERIAL PRIMARY KEY,
    clinic_id INTEGER NOT NULL REFERENCES medical.clinic(id) ON DELETE CASCADE,
    template_name VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de preguntas de evaluación
CREATE TABLE medical.evaluation_question (
    id SERIAL PRIMARY KEY,
    template_id INTEGER NOT NULL REFERENCES medical.clinic_evaluation_template(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    question_order INTEGER NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Índice para ordenar preguntas eficientemente
CREATE INDEX idx_question_template_order ON medical.evaluation_question(template_id, question_order);

-- Tabla de respuestas a la evaluación
CREATE TABLE medical.evaluation_response (
    id SERIAL PRIMARY KEY,
    appointment_id INTEGER NOT NULL REFERENCES medical.appointment(id) ON DELETE CASCADE,
    question_id INTEGER NOT NULL REFERENCES medical.evaluation_question(id) ON DELETE RESTRICT,
    response_text TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(appointment_id, question_id)  -- Evita respuestas duplicadas para la misma pregunta
);

-- Índice para buscar todas las respuestas de una cita específica
CREATE INDEX idx_response_appointment ON medical.evaluation_response(appointment_id);


-- Tabla de horarios de atención por clínica
CREATE TABLE medical.clinic_working_hours (
    id SERIAL PRIMARY KEY,
    clinic_id INTEGER NOT NULL REFERENCES medical.clinic(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- 1=Lunes, 7=Domingo
    opening_time TIME NOT NULL,
    closing_time TIME NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraint para integridad de horarios
    CONSTRAINT valid_times CHECK (opening_time < closing_time)
);

-- Índices para consultas eficientes
CREATE INDEX idx_clinic_working_hours_clinic ON medical.clinic_working_hours(clinic_id);
CREATE INDEX idx_clinic_working_hours_day ON medical.clinic_working_hours(day_of_week);

-- Índice compuesto para consultas de disponibilidad
CREATE INDEX idx_clinic_working_hours_lookup ON medical.clinic_working_hours(clinic_id, day_of_week);

-- Constraint para evitar horarios duplicados por clínica y día
CREATE UNIQUE INDEX idx_unique_clinic_working_hours 
ON medical.clinic_working_hours(clinic_id, day_of_week);



-- Función upsert para tabla de pacientes
CREATE OR REPLACE FUNCTION upsert_patient(
    p_first_name TEXT,
    p_last_name TEXT,
    p_phone_number_str TEXT,
    p_birth_date DATE,
    p_source TEXT DEFAULT 'ai_agent'
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO medical.patient (first_name, last_name, phone_number_str, birth_date, data_source)
    VALUES (p_first_name, p_last_name, p_phone_number_str, p_birth_date, p_source)
    ON CONFLICT (phone_number_str, first_name, last_name) DO UPDATE
    SET first_name = EXCLUDED.first_name,
        last_name = EXCLUDED.last_name,
        birth_date = EXCLUDED.birth_date,
        data_source = EXCLUDED.data_source,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

CREATE UNIQUE INDEX idx_patient_phone_name ON medical.patient(phone_number_str, first_name, last_name);


-- Función upsert para tabla de citas
CREATE OR REPLACE FUNCTION medical.upsert_appointment(
    p_chat_history_id INTEGER,
    p_patient_id INTEGER,
    p_doctor_id INTEGER,
    p_clinic_id INTEGER,
    p_appointment_timestamp TIMESTAMP,
    p_appointment_reason VARCHAR(255),
    p_status VARCHAR(50),
    p_data_source TEXT DEFAULT 'ai_agent'
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO medical.appointment (
        chat_history_id, 
        patient_id, 
        doctor_id, 
        clinic_id, 
        appointment_timestamp, 
        appointment_reason,
        status, 
        data_source
    )
    VALUES (
        p_chat_history_id, 
        p_patient_id, 
        p_doctor_id, 
        p_clinic_id, 
        p_appointment_timestamp, 
        p_appointment_reason,
        p_status, 
        p_data_source
    )
    ON CONFLICT (patient_id, appointment_timestamp) DO UPDATE
    SET 
        chat_history_id = EXCLUDED.chat_history_id,
        doctor_id = EXCLUDED.doctor_id,
        clinic_id = EXCLUDED.clinic_id,
        appointment_reason = EXCLUDED.appointment_reason,
        status = EXCLUDED.status,
        data_source = EXCLUDED.data_source,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Función upsert para tabla de respuestas de evaluación
CREATE OR REPLACE FUNCTION medical.upsert_evaluation_response(
    p_appointment_id INTEGER,
    p_question_id INTEGER,
    p_response_text TEXT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO medical.evaluation_response (
        appointment_id, 
        question_id, 
        response_text
    )
    VALUES (
        p_appointment_id, 
        p_question_id, 
        p_response_text
    )
    ON CONFLICT (appointment_id, question_id) DO UPDATE
    SET 
        response_text = EXCLUDED.response_text,
        updated_at = CURRENT_TIMESTAMP;
        
    -- Automáticamente marcar la cita como evaluación completada
    UPDATE medical.appointment 
    SET evaluation_completed = TRUE
    WHERE id = p_appointment_id;
END;
$$ LANGUAGE plpgsql;




-- MVP: Función wrapper que coordina tus funciones existentes
-- Mantiene tus funciones actuales pero elimina el race condition

CREATE OR REPLACE FUNCTION medical.mvp_create_patient_appointment_evaluation(
    -- Patient data
    p_first_name TEXT,
    p_last_name TEXT,
    p_phone_number_str TEXT,
    p_birth_date DATE,
    
    -- Appointment data  
    p_appointment_timestamp TIMESTAMP,
    p_appointment_reason TEXT DEFAULT 'Consulta general',
    p_doctor_id INTEGER DEFAULT 1,
    p_clinic_id INTEGER DEFAULT 1,
    
    -- Evaluation data
    p_evaluation_responses JSONB DEFAULT NULL,
    
    -- Metadata
    p_session_id TEXT DEFAULT NULL,
    p_data_source TEXT DEFAULT 'ai_agent'
) RETURNS JSONB AS $$
DECLARE
    v_patient_id INTEGER;
    v_appointment_id INTEGER;
    v_chat_history_id INTEGER;
    v_evaluation_count INTEGER := 0;
    evaluation_item JSONB;
    result JSONB;
BEGIN
    -- PASO 1: Usar tu función existente de upsert_patient
    PERFORM medical.upsert_patient(
        p_first_name,
        p_last_name, 
        p_phone_number_str,
        p_birth_date,
        p_data_source
    );
    
    -- PASO 2: Obtener el patient_id que acabamos de crear/actualizar
    SELECT id INTO v_patient_id 
    FROM medical.patient 
    WHERE phone_number_str = p_phone_number_str 
      AND first_name = p_first_name 
      AND last_name = p_last_name
    ORDER BY updated_at DESC 
    LIMIT 1;
    
    -- Verificar que obtuvimos el patient_id
    IF v_patient_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Failed to create or find patient',
            'error_code', 'PATIENT_CREATION_FAILED'
        );
    END IF;

    -- PASO 3: Crear chat_history si se necesita
    IF p_session_id IS NOT NULL THEN
        INSERT INTO medical.chat_history (
            session_id,
            message,
            created_at,
            updated_at
        ) VALUES (
            p_session_id,
            jsonb_build_object(
                'type', 'ai',
                'text', 'Confirmación: Cita agendada para el ' || p_appointment_timestamp::text
            ),
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        ) RETURNING id INTO v_chat_history_id;
    END IF;

    -- PASO 4: Usar tu función existente de upsert_appointment
    -- Ahora tenemos patient_id garantizado, no hay race condition
    PERFORM medical.upsert_appointment(
        v_chat_history_id,
        v_patient_id, 
        p_doctor_id,
        p_clinic_id,
        p_appointment_timestamp,
        p_appointment_reason,
        'scheduled',
        p_data_source
    );
    
    -- PASO 5: Obtener el appointment_id que acabamos de crear
    SELECT id INTO v_appointment_id 
    FROM medical.appointment 
    WHERE patient_id = v_patient_id 
      AND appointment_timestamp = p_appointment_timestamp
    ORDER BY updated_at DESC 
    LIMIT 1;
    
    -- Verificar que obtuvimos el appointment_id
    IF v_appointment_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Failed to create appointment',
            'error_code', 'APPOINTMENT_CREATION_FAILED'
        );
    END IF;

    -- PASO 6: Usar tu función existente de evaluation_response
    IF p_evaluation_responses IS NOT NULL AND jsonb_array_length(p_evaluation_responses) > 0 THEN
        FOR evaluation_item IN SELECT * FROM jsonb_array_elements(p_evaluation_responses)
        LOOP
            -- Usar tu función existente
            PERFORM medical.upsert_evaluation_response(
                v_appointment_id,  -- ✅ Ahora tenemos este ID
                COALESCE((evaluation_item->>'question_id')::INTEGER, 1),
                evaluation_item->>'response_text'
            );
            
            v_evaluation_count := v_evaluation_count + 1;
        END LOOP;
    END IF;

    -- PASO 7: Retornar resultado exitoso
    result := jsonb_build_object(
        'success', true,
        'patient_id', v_patient_id,
        'appointment_id', v_appointment_id,
        'chat_history_id', v_chat_history_id,
        'evaluations_processed', v_evaluation_count,
        'message', 'MVP: Patient, appointment and evaluation processed successfully',
        'mvp_version', 'v1',
        'created_at', CURRENT_TIMESTAMP
    );
    
    RETURN result;

EXCEPTION 
    WHEN OTHERS THEN
        -- En caso de error, PostgreSQL hace rollback automático
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'error_code', SQLSTATE,
            'mvp_version', 'v1',
            'timestamp', CURRENT_TIMESTAMP
        );
END;
$$ LANGUAGE plpgsql;

-- Función auxiliar para obtener patient_id (útil para otras operaciones)
CREATE OR REPLACE FUNCTION medical.get_patient_id_by_phone_and_name(
    p_phone_number_str TEXT,
    p_first_name TEXT,
    p_last_name TEXT
) RETURNS INTEGER AS $$
DECLARE
    v_patient_id INTEGER;
BEGIN
    SELECT id INTO v_patient_id 
    FROM medical.patient 
    WHERE phone_number_str = p_phone_number_str 
      AND first_name = p_first_name 
      AND last_name = p_last_name
    ORDER BY updated_at DESC 
    LIMIT 1;
    
    RETURN v_patient_id;
END;
$$ LANGUAGE plpgsql;