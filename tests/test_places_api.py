"""API Places della mappa locali, con un Google finto (nessuna chiamata vera)."""
import io
import json

import pytest

import app as app_module


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class FakeGoogle:
    def __init__(self):
        self.calls = []
        self.routes = []

    def add(self, fragment, payload):
        self.routes.append((fragment, payload))

    def __call__(self, req, timeout=None):
        url = req.full_url
        body = json.loads(req.data.decode()) if req.data else None
        self.calls.append({
            "url": url,
            "body": body,
            "field_mask": req.headers.get("X-goog-fieldmask", ""),
            "api_key": req.headers.get("X-goog-api-key", ""),
        })
        for fragment, payload in self.routes:
            if fragment in url:
                data = payload(body) if callable(payload) else payload
                return FakeResponse(json.dumps(data).encode())
        raise AssertionError(f"chiamata Google inattesa: {url}")


@pytest.fixture
def google(monkeypatch):
    fake = FakeGoogle()
    monkeypatch.setattr(app_module, "urlopen", fake)
    app_module.app.config["GOOGLE_PLACES_API_KEY"] = "test-key"
    return fake


@pytest.fixture
def client(make_user, client_for):
    return client_for(make_user())


def place(pid, name, ptype, lat=45.4642, lon=9.19):
    return {
        "id": pid,
        "displayName": {"text": name},
        "formattedAddress": f"Via {name}, Milano",
        "location": {"latitude": lat, "longitude": lon},
        "primaryType": ptype,
    }


def test_food_types_include_specific_restaurants():
    f = app_module.is_google_food_place_type
    assert f("italian_restaurant")
    assert f("sushi_restaurant")
    assert f("wine_bar")
    assert f("pub")
    assert not f("barber_shop")
    assert not f("supermarket")
    # Prima "Da Gigi" (italian_restaurant) veniva scartato perche il nome non conteneva parole chiave.
    assert app_module.is_google_place_relevant("Da Gigi", "Via Roma 1, Milano", "italian_restaurant")


def test_nearby_uses_popularity_and_interleaves_groups(google, client):
    def nearby(body):
        types = body["includedTypes"]
        if "restaurant" in types:
            return {"places": [place(f"r{i}", f"Ristorante {i}", "italian_restaurant") for i in range(5)]}
        if "cafe" in types:
            return {"places": [place("c1", "Caffe Uno", "cafe"), place("r0", "Ristorante 0", "italian_restaurant")]}
        return {"places": [place("b1", "Bar Uno", "wine_bar"), place("s1", "Esselunga", "supermarket")]}

    google.add("places:searchNearby", nearby)
    res = client.get("/api/places/nearby?lat=45.46&lon=9.19&radius=15000&max_results=36")
    data = res.get_json()
    assert res.status_code == 200, data
    ids = [p["id"] for p in data["places"]]
    assert ids[:3] == ["r0", "c1", "b1"], ids  # un ristorante, un caffe, un bar
    assert "s1" not in ids  # supermercato escluso
    assert len(ids) == len(set(ids))  # niente doppioni
    bodies = [c["body"] for c in google.calls]
    assert len(bodies) == 3  # stesse 3 chiamate di prima
    assert all(b["rankPreference"] == "POPULARITY" for b in bodies)
    assert all(b["locationRestriction"]["circle"]["radius"] == 15000.0 for b in bodies)
    # Solo campi Pro nella lista: nessun costo in piu.
    assert all("rating" not in c["field_mask"] for c in google.calls)


def test_nearby_distance_mode_and_radius_cap(google, client):
    google.add("places:searchNearby", {"places": [
        place("far", "Bar Lontano", "bar", lat=45.50),
        place("near", "Bar Vicino", "bar", lat=45.4643),
    ]})
    res = client.get("/api/places/nearby?lat=45.4642&lon=9.19&radius=99999&rank=distance")
    ids = [p["id"] for p in res.get_json()["places"]]
    assert ids == ["near", "far"]
    assert google.calls[0]["body"]["rankPreference"] == "DISTANCE"
    assert google.calls[0]["body"]["locationRestriction"]["circle"]["radius"] == 20000.0


def test_autocomplete_keeps_places_and_areas_only(google, client):
    google.add("places:autocomplete", {"suggestions": [
        {"placePrediction": {"placeId": "p1", "types": ["italian_restaurant", "restaurant", "food", "establishment"],
                             "structuredFormat": {"mainText": {"text": "Trattoria da Gigi"}, "secondaryText": {"text": "Via Roma 12, Milano"}},
                             "distanceMeters": 850}},
        {"placePrediction": {"placeId": "a1", "types": ["locality", "political", "geocode"],
                             "structuredFormat": {"mainText": {"text": "Milano"}, "secondaryText": {"text": "MI, Italia"}}}},
        {"placePrediction": {"placeId": "x1", "types": ["barber_shop", "establishment"],
                             "structuredFormat": {"mainText": {"text": "Barberia Gigi"}, "secondaryText": {"text": "Milano"}}}},
        {"placePrediction": {"placeId": "g1", "types": ["food", "point_of_interest", "establishment"],
                             "structuredFormat": {"mainText": {"text": "Osteria del Ponte"}, "secondaryText": {"text": "Milano"}}}},
    ]})
    res = client.get("/api/places/autocomplete?q=gigi%20milano&lat=41.9&lon=12.5&session=abcDEF_123-x")
    data = res.get_json()
    assert res.status_code == 200, data
    got = [(s["id"], s["kind"]) for s in data["suggestions"]]
    assert got == [("p1", "place"), ("a1", "area"), ("g1", "place")]
    assert data["suggestions"][0]["distance_meters"] == 850
    body = google.calls[0]["body"]
    assert body["sessionToken"] == "abcDEF_123-x"
    assert body["includedRegionCodes"] == ["it"]
    assert body["locationBias"]["circle"]["center"] == {"latitude": 41.9, "longitude": 12.5}


