"""Riquadro geografico: il database scarta gli eventi lontani prima del calcolo esatto."""
import pytest

import app as app_module
from conftest import ROMA
from geo import bounding_box, calculate_distance
from models import DevicePushToken, db

LONTANO = (ROMA[0] + 0.45, ROMA[1])  # circa 50 km


def test_distance_roma_milano():
    assert calculate_distance(41.9028, 12.4964, 45.4642, 9.19) == pytest.approx(477, abs=5)


@pytest.mark.parametrize("radius_km", [1, 5, 15, 60, 300])
@pytest.mark.parametrize("bearing", [(1, 0), (-1, 0), (0, 1), (0, -1), (0.7, 0.7), (-0.7, -0.7)])
def test_box_contains_every_point_of_the_circle(radius_km, bearing):
    lat0, lon0 = 45.4642, 9.19
    lat_min, lat_max, lon_min, lon_max = bounding_box(lat0, lon0, radius_km)
    # Cerca il punto a esattamente radius_km nella direzione indicata.
    step = 0.0005
    lat, lon = lat0, lon0
    while calculate_distance(lat0, lon0, lat, lon) < radius_km:
        lat += bearing[0] * step
        lon += bearing[1] * step
    assert lat_min <= lat <= lat_max
    assert lon_min <= lon <= lon_max


def test_box_is_skipped_where_it_would_be_wrong():
    assert bounding_box(89.9, 0, 50) is None  # polo
    assert bounding_box(0, 179.9, 50) is None  # meridiano 180
    assert bounding_box(45, 9, None) is None
    assert bounding_box(None, 9, 10) is None


def test_far_offers_are_not_loaded_from_the_database(make_user, make_offer, client_for, monkeypatch):
    viewer, host = make_user("Spettatore"), make_user("Host")
    near = make_offer(host)
    far = make_offer(host, lat=LONTANO[0], lon=LONTANO[1])
    mine_far = make_offer(viewer, lat=LONTANO[0], lon=LONTANO[1])

    loaded = []
    original = app_module.filter_visible_offers_and_notify_empty_started_hosts

    def spy(offers, **kwargs):
        loaded.extend(offer.id for offer in offers)
        return original(offers, **kwargs)

    monkeypatch.setattr(app_module, "filter_visible_offers_and_notify_empty_started_hosts", spy)
    res = client_for(viewer).get("/api/offers?radius=15")

    assert res.status_code == 200
    assert near.id in loaded
    assert mine_far.id in loaded  # i propri eventi restano sempre
    assert far.id not in loaded


def test_nearby_push_users_use_the_box(make_user, make_offer):
    host = make_user("Host")
    near_user = make_user("Vicino")
    far_user = make_user("Lontano", lat=LONTANO[0], lon=LONTANO[1])
    for user in (near_user, far_user):
        db.session.add(DevicePushToken(user_id=user.id, token=f"token-{user.id}", platform="android", active=True))
    db.session.commit()
    offer = make_offer(host)

    users = app_module.get_nearby_active_push_users(offer, radius_km=20)

    assert [user.id for user in users] == [near_user.id]
