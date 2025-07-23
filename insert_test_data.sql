-- 1. Insertar location
INSERT INTO medical.location (
    id, country, city, address, created_at, updated_at
) VALUES (
    1, 'Mexico', 'Ciudad de México', 'Cuauhtémoc, 06350', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
) ON CONFLICT (id) DO NOTHING;

-- 2. Insertar clínicas
INSERT INTO medical.clinic (id, clinic_name, phone_number, status, created_at, updated_at) VALUES 
(1, 'OCAI Jerson', 5411223344, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(2, 'CLINICA DULCE', 5430099886, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(3, 'consultorio Jonatan', 573166379380, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- 3. Insertar sucursales (una por clinic_id con location_id = 1)
INSERT INTO medical.clinic_branch (id, branch_name, branch_phone_number, location_id, clinic_id, created_at, updated_at) VALUES 
(1, 'ocai sede polanco', '52001112233', 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(2, 'dulce - 1', '5522335544', 1, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(3, 'consultorio Jonatan', '573166379380', 1, 3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- 4. Insertar doctores
INSERT INTO medical.doctor (id, first_name, last_name, clinic_id, created_at, updated_at) VALUES 
(1, 'Dulce', 'Hernandez', 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(2, 'Ana', 'Reina', 3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(3, 'Angee', 'Abello Zapata', 3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(4, 'Juliana', 'Perdomo', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);


-- 5. specialty
INSERT INTO medical.specialty (id, name, description, created_at, updated_at) VALUES 
(1, 'odontologia pediatrica', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(2, 'odontologia general', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(3, 'maxilofacial', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(4, 'Periodoncia', NULL, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);


--6. doctor specialty
INSERT INTO medical.doctor_specialty (id, doctor_id, specialty_id, is_primary, created_at, updated_at) VALUES 
(1, 1, 1, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(2, 2, 1, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(3, 1, 2, FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(4, 3, 4, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(5, 4, 4, FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(6, 2, 3, FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);


-- 7. patient
INSERT INTO medical.patient (
    id, first_name, last_name, phone_number_str,
    related_party_phone_number, birth_date,
    created_at, updated_at, data_source
) VALUES 
(1, 'Jonatan', 'Polanco', '573166379380', NULL, '1999-07-29', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ai_agent'),
(2, 'Jerson', 'Correa', '525527742570', NULL, '1991-01-01', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ai_agent');


--8. chat history
INSERT INTO medical.chat_history (id, session_id, message, created_at, updated_at) VALUES
(1, '573166379380', '{"text": "hola"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(2, '573166379380', '{"text": "quiero sacar una cita"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(3, '573166379380', '{"text": "primera vez"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(4, '573166379380', '{"text": "si"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(5, '573166379380', '{"text": "Jonatan Polanco. 573166379380. 29 de julio de 1999"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(6, '573166379380', '{"text": "si"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(7, '573166379380', '{"text": "para el viernes a las 10 am por favor"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(8, '573166379380', '{"text": "si"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(9, '573166379380', '{"text": "gracias!"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(10, '525527742570', '{"text": "hola que onda wey"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(11, '525527742570', '{"text": "quiero sacar una cita carnalito me ayudas?"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(12, '525527742570', '{"text": "soy nuevo aqui"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(13, '525527742570', '{"text": "si"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(14, '525527742570', '{"text": "Jerson Correa"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(15, '525527742570', '{"text": "1991-01-01"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(16, '525527742570', '{"text": "525527742570"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(17, '525527742570', '{"text": "si"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(18, '525527742570', '{"text": "para el sabado a las 10 am por favor"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(19, '525527742570', '{"text": "si"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
(20, '525527742570', '{"text": "gracias!"}'::jsonb, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);


-- 9. appointment
INSERT INTO medical.appointment (
    id, chat_history_id, patient_id, doctor_id, clinic_id,
    appointment_timestamp, status,
    created_at, updated_at, data_source, appointment_reason
) VALUES 
(1, 1, 1, 1, 2, '2025-07-25 10:00:00', 'scheduled', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ai_agent', 'dolor de muela'),
(2, 2, 2, 3, 1, '2025-07-26 10:00:00', 'scheduled', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'ai_agent', 'revision general');

