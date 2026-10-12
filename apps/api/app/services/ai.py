from time import perf_counter
from openai import OpenAI
from app.core.config import settings
from app.schemas.contracts import DevotionalOutput, SermonAnalysisOutput, SummaryOutput

PROMPT_VERSION = "2026-09-1"
BASE_RULES = """Eres un asistente editorial para estudios bíblicos. Responde en español. Usa exclusivamente el transcript entregado como fuente del sermón. No inventes citas bíblicas, contenido, puntos ni palabras atribuidas al predicador. Distingue siempre la aplicación devocional generada por IA del contenido del sermón. Si no hay evidencia, omítela o márcala como incierta."""

def _client() -> OpenAI:
    if not settings.openai_api_key: raise RuntimeError("OPENAI_API_KEY no está configurada; no se puede generar contenido editorial.")
    return OpenAI(api_key=settings.openai_api_key, base_url=settings.openai_base_url)

def parse(model, instruction: str, source: str, schema):
    started = perf_counter()
    response = _client().responses.parse(model=model, input=[{"role": "system", "content": BASE_RULES + "\n" + instruction}, {"role": "user", "content": source}], text_format=schema)
    parsed = response.output_parsed
    if not parsed: raise RuntimeError("OpenAI no devolvió una salida estructurada válida.")
    usage = response.usage
    return parsed, {"input_tokens": getattr(usage, "input_tokens", None), "output_tokens": getattr(usage, "output_tokens", None), "duration": perf_counter() - started}

def analyze(transcript: str):
    return parse(settings.openai_model, "Analiza la estructura real del sermón, sus referencias explícitas o posibles y timestamps que estén respaldados por el transcript.", transcript, SermonAnalysisOutput)

def summarize(analysis: dict):
    return parse(settings.openai_model, "Redacta un resumen editorial fiel. Las aplicaciones deben estar claramente identificadas como aplicación derivada del sermón.", str(analysis), SummaryOutput)

def devotional(analysis: dict, days: int):
    return parse(settings.openai_model, f"Crea exactamente {days} devocionales, distribuidos naturalmente. Cada oración sugerida debe presentarse como material devocional generado, nunca como palabras del predicador.", str(analysis), DevotionalOutput)
