import json
import boto3
import uuid
import time
import urllib.request
import urllib.parse

def lambda_handler(event, context):
    """
    Lambda handler 100% AUTOMÁTICO
    - Acepta URLs HTTPS de S3 directamente
    - Detecta el idioma automáticamente
    - Detecta el formato automáticamente
    """

    # Si el evento viene de una URL (n8n), los datos están en 'body' como texto
    if 'body' in event and isinstance(event['body'], str):
        try:
            event = json.loads(event['body'])
        except Exception as e:
            print(f"Error parseando el body: {str(e)}")
    # -------------------------------
    
    transcribe = boto3.client('transcribe')
    
    transcribe = boto3.client('transcribe')
    s3 = boto3.client('s3')
    
    print(f"Evento recibido: {json.dumps(event)}")
    
    try:
        # Obtener audio_url (único parámetro requerido)
        audio_url = event.get('audio_url')
        
        # Idioma opcional - si no se especifica, se detecta automáticamente
        language_code = event.get('language_code')  # Puede ser None
        
        if not audio_url:
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'Debes proporcionar audio_url',
                    'success': False
                })
            }
        
        print(f"Audio URL recibida: {audio_url}")
        
        # Convertir URL HTTPS de S3 a formato s3://
        s3_uri = audio_url
        if audio_url.startswith('https://'):
            if '.s3.' in audio_url or 's3.amazonaws.com' in audio_url:
                parsed = urllib.parse.urlparse(audio_url)
                path = parsed.path.lstrip('/')
                
                # Detectar bucket del hostname o path
                if parsed.hostname.endswith('.s3.amazonaws.com') or '.s3.' in parsed.hostname:
                    # Formato: bucket.s3.region.amazonaws.com/key
                    bucket = parsed.hostname.split('.s3')[0]
                    key = path
                elif 's3.amazonaws.com' in parsed.hostname:
                    # Formato: s3.region.amazonaws.com/bucket/key
                    parts = path.split('/', 1)
                    bucket = parts[0]
                    key = parts[1] if len(parts) > 1 else ''
                else:
                    bucket = parsed.hostname.split('.')[0]
                    key = path
                
                s3_uri = f"s3://{bucket}/{key}"
                print(f"URL convertida a: {s3_uri}")
        
        # Detectar formato del archivo
        file_extension = s3_uri.split('.')[-1].split('?')[0].lower()
        
        format_mapping = {
            'ogg': 'ogg',
            'mp3': 'mp3',
            'mp4': 'mp4',
            'm4a': 'mp4',
            'wav': 'wav',
            'flac': 'flac',
            'webm': 'webm',
            'amr': 'amr'
        }
        
        media_format = format_mapping.get(file_extension, 'ogg')
        print(f"Formato detectado: {media_format}")
        
        # Verificar archivo en S3
        if s3_uri.startswith('s3://'):
            bucket_and_key = s3_uri.replace('s3://', '').split('/', 1)
            bucket = bucket_and_key[0]
            key = bucket_and_key[1] if len(bucket_and_key) > 1 else ''
            
            print(f"Verificando S3 - Bucket: {bucket}, Key: {key}")
            
            try:
                s3.head_object(Bucket=bucket, Key=key)
                print("Archivo encontrado en S3")
            except Exception as e:
                print(f"Error verificando archivo: {str(e)}")
                return {
                    'statusCode': 404,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'error': f'Archivo no encontrado en S3: {str(e)}',
                        'bucket': bucket,
                        'key': key,
                        'success': False
                    })
                }
        
        # Generar nombre único para el job
        job_name = f"transcription-{uuid.uuid4().hex[:8]}"
        print(f"Iniciando job: {job_name}")
        
        # Configurar parámetros de transcripción
        job_params = {
            'TranscriptionJobName': job_name,
            'Media': {'MediaFileUri': s3_uri},
            'MediaFormat': media_format,
            'Settings': {
                'ShowSpeakerLabels': False,
            }
        }
        
        # Si se especificó idioma, usarlo. Si no, detectar automáticamente
        if language_code:
            job_params['LanguageCode'] = language_code
            print(f"Usando idioma especificado: {language_code}")
        else:
            # Detección automática de idioma
            # AWS Transcribe soporta IdentifyLanguage para detectar automáticamente
            job_params['IdentifyLanguage'] = True
            
            # Opciones de idiomas más comunes para mejorar detección
            # Puedes agregar o quitar idiomas según tus necesidades
            job_params['LanguageOptions'] = [
                'es-ES',  # Español (España)
                'es-US',  # Español (Estados Unidos)
                'en-US',  # Inglés (Estados Unidos)
                'en-GB',  # Inglés (Reino Unido)
                'pt-BR',  # Portugués (Brasil)
                'fr-FR',  # Francés
                'de-DE',  # Alemán
                'it-IT',  # Italiano
            ]
            print(f"Detección automática de idioma activada")
        
        # Iniciar transcripción
        try:
            transcribe.start_transcription_job(**job_params)
            print(f"Job iniciado exitosamente")
        except Exception as e:
            print(f"Error iniciando job: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': f'Error iniciando transcripción: {str(e)}',
                    'success': False
                })
            }
        
        # Polling optimizado
        max_wait_time = 300  # 5 minutos
        start_time = time.time()
        wait_interval = 2
        poll_count = 0
        
        while time.time() - start_time < max_wait_time:
            poll_count += 1
            status_response = transcribe.get_transcription_job(TranscriptionJobName=job_name)
            job_status = status_response['TranscriptionJob']['TranscriptionJobStatus']
            
            print(f"Poll #{poll_count}: Status = {job_status}, Elapsed = {round(time.time() - start_time, 1)}s")
            
            if job_status == 'COMPLETED':
                transcript_uri = status_response['TranscriptionJob']['Transcript']['TranscriptFileUri']
                print(f"Transcripción completada. URI: {transcript_uri}")
                
                # Descargar resultado
                with urllib.request.urlopen(transcript_uri) as response:
                    transcript_json = json.loads(response.read().decode('utf-8'))
                
                transcript_text = transcript_json['results']['transcripts'][0]['transcript']
                processing_time = round(time.time() - start_time, 2)
                
                # Obtener el idioma detectado (si fue auto-detectado)
                detected_language = status_response['TranscriptionJob'].get('LanguageCode')
                if not detected_language and 'IdentifiedLanguageScore' in status_response['TranscriptionJob']:
                    detected_language = status_response['TranscriptionJob'].get('IdentifyLanguage')
                
                print(f"Transcripción: {transcript_text[:100]}...")
                print(f"Idioma detectado: {detected_language}")
                print(f"Tiempo total: {processing_time}s")
                
                # Limpiar el job
                try:
                    transcribe.delete_transcription_job(TranscriptionJobName=job_name)
                    print("Job limpiado")
                except:
                    pass
                
                response_data = {
                    'transcript': transcript_text,
                    'language': detected_language or language_code or 'auto-detected',
                    'processing_time': processing_time,
                    'polls': poll_count,
                    'success': True
                }
                
                # Agregar información adicional si hubo detección automática
                if 'IdentifiedLanguageScore' in status_response['TranscriptionJob']:
                    response_data['language_confidence'] = status_response['TranscriptionJob']['IdentifiedLanguageScore']
                
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps(response_data)
                }
                
            elif job_status == 'FAILED':
                failure_reason = status_response['TranscriptionJob'].get('FailureReason', 'Unknown')
                print(f"Job fallido: {failure_reason}")
                
                try:
                    transcribe.delete_transcription_job(TranscriptionJobName=job_name)
                except:
                    pass
                
                return {
                    'statusCode': 500,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({
                        'error': f'Transcription failed: {failure_reason}',
                        'success': False
                    })
                }
            
            time.sleep(wait_interval)
            wait_interval = min(wait_interval + 0.5, 5)
        
        # Timeout
        print(f"Timeout después de {max_wait_time}s")
        try:
            transcribe.delete_transcription_job(TranscriptionJobName=job_name)
        except:
            pass
            
        return {
            'statusCode': 408,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': 'Transcription timeout',
                'processing_time': round(time.time() - start_time, 2),
                'success': False
            })
        }
        
    except Exception as e:
        error_msg = str(e)
        print(f"Error general: {error_msg}")
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'error': error_msg,
                'error_type': type(e).__name__,
                'success': False
            })
        }