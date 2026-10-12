# Selah — La Palabra que permanece

Selah convierte predicaciones de YouTube en estudios bíblicos y devocionales revisables por la iglesia. La aplicación conserva el vínculo con el transcript y sus marcas de tiempo; la IA no sustituye la revisión editorial ni reconstruye texto bíblico protegido.

## Qué incluye este MVP

- Importación de URLs `youtube.com/watch`, `youtube.com/live` y `youtu.be`, con metadatos públicos y selección explícita del intervalo.
- Recuperación asíncrona de subtítulos con `youtube-transcript-api`; alternativa manual para TXT/SRT/VTT. TXT sin tiempos informa que se desactivan enlaces por momento.
- Pipeline Celery: transcript → análisis estructurado de OpenAI → extracción y comprobación sintáctica de referencias → resumen → devocional de 1, 3, 5 o 7 días.
- Modelos Pydantic de salida, prompts versionados, trazabilidad de modelo/tokens/trabajo y protección contra trabajos duplicados en curso.
- Integración bíblica inicial sin API: Selah valida el formato de la referencia y abre RVR1960 en un lector externo. No busca, copia, almacena ni redistribuye el texto bíblico.
- Login con contraseña cifrada, cookie HttpOnly/JWT, autorización de administrador en servidor, estudios pendientes de aprobación, progreso y notas privadas persistentes.
- Interfaz móvil en español con la identidad Selah: verde profundo, crema y dorado suave.

## Puesta en marcha

1. Copia `.env.example` a `.env` y reemplaza contraseñas y claves. Para crear el primer administrador configura `BOOTSTRAP_ADMIN_EMAIL` y `BOOTSTRAP_ADMIN_PASSWORD` antes del primer arranque.
2. Ejecuta `docker compose up --build`.
3. Opcional pero recomendado en producción: `docker compose exec api alembic upgrade head`.
4. Abre [http://localhost:3000](http://localhost:3000), inicia sesión y entra en **Administrar**.

La documentación OpenAPI está disponible en [http://localhost:8000/docs](http://localhost:8000/docs).

## Variables relevantes

| Variable | Propósito |
| --- | --- |
| `OPENAI_API_KEY` / `OPENAI_MODEL` | Respuestas estructuradas de OpenAI; `gpt-4.1` por defecto. Evalúa modelos más recientes con sermones reales antes de cambiar el valor. |
| `BIBLE_EXTERNAL_READER_BASE_URL` | Lector externo al que Selah enlaza las referencias RVR1960. El valor predeterminado es BibleGateway. |
| `YOUTUBE_API_KEY` | Opcional, para duración/fecha oficiales y validación completa del intervalo. Sin ella se usan metadatos públicos y el administrador debe confirmar el límite final. |
| `DATABASE_URL`, `REDIS_URL` | Persistencia PostgreSQL y cola Celery. |
| `API_SECRET_KEY`, `CORS_ORIGINS` | Seguridad de sesión y origen del cliente. |

## Referencias bíblicas y licencia

Durante el MVP, RVR1960 se usa solamente como una referencia de traducción: la aplicación muestra la cita y abre el texto en un lector externo. No se almacena el texto bíblico ni se pide a la IA que lo reconstruya. Las citas breves, si se añaden editorialmente, deben respetar los límites y la atribución de Sociedades Bíblicas Unidas. Una futura integración de texto completo deberá pasar revisión de licencia antes de habilitarse.

## Pruebas

Con dependencias de API instaladas: `cd apps/api && pytest`.

Las pruebas automáticas no llaman a YouTube, OpenAI ni API.Bible. Para probar proveedores reales, configura las credenciales y usa un video propio con subtítulos disponibles. No hay descarga de audio ni Whisper en este MVP.

## Operación y despliegue

Usa PostgreSQL administrado y Redis duradero en producción, aplica Alembic antes de desplegar código y realiza copias de seguridad regulares de PostgreSQL. Mantén las claves en un gestor de secretos. Configure HTTPS antes de cambiar `secure=False` de la cookie de desarrollo a `secure=True`; la protección CSRF debe acompañar cualquier autenticación basada exclusivamente en cookies en un dominio separado.

El contenido generado se guarda como borrador: solo `POST /studies/{id}/publish` por un administrador lo expone a miembros. Revise las referencias con estado `REVIEW_REQUIRED`, las citas y las aplicaciones antes de publicar.
