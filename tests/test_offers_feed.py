"""Lista eventi «Approfitta»: raggio, tipo di pasto, eventi passati, eventi propri."""
from datetime import timedelta

from conftest import ROMA

# Circa 2 km e 50 km a nord di Roma centro.
VICINO = (ROMA[0] + 0.018, ROMA[1])
LONTANO = (ROMA[0] + 0.45, ROMA[1])


def _ids(response):
    assert response.status_code == 200, response.get_json()
    payload = response.get_json()
    offers = payload["offers"] if isinstance(payload, dict) else payload
    return {offer["id"] for offer in offers}


def test_radius_hides_far_events(make_user, make_offer, client_for):
    viewer, host = make_user("Spettatore"), make_user("Host")
    near = make_offer(host, lat=VICINO[0], lon=VICINO[1])
    far = make_offer(host, lat=LONTANO[0], lon=LONTANO[1])

    ids = _ids(client_for(viewer).get("/api/offers"))  # raggio del profilo: 15 km

    assert near.id in ids
    assert far.id not in ids


def test_explicit_radius_and_unlimited(make_user, make_offer, client_for):
    viewer, host = make_user("Spettatore"), make_user("Host")
    near = make_offer(host, lat=VICINO[0], lon=VICINO[1])
    far = make_offer(host, lat=LONTANO[0], lon=LONTANO[1])
    client = client_for(viewer)

    assert _ids(client.get("/api/offers?radius=1")) == set()
    assert _ids(client.get("/api/offers?radius=60")) == {near.id, far.id}
    assert _ids(client.get("/api/offers?radius=999")) == {near.id, far.id}


def test_search_center_can_be_moved(make_user, make_offer, client_for):
    viewer, host = make_user("Spettatore"), make_user("Host")
    far = make_offer(host, lat=LONTANO[0], lon=LONTANO[1])

    ids = _ids(client_for(viewer).get(f"/api/offers?radius=5&lat={LONTANO[0]}&lon={LONTANO[1]}"))

    assert ids == {far.id}


def test_own_events_stay_visible_outside_radius(make_user, make_offer, client_for):
    host = make_user("Host")
    mine = make_offer(host, lat=LONTANO[0], lon=LONTANO[1])

    assert mine.id in _ids(client_for(host).get("/api/offers?radius=5"))


def test_meal_type_filter(make_user, make_offer, client_for):
    viewer, host = make_user("Spettatore"), make_user("Host")
    dinner = make_offer(host, tipo="cena")
    breakfast = make_offer(host, tipo="colazione")

    assert _ids(client_for(viewer).get("/api/offers?tipo=colazione")) == {breakfast.id}
    assert dinner.id not in _ids(client_for(viewer).get("/api/offers?tipo=colazione"))


def test_old_and_cancelled_events_are_hidden(make_user, make_offer, make_claim, client_for):
    viewer, host, guest = make_user("Spettatore"), make_user("Host"), make_user("Ospite")
    upcoming = make_offer(host)
    old = make_offer(host, hours_from_now=-5)
    cancelled = make_offer(host, stato="annullata")
    make_claim(guest, old)

    ids = _ids(client_for(viewer).get("/api/offers"))

    assert upcoming.id in ids
    assert old.id not in ids
    assert cancelled.id not in ids


def test_events_far_apart_on_longitude(make_user, make_offer, client_for):
    """Il filtro deve valere anche in orizzontale (est-ovest), non solo nord-sud."""
    viewer, host = make_user("Spettatore"), make_user("Host")
    east = make_offer(host, lat=ROMA[0], lon=ROMA[1] + 0.6)  # circa 50 km a est

    assert east.id not in _ids(client_for(viewer).get("/api/offers?radius=15"))
    assert east.id in _ids(client_for(viewer).get("/api/offers?radius=60"))
