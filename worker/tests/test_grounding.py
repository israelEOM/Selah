from selah_worker.grounding import locate, window_end, window_start

WINDOWS = [
    {"index": 0, "start": 0.0, "text": "Buenos días hermanos, vamos a abrir la Biblia en segunda de Reyes"},
    {"index": 1, "start": 30.0, "text": "Dios está trabajando incluso cuando no lo vemos, y eso"},
    {"index": 2, "start": 60.0, "text": "nos llena de esperanza en medio de la prueba más difícil"},
]


def test_finds_exact_quote_ignoring_accents_and_punctuation():
    assert locate("Dios esta trabajando, incluso cuando no lo vemos.", WINDOWS, near=0) == 1


def test_finds_quote_that_straddles_two_windows():
    assert locate("cuando no lo vemos, y eso nos llena de esperanza", WINDOWS, near=None) == 1


def test_rejects_invented_quote():
    assert locate("La fe mueve montañas si creemos de todo corazón", WINDOWS, near=1) is None


def test_window_times():
    assert window_start(WINDOWS, 1) == 30.0
    assert window_end(WINDOWS, 1) == 60.0
    assert window_end(WINDOWS, 2) is None
    assert window_start(WINDOWS, 99) is None
