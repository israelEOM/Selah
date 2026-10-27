import pytest

from selah_worker import pipeline


class FakeQuery:
    def __init__(self, rows, eqs):
        self.rows, self.eqs, self.filters = rows, eqs, []

    def select(self, *_):
        return self

    def eq(self, column, value):
        self.eqs.append((column, value))
        self.filters.append((column, value))
        return self

    def limit(self, *_):
        return self

    def execute(self):
        data = [r for r in self.rows if all(r.get(c) == v for c, v in self.filters)]
        return type("R", (), {"data": data})()


class FakeClient:
    def __init__(self, tables):
        self.tables, self.eqs = tables, []

    def table(self, name):
        return FakeQuery(self.tables.get(name, []), self.eqs)


def use(monkeypatch, tables):
    fake = FakeClient(tables)
    monkeypatch.setattr(pipeline, "client", lambda: fake)
    return fake


def test_slug_is_unique_per_church(monkeypatch):
    fake = use(monkeypatch, {"studies": [{"church_id": "c2", "slug": "fe-que-obra"}]})
    assert pipeline._unique_slug("c1", "Fe que obra") == "fe-que-obra"
    assert ("church_id", "c1") in fake.eqs
    use(monkeypatch, {"studies": [{"church_id": "c1", "slug": "fe-que-obra"}]})
    assert pipeline._unique_slug("c1", "Fe que obra") == "fe-que-obra-2"


def test_run_all_rejects_unknown_church(monkeypatch):
    use(monkeypatch, {"churches": []})
    with pytest.raises(RuntimeError, match="No church with slug 'nope'"):
        pipeline.run_all("nope", "https://youtu.be/x")
