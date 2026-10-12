import re
from urllib.parse import urlencode
from app.core.config import settings

class BibleProvider:
    async def versions(self): raise NotImplementedError
    async def validate(self, reference: str, version_id: str | None): raise NotImplementedError

class ExternalReaderProvider(BibleProvider):
    """Reference-only provider: it never retrieves, caches, or redistributes Bible text."""
    async def versions(self):
        return [{"code": "RVR1960", "name": "Reina-Valera 1960", "language": "es"}]

    async def validate(self, reference: str, version_id: str | None):
        valid = syntactically_valid(reference)
        translation = version_id or "RVR1960"
        query = urlencode({"search": reference, "version": translation})
        return {
            "valid": valid,
            "verification_status": "VERIFIED_FORMAT" if valid else "REVIEW_REQUIRED",
            "external_url": f"{settings.bible_external_reader_base_url}?{query}",
            "text_available_in_selah": False,
            "notice": "Selah muestra la referencia y abre la lectura bíblica en el proveedor externo; no almacena texto bíblico.",
        }

provider = ExternalReaderProvider()
BOOK_RE = re.compile(r"^(?:[1-3]\s)?[A-Za-zÁÉÍÓÚáéíóúÑñ]+(?:\s[A-Za-zÁÉÍÓÚáéíóúÑñ]+)*\s\d+(?::\d+(?:-\d+)?)?$")
def syntactically_valid(reference: str) -> bool: return bool(BOOK_RE.match(reference.strip()))
