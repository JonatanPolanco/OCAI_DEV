"""
Script para probar la Lambda localmente antes de deployar
"""
import json
import os
from datetime import datetime

# Cargar variables de entorno desde .env
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    print("⚠️  python-dotenv no instalado, usando variables de sistema")

# Importar Lambda
from lambda_appointment_store import lambda_handler


class MockContext:
    """Mock del contexto de Lambda"""
    request_id = f"test_{datetime.now().strftime('%Y%m%d%H%M%S')}"
    function_name = "test-local"
    memory_limit_in_mb = 256
    invoked_function_arn = "arn:aws:lambda:local:test"


def test_create_appointment():
    """Test de creación de cita exitosa"""
    print("\n=== Test 1: Crear cita completa ===")

    event = {
        'body': json.dumps({
            'first_name': 'Juan',
            'last_name': 'Pérez',
            'phone': '+573001234567',
            'birth_date': '1990-05-15',
            'appointment_date': '2026-03-01',
            'appointment_time': '14:30',
            'appointment_reason': 'Consulta general',
            'doctor_id': 1,
            'clinic_id': 1,
            'self_evaluation': 'Me duele la cabeza desde hace 3 días',
            'sessionId': 'test_session_123'
        })
    }

    result = lambda_handler(event, MockContext())

    print(f"Status Code: {result['statusCode']}")
    print(f"Response: {json.dumps(json.loads(result['body']), indent=2)}")

    return result['statusCode'] == 200


def test_minimal_appointment():
    """Test con datos mínimos requeridos"""
    print("\n=== Test 2: Cita con datos mínimos ===")

    event = {
        'body': json.dumps({
            'first_name': 'María',
            'last_name': 'González',
            'phone': '3109876543',  # Sin +, debería agregar +57
            'appointment_date': '2026-03-02',
            'appointment_time': '10:00'
        })
    }

    result = lambda_handler(event, MockContext())

    print(f"Status Code: {result['statusCode']}")
    print(f"Response: {json.dumps(json.loads(result['body']), indent=2)}")

    return result['statusCode'] == 200


def test_invalid_data():
    """Test con datos inválidos"""
    print("\n=== Test 3: Datos inválidos (sin first_name) ===")

    event = {
        'body': json.dumps({
            'last_name': 'Test',
            'phone': '+573001234567'
        })
    }

    result = lambda_handler(event, MockContext())

    print(f"Status Code: {result['statusCode']}")
    print(f"Response: {json.dumps(json.loads(result['body']), indent=2)}")

    return result['statusCode'] == 400


def test_phone_sanitization():
    """Test de sanitización de teléfonos"""
    print("\n=== Test 4: Sanitización de teléfonos ===")

    phones = [
        '+57 300 123 4567',
        '300-123-4567',
        '(300) 123-4567',
        '3001234567'
    ]

    for phone in phones:
        event = {
            'body': json.dumps({
                'first_name': 'Test',
                'last_name': 'Phone',
                'phone': phone,
                'appointment_date': '2026-03-03',
                'appointment_time': '11:00'
            })
        }

        result = lambda_handler(event, MockContext())
        body = json.loads(result['body'])

        print(f"Input: {phone:20} → Success: {body.get('success', False)}")


def run_all_tests():
    """Ejecutar todos los tests"""
    print("=" * 60)
    print("Testing Lambda Appointment Store - Local")
    print("=" * 60)

    # Verificar variables de entorno
    required_vars = ['DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASSWORD']
    missing = [var for var in required_vars if not os.getenv(var)]

    if missing:
        print(f"\n❌ Error: Variables de entorno faltantes: {', '.join(missing)}")
        print("Crear archivo .env con las credenciales de RDS")
        return

    print("\n✓ Variables de entorno configuradas")

    # Ejecutar tests
    tests = [
        ("Test 1: Crear cita completa", test_create_appointment),
        ("Test 2: Datos mínimos", test_minimal_appointment),
        ("Test 3: Datos inválidos", test_invalid_data),
        ("Test 4: Sanitización", test_phone_sanitization),
    ]

    results = []
    for name, test_func in tests:
        try:
            success = test_func()
            results.append((name, success))
        except Exception as e:
            print(f"\n❌ {name} falló con error: {str(e)}")
            results.append((name, False))

    # Resumen
    print("\n" + "=" * 60)
    print("Resumen de Tests")
    print("=" * 60)
    for name, success in results:
        status = "✓" if success else "✗"
        print(f"{status} {name}")

    passed = sum(1 for _, s in results if s)
    total = len(results)
    print(f"\nTests pasados: {passed}/{total}")


if __name__ == "__main__":
    run_all_tests()
