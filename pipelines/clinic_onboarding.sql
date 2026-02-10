DROP TABLE IF EXISTS medical.clinic_onboarding;
CREATE TABLE medical.clinic_onboarding (
    id SERIAL PRIMARY KEY,
    
    -- 1. Info General de la Clínica
    clinic_name VARCHAR(255) NOT NULL,
    clinic_phone VARCHAR(20) NOT NULL,  
    
    -- 2. Ubicación y Sede
    country VARCHAR(100) DEFAULT 'Colombia',
    city VARCHAR(100) NOT NULL,
    address TEXT NOT NULL,
    branch_name VARCHAR(255) DEFAULT 'Principal Branch',
    
    -- 3. Suscripción
    subscription_plan VARCHAR(100) DEFAULT 'Basic',
    
    -- 4. Lista de Doctores (JSON)
    doctors_list JSONB NOT NULL DEFAULT '[]'::jsonb,
    
    -- 5. Configuración de Evaluación (Nuevos campos corregidos)
    evaluation_template_name VARCHAR(255) DEFAULT 'General',
    evaluation_questions TEXT, -- Aquí se guarda el texto con \n del Excel
    
    -- 6. Horarios
    opening_time TIME DEFAULT '08:00:00',
    closing_time TIME DEFAULT '18:00:00',
    operating_days VARCHAR(50) DEFAULT '1,2,3,4,5',
    
    -- 7. Control
    onboarding_status VARCHAR(50) DEFAULT 'Pending',
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);