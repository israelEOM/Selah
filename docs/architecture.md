# Arquitectura de Selah

```text
Next.js (web) ──JWT/cookie──> FastAPI ──> PostgreSQL
                                  │
                                  ├──> Redis / Celery ──> YouTube transcript adapter
                                  │                    ├──> OpenAI Responses structured output
                                  │                    └──> BibleProvider (reference validation + external reader link)
                                  └──> OpenAPI /docs
```

Los adaptadores externos están aislados en `apps/api/app/services`. Un fallo de YouTube no provoca una sustitución silenciosa: el administrador puede elegir otro idioma disponible o importar un transcript manualmente. Las tareas almacenan estado, modelo, versión de prompt, tokens y error; las publicaciones solo se realizan mediante una transición explícita de administrador.
