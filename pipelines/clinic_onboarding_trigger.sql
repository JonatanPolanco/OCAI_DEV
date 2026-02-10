-- 1. Función intermedia para el Trigger
CREATE OR REPLACE FUNCTION medical.trigger_launcher_onboarding()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo dispara si el estado es 'Ready' o si se acaba de insertar como 'Ready'
    -- Esto evita que corra mientras estás escribiendo a medias.
    IF NEW.onboarding_status = 'Ready' THEN
        PERFORM medical.process_clinic_onboarding(NEW.id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. El Trigger en sí (El Vigilante)
DROP TRIGGER IF EXISTS trg_run_onboarding ON medical.clinic_onboarding;

CREATE TRIGGER trg_run_onboarding
AFTER INSERT OR UPDATE OF onboarding_status
ON medical.clinic_onboarding
FOR EACH ROW
EXECUTE FUNCTION medical.trigger_launcher_onboarding();