def test_autocomplete_short_query_does_not_call_google(google, client):
    res = client.get("/api/places/autocomplete?q=a")
    assert res.get_json() == {"success": True, "suggestions": []}
    assert google.calls == []


def test_autocomplete_rejects_bad_session_token(google, client):
    google.add("places:autocomplete", {"suggestions": []})
    client.get("/api/places/autocomplete?q=bar&session=" + "x" * 50)
    assert "sessionToken" not in google.calls[0]["body"]


def test_details_returns_rating_hours_and_photo(google, client):
    google.add("/media", {"photoUri": "https://lh3.googleusercontent.com/foto"})
    google.add("places/p1", {
        **place("p1", "Trattoria da Gigi", "italian_restaurant"),
        "nationalPhoneNumber": "02 1234567",
        "rating": 4.6,
        "userRatingCount": 1287,
        "priceLevel": "PRICE_LEVEL_MODERATE",
        "currentOpeningHours": {"openNow": True},
        "regularOpeningHours": {"weekdayDescriptions": ["lunedì: 12:00–15:00, 19:00–23:00"]},
        "googleMapsUri": "https://maps.google.com/?cid=1",
        "photos": [{"name": "places/p1/photos/abc", "authorAttributions": [{"displayName": "Mario R."}]}],
    })
    res = client.get("/api/places/p1?session=tok123")
    data = res.get_json()
    assert res.status_code == 200, data
    p = data["place"]
    assert p["rating"] == 4.6 and p["rating_count"] == 1287
    assert p["price_level"] == 2
    assert p["open_now"] is True
    assert p["opening_hours"] == ["lunedì: 12:00–15:00, 19:00–23:00"]
    assert p["phone_number"] == "02 1234567"
    assert p["photo_url"] == "https://lh3.googleusercontent.com/foto"
    assert p["photo_author"] == "Mario R."
    details_call = next(c for c in google.calls if "places/p1?" in c["url"])
    assert "sessionToken=tok123" in details_call["url"]
    assert "rating" in details_call["field_mask"]
    photo_call = next(c for c in google.calls if "/media" in c["url"])
    assert "skipHttpRedirect=true" in photo_call["url"]
    assert "test-key" not in p["photo_url"]  # la chiave non arriva mai al telefono


def test_details_without_photo_or_rating(google, client):
    google.add("places/p2", {**place("p2", "Bar Sport", "bar")})
    p = client.get("/api/places/p2").get_json()["place"]
    assert p["rating"] is None and p["price_level"] is None and p["open_now"] is None
    assert p["photo_url"] == "" and p["opening_hours"] == []
    assert not any("/media" in c["url"] for c in google.calls)


def test_details_photo_failure_is_not_fatal(google, client):
    def broken(_body):
        raise app_module.HTTPError("u", 403, "no", {}, io.BytesIO(b"denied"))

    google.routes.append(("/media", broken))
    google.add("places/p3", {**place("p3", "Pizzeria Uno", "pizza_restaurant"),
                             "photos": [{"name": "places/p3/photos/z"}]})
    res = client.get("/api/places/p3")
    assert res.status_code == 200
    assert res.get_json()["place"]["photo_url"] == ""


def test_area_mode_returns_location_and_viewport(google, client):
    google.add("places/a1", {
        "id": "a1",
        "formattedAddress": "Milano MI, Italia",
        "location": {"latitude": 45.4642, "longitude": 9.19},
        "viewport": {"low": {"latitude": 45.38, "longitude": 9.04}, "high": {"latitude": 45.54, "longitude": 9.28}},
    })
    res = client.get("/api/places/a1?mode=area&session=tok")
    data = res.get_json()
    assert res.status_code == 200, data
    assert data["area"]["latitude"] == 45.4642
    assert data["area"]["viewport"]["north"] == 45.54
    mask = google.calls[0]["field_mask"]
    assert "displayName" not in mask and "rating" not in mask  # solo campi Essentials


def test_autocomplete_route_is_not_swallowed_by_details_route(google, client):
    google.add("places:autocomplete", {"suggestions": []})
    res = client.get("/api/places/autocomplete?q=bar")
    assert "suggestions" in res.get_json()
