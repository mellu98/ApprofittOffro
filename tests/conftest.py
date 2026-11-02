"""Configurazione comune dei test del backend.

Ogni test parte da un database SQLite vuoto in una cartella temporanea e senza
servizi esterni: email, push, moderazione OpenAI e chiamate di rete sono finti.
Non legge mai il file .env reale.

Lancio dalla radice del repo:
    pip install -r requirements.txt -r requirements-dev.txt
    pytest
"""
import os
import sys
import tempfile
from datetime import timedelta

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXECUTION = os.path.join(ROOT, "execution")

_TMP = tempfile.mkdtemp(prefix="approfittoffro-test-")
_EMPTY_ENV = os.path.join(_TMP, "empty.env")
open(_EMPTY_ENV, "w").close()

# Prima di importare l'app: niente .env reale, database e upload temporanei.
os.environ["APP_ENV_FILE"] = _EMPTY_ENV
os.environ["DATABASE_URL"] = "sqlite:///" + os.path.join(_TMP, "test.db")
os.environ["APP_UPLOAD_FOLDER"] = os.path.join(_TMP, "uploads")
os.environ["APP_STORAGE_BACKEND"] = "local"
os.environ["SECRET_KEY"] = "test-secret"
os.environ["GOOGLE_PLACES_API_KEY"] = "test-key"
for name in ("OPENAI_API_KEY", "RESEND_API_KEY", "MAIL_USERNAME", "MAIL_PASSWORD"):
    os.environ.pop(name, None)

if EXECUTION not in sys.path:
    sys.path.insert(0, EXECUTION)

import app as app_module  # noqa: E402
import places as places_module  # noqa: E402
from models import (  # noqa: E402
    CLAIM_STATUS_ACCEPTED,
    LEGAL_PRIVACY_VERSION,
    LEGAL_TERMS_VERSION,
    MODERATION_STATUS_APPROVED,
    Claim,
    Offer,
    User,
    db,
)

ROMA = (41.9028, 12.4964)


class _NoNetwork:
    def __call__(self, req, timeout=None):
        url = getattr(req, "full_url", req)
        raise AssertionError(f"chiamata di rete inattesa nei test: {url}")


@pytest.fixture(autouse=True)
def isolated_app(monkeypatch):
    """Database pulito e servizi esterni finti per ogni test."""
    flask_app = app_module.app
    flask_app.config.update(TESTING=True, LOGIN_DISABLED=False, WTF_CSRF_ENABLED=False)
    flask_app.config["GOOGLE_PLACES_API_KEY"] = "test-key"

    sent = {"emails": [], "pushes": []}

    def fake_email(subject, recipients, *args, **kwargs):
        sent["emails"].append({"subject": subject, "to": list(recipients or [])})
        return True

    def fake_push(user, *, title, body, target="login", extra_data=None):
        sent["pushes"].append({"user_id": getattr(user, "id", None), "title": title})
        return True

    monkeypatch.setattr(app_module, "send_email", fake_email)
    monkeypatch.setattr(app_module, "send_email_html", fake_email)
    monkeypatch.setattr(app_module, "send_push_to_user", fake_push)
    monkeypatch.setattr(
        app_module,
        "call_openai_moderation_api",
        lambda _input: ({"results": [{"flagged": False, "category_scores": {}}]}, None),
    )
    monkeypatch.setattr(app_module, "urlopen", _NoNetwork())
    monkeypatch.setattr(places_module, "urlopen", _NoNetwork())

    with flask_app.app_context():
        db.session.remove()
        for table in reversed(db.metadata.sorted_tables):
            db.session.execute(table.delete())
        db.session.commit()
        yield sent
        db.session.remove()


@pytest.fixture
def sent(isolated_app):
    return isolated_app


@pytest.fixture
def now():
    return app_module.local_now()


@pytest.fixture
def make_user(now):
    counter = {"n": 0}

    def _make(name=None, *, lat=ROMA[0], lon=ROMA[1], password="Password123!", **fields):
        counter["n"] += 1
        n = counter["n"]
        user = User(
            nome=name or f"Utente {n}",
            email=f"utente{n}@example.com",
            foto_filename=f"foto-{n}.jpg",
            fascia_eta="26-35",
            eta=30,
            latitudine=lat,
            longitudine=lon,
            numero_telefono="+39 333 0000000",
            cibi_preferiti="pizza",
            intolleranze="nessuna",
            bio="Mi piace conoscere gente nuova.",
            verificato=True,
            raggio_azione=15,
            terms_accepted_version=LEGAL_TERMS_VERSION,
            terms_accepted_at=now,
            privacy_acknowledged_version=LEGAL_PRIVACY_VERSION,
            privacy_acknowledged_at=now,
            bio_moderation_status=MODERATION_STATUS_APPROVED,
            photo_moderation_status=MODERATION_STATUS_APPROVED,
        )
        for key, value in fields.items():
            setattr(user, key, value)
        user.set_password(password)
        db.session.add(user)
        db.session.commit()
        user.test_password = password
        return user

    return _make


@pytest.fixture
def make_offer(now):
    def _make(host, *, hours_from_now=48, lat=None, lon=None, posti=3, tipo="cena", **fields):
        offer = Offer(
            user_id=host.id,
            tipo_pasto=tipo,
            nome_locale=fields.pop("nome_locale", "Trattoria di prova"),
            indirizzo=fields.pop("indirizzo", "Via Roma 1, Roma"),
            latitudine=host.latitudine if lat is None else lat,
            longitudine=host.longitudine if lon is None else lon,
            posti_totali=posti,
            posti_disponibili=fields.pop("posti_disponibili", posti),
            data_ora=now + timedelta(hours=hours_from_now),
            descrizione="Cena tra nuovi amici",
            foto_locale="locale.jpg",
            stato=fields.pop("stato", "attiva"),
            created_at=fields.pop("created_at", now - timedelta(days=3)),
        )
        for key, value in fields.items():
            setattr(offer, key, value)
        db.session.add(offer)
        db.session.commit()
        return offer

    return _make


@pytest.fixture
def make_claim():
    def _make(user, offer, status=CLAIM_STATUS_ACCEPTED):
        claim = Claim(user_id=user.id, offer_id=offer.id, status=status)
        db.session.add(claim)
        if status == CLAIM_STATUS_ACCEPTED:
            offer.posti_disponibili -= 1
        db.session.commit()
        return claim

    return _make


@pytest.fixture
def client_for():
    """Restituisce un client HTTP gia autenticato come l'utente indicato."""
    def _login(user):
        client = app_module.app.test_client()
        response = client.post(
            "/api/login",
            json={"email": user.email, "password": user.test_password},
        )
        assert response.status_code == 200, response.get_json()
        return client

    return _login


@pytest.fixture
def anon_client():
    return app_module.app.test_client()
