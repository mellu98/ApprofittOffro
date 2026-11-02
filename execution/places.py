"""Locali da Google Places: ricerca nella mappa, suggerimenti e dettagli.

Primo modulo staccato da app.py. Le rotte sono le stesse di prima
(/api/places/...), ora in un Blueprint registrato da app.py.

Costi Google (Places API New):
- lista dei locali (searchNearby): solo campi della SKU Pro, 3 chiamate per "Aggiorna";
- suggerimenti (autocomplete): gratis se la sessione finisce con il dettaglio del locale;
- dettaglio: SKU Enterprise (gia per il telefono), voto/prezzo/orari non costano di piu;
- foto: una chiamata Place Photos per ogni locale aperto.
"""
import json
import re
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from flask import Blueprint, current_app, jsonify, request
from flask_login import login_required

from geo import calculate_distance

places_bp = Blueprint("places", __name__)


def google_places_enabled():
    return bool(current_app.config.get("GOOGLE_PLACES_API_KEY"))


GOOGLE_PLACES_ALLOWED_PRIMARY_TYPES = {
    "restaurant",
    "cafe",
    "bar",
    "pub",
    "bakery",
    "meal_takeaway",
    "pizza_restaurant",
    "coffee_shop",
    "fast_food_restaurant",
    "brunch_restaurant",
    "breakfast_restaurant",
    "sandwich_shop",
    "cafeteria",
    "diner",
    "bistro",
    "bar_and_grill",
    "wine_bar",
    "cocktail_bar",
    "pastry_shop",
    "dessert_shop",
    "ice_cream_shop",
    "tea_house",
    "juice_shop",
    "food_court",
}

# Tipi Google che indicano una zona (citta, quartiere, via) nei suggerimenti di ricerca.
GOOGLE_PLACES_AREA_TYPES = {
    "locality",
    "sublocality",
    "sublocality_level_1",
    "neighborhood",
    "administrative_area_level_1",
    "administrative_area_level_2",
    "administrative_area_level_3",
    "postal_code",
    "route",
    "street_address",
    "premise",
}

GOOGLE_PLACES_PRICE_LEVELS = {
    "PRICE_LEVEL_FREE": 0,
    "PRICE_LEVEL_INEXPENSIVE": 1,
    "PRICE_LEVEL_MODERATE": 2,
    "PRICE_LEVEL_EXPENSIVE": 3,
    "PRICE_LEVEL_VERY_EXPENSIVE": 4,
}

GOOGLE_PLACES_INCLUDED_TYPE_GROUPS = (
    (
        "restaurant",
        "pizza_restaurant",
        "brunch_restaurant",
        "fast_food_restaurant",
    ),
    (
        "cafe",
        "coffee_shop",
        "bakery",
        "sandwich_shop",
    ),
    (
        "bar",
        "pub",
        "wine_bar",
        "meal_takeaway",
    ),
)

GOOGLE_PLACES_EXCLUDED_PRIMARY_TYPES = {
    "shopping_mall",
    "supermarket",
    "grocery_store",
    "convenience_store",
    "market",
    "store",
    "department_store",
}

GOOGLE_PLACES_EXCLUDED_KEYWORDS = (
    "centro commerciale",
    "shopping center",
    "shopping mall",
    "supermercato",
    "ipermercato",
    "minimarket",
    "market",
    "iper ",
)

GOOGLE_PLACES_MAX_RADIUS_METERS = 20000
GOOGLE_PLACES_AUTOCOMPLETE_BIAS_METERS = 30000.0


def is_google_food_place_type(place_type):
    """True per i tipi Google di bar, caffe e ristoranti (anche quelli specifici)."""
    normalized_type = (place_type or "").strip().lower()
    if not normalized_type:
        return False
    if normalized_type in GOOGLE_PLACES_ALLOWED_PRIMARY_TYPES:
        return True
    # Google usa tipi specifici come italian_restaurant, sushi_restaurant, wine_bar.
    return normalized_type.endswith("_restaurant") or normalized_type.endswith("_bar")


def is_google_place_relevant(place_name, place_address, primary_type):
    """Filtra solo i locali coerenti con colazione, pranzo e cena."""
    normalized_type = (primary_type or "").strip().lower()
    normalized_name = (place_name or "").strip().lower()
    normalized_address = (place_address or "").strip().lower()
    haystack = f"{normalized_name} {normalized_address}"

    if normalized_type in GOOGLE_PLACES_EXCLUDED_PRIMARY_TYPES:
        return False

    if any(keyword in haystack for keyword in GOOGLE_PLACES_EXCLUDED_KEYWORDS):
        return False

    if is_google_food_place_type(normalized_type):
        return True

    # Fallback prudente: alcuni locali buoni arrivano con type generico ma nome parlante.
    useful_keywords = (
        "ristor",
        "pizzer",
        "pizza",
        "bar",
        "pub",
        "caff",
        "cafeter",
        "brunch",
        "oster",
        "trattor",
        "bistrot",
        "bakery",
    )
    return any(keyword in haystack for keyword in useful_keywords)


def _google_places_api_key():
    api_key = current_app.config.get("GOOGLE_PLACES_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("Google Places non configurato.")
    return api_key


def _google_places_fetch_json(req):
    try:
        with urlopen(req, timeout=12) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        details = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"Google Places HTTP {exc.code}: {details}") from exc
    except URLError as exc:
        raise RuntimeError(f"Google Places non raggiungibile: {exc}") from exc


def _google_places_nearby_request(
    latitude,
    longitude,
    radius,
    included_types,
    max_results,
    rank_preference="POPULARITY",
):
    api_key = _google_places_api_key()

    request_url = "https://places.googleapis.com/v1/places:searchNearby"
    request_payload = {
        "includedTypes": list(included_types),
        "excludedTypes": [
            "shopping_mall",
            "supermarket",
            "grocery_store",
            "market",
            "department_store",
            "convenience_store",
        ],
        "maxResultCount": max(1, min(int(max_results), 20)),
        "locationRestriction": {
            "circle": {
                "center": {
                    "latitude": float(latitude),
                    "longitude": float(longitude),
                },
                "radius": float(
                    max(100, min(radius, GOOGLE_PLACES_MAX_RADIUS_METERS))
                ),
            }
        },
        "rankPreference": rank_preference,
        "languageCode": "it",
        "regionCode": "IT",
    }
    req = Request(
        request_url,
        data=json.dumps(request_payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "X-Goog-Api-Key": api_key,
            # Solo campi della SKU Pro: stesso costo di prima per ogni chiamata.
            "X-Goog-FieldMask": ",".join([
                "places.id",
                "places.displayName",
                "places.formattedAddress",
                "places.location",
                "places.primaryType",
            ]),
        },
        method="POST",
    )

    payload = _google_places_fetch_json(req)
    return payload.get("places", [])


def search_google_nearby_places(
    latitude,
    longitude,
    radius=7000,
    max_results=36,
    rank="popularity",
):
    """Cerca locali nella zona tramite Google Places API (New).

    Con rank="popularity" Google restituisce prima i locali piu frequentati della
    zona; i tre gruppi (ristoranti, caffe, bar) vengono alternati per non
    nascondere colazioni e aperitivi sotto i ristoranti.
    """
    rank_preference = "DISTANCE" if rank == "distance" else "POPULARITY"
    results_by_group = []
    last_error = None

    for included_types in GOOGLE_PLACES_INCLUDED_TYPE_GROUPS:
        try:
            raw_places = _google_places_nearby_request(
                latitude,
                longitude,
                radius=radius,
                included_types=included_types,
                max_results=max_results,
                rank_preference=rank_preference,
            )
        except Exception as exc:
            print(f"[GOOGLE_PLACES_GROUP_ERROR] types={included_types} error={exc}")
            last_error = exc
            continue

        group_places = []
        for place in raw_places:
            location = place.get("location") or {}
            display_name = place.get("displayName") or {}
            lat = location.get("latitude")
            lon = location.get("longitude")
            if lat is None or lon is None:
                continue
            place_name = display_name.get("text", "").strip()
            place_address = (place.get("formattedAddress") or "").strip()
            primary_type = (place.get("primaryType") or "").strip()
            if not is_google_place_relevant(place_name, place_address, primary_type):
                continue
            place_id = (place.get("id") or "").strip()
            if not place_id:
                continue
            group_places.append({
                "id": place_id,
                "name": place_name,
                "address": place_address,
                "latitude": float(lat),
                "longitude": float(lon),
                "primary_type": primary_type,
                "_distance_km": calculate_distance(
                    float(latitude),
                    float(longitude),
                    float(lat),
                    float(lon),
                ),
            })
        results_by_group.append(group_places)

    if rank_preference == "DISTANCE":
        ordered = sorted(
            (place for group in results_by_group for place in group),
            key=lambda item: (item["_distance_km"], item["name"].lower()),
        )
    else:
        # Alterna i gruppi mantenendo l'ordine di popolarita di Google.
        ordered = []
        longest = max((len(group) for group in results_by_group), default=0)
        for index in range(longest):
            for group in results_by_group:
                if index < len(group):
                    ordered.append(group[index])

    places = []
    seen_ids = set()
    limit = max(1, min(int(max_results), 60))
    for place in ordered:
        if place["id"] in seen_ids:
            continue
        seen_ids.add(place["id"])
        normalized_place = dict(place)
        normalized_place.pop("_distance_km", None)
        places.append(normalized_place)
        if len(places) >= limit:
            break

    if not places and last_error is not None:
        raise last_error

    return places


def search_google_place_suggestions(query, latitude=None, longitude=None, session_token=None):
    """Suggerimenti mentre si scrive: locali e zone (citta, quartieri, vie).

    Usa Autocomplete (New) con un session token: se la sessione si chiude con il
    dettaglio del luogo scelto, Google non fa pagare i suggerimenti.
    """
    api_key = _google_places_api_key()
    request_payload = {
        "input": query[:120],
        "languageCode": "it",
        "regionCode": "IT",
        "includedRegionCodes": ["it"],
    }
    if latitude is not None and longitude is not None:
        center = {"latitude": float(latitude), "longitude": float(longitude)}
        request_payload["locationBias"] = {
            "circle": {"center": center, "radius": GOOGLE_PLACES_AUTOCOMPLETE_BIAS_METERS}
        }
        request_payload["origin"] = center
    if session_token:
        request_payload["sessionToken"] = session_token

    req = Request(
        "https://places.googleapis.com/v1/places:autocomplete",
        data=json.dumps(request_payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "X-Goog-Api-Key": api_key,
        },
        method="POST",
    )
    payload = _google_places_fetch_json(req)

    suggestions = []
    for suggestion in payload.get("suggestions", []):
        prediction = suggestion.get("placePrediction") or {}
        place_id = (prediction.get("placeId") or "").strip()
        if not place_id:
            continue
        types = [str(item).strip().lower() for item in prediction.get("types") or []]
        structured = prediction.get("structuredFormat") or {}
        title = ((structured.get("mainText") or {}).get("text") or "").strip()
        subtitle = ((structured.get("secondaryText") or {}).get("text") or "").strip()
        if not title:
            title = ((prediction.get("text") or {}).get("text") or "").strip()
        if not title:
            continue

        if any(is_google_food_place_type(item) for item in types):
            kind = "place"
        elif any(item in GOOGLE_PLACES_AREA_TYPES for item in types):
            kind = "area"
        elif set(types) <= {"establishment", "point_of_interest", "food"} and is_google_place_relevant(title, subtitle, ""):
            # Locale con tipo generico ma nome parlante (es. "Trattoria da Gigi").
            kind = "place"
        else:
            # Negozi, uffici, scuole...: non servono per un evento.
            continue

        distance = prediction.get("distanceMeters")
        suggestions.append({
            "id": place_id,
            "kind": kind,
            "title": title,
            "subtitle": subtitle,
            "distance_meters": int(distance) if isinstance(distance, (int, float)) else None,
        })

    return suggestions


def _google_place_photo_uri(photo_name, max_width_px=640):
    """Restituisce un link temporaneo alla foto, senza esporre la chiave API."""
    api_key = _google_places_api_key()
    safe_name = quote(photo_name.strip(), safe="/")
    request_url = (
        f"https://places.googleapis.com/v1/{safe_name}/media"
        f"?maxWidthPx={int(max_width_px)}&skipHttpRedirect=true"
    )
    req = Request(request_url, headers={"X-Goog-Api-Key": api_key}, method="GET")
    payload = _google_places_fetch_json(req)
    return (payload.get("photoUri") or "").strip()


def get_google_place_location(place_id, session_token=None):
    """Posizione di una zona scelta dai suggerimenti (solo campi Essentials)."""
    api_key = _google_places_api_key()
    safe_place_id = quote(place_id.strip(), safe="")
    request_url = f"https://places.googleapis.com/v1/places/{safe_place_id}"
    if session_token:
        request_url += f"?sessionToken={quote(session_token, safe='')}"
    req = Request(
        request_url,
        headers={
            "X-Goog-Api-Key": api_key,
            "X-Goog-FieldMask": "id,formattedAddress,location,viewport",
        },
        method="GET",
    )
    payload = _google_places_fetch_json(req)
    location = payload.get("location") or {}
    viewport = payload.get("viewport") or {}
    low = viewport.get("low") or {}
    high = viewport.get("high") or {}
    result = {
        "id": payload.get("id", ""),
        "address": (payload.get("formattedAddress") or "").strip(),
        "latitude": float(location.get("latitude") or 0),
        "longitude": float(location.get("longitude") or 0),
    }
    if low and high:
        result["viewport"] = {
            "south": float(low.get("latitude") or 0),
            "west": float(low.get("longitude") or 0),
            "north": float(high.get("latitude") or 0),
            "east": float(high.get("longitude") or 0),
        }
    return result


def get_google_place_details(place_id, session_token=None):
    """Recupera dettagli mirati del locale selezionato.

    Il telefono fa gia scattare la SKU Enterprise: voto, prezzo e orari
    rientrano nella stessa SKU e non aggiungono costi.
    """
    api_key = _google_places_api_key()

    safe_place_id = quote(place_id.strip(), safe="")
    request_url = f"https://places.googleapis.com/v1/places/{safe_place_id}"
    if session_token:
        request_url += f"?sessionToken={quote(session_token, safe='')}"
    req = Request(
        request_url,
        headers={
            "X-Goog-Api-Key": api_key,
            "X-Goog-FieldMask": ",".join(
                [
                    "id",
                    "displayName",
                    "formattedAddress",
                    "location",
                    "primaryType",
                    "nationalPhoneNumber",
                    "internationalPhoneNumber",
                    "rating",
                    "userRatingCount",
                    "priceLevel",
                    "currentOpeningHours.openNow",
                    "regularOpeningHours.weekdayDescriptions",
                    "googleMapsUri",
                    "photos",
                ]
            ),
        },
        method="GET",
    )

    payload = _google_places_fetch_json(req)

    location = payload.get("location") or {}
    display_name = payload.get("displayName") or {}
    current_hours = payload.get("currentOpeningHours") or {}
    regular_hours = payload.get("regularOpeningHours") or {}
    rating = payload.get("rating")
    rating_count = payload.get("userRatingCount")

    photo_url = ""
    photo_author = ""
    photos = payload.get("photos") or []
    if photos:
        first_photo = photos[0] or {}
        photo_name = (first_photo.get("name") or "").strip()
        authors = first_photo.get("authorAttributions") or []
        if authors:
            photo_author = ((authors[0] or {}).get("displayName") or "").strip()
        if photo_name:
            try:
                photo_url = _google_place_photo_uri(photo_name)
            except Exception as exc:
                print(f"[GOOGLE_PLACE_PHOTO_ERROR] {exc}")
                photo_url = ""
                photo_author = ""

    return {
        "id": payload.get("id", ""),
        "name": display_name.get("text", "").strip(),
        "address": (payload.get("formattedAddress") or "").strip(),
        "latitude": float(location.get("latitude") or 0),
        "longitude": float(location.get("longitude") or 0),
        "primary_type": (payload.get("primaryType") or "").strip(),
        "phone_number": (
            (payload.get("nationalPhoneNumber") or "").strip()
            or (payload.get("internationalPhoneNumber") or "").strip()
        ),
        "rating": float(rating) if isinstance(rating, (int, float)) else None,
        "rating_count": int(rating_count) if isinstance(rating_count, (int, float)) else None,
        "price_level": GOOGLE_PLACES_PRICE_LEVELS.get(payload.get("priceLevel") or ""),
        "open_now": (
            bool(current_hours["openNow"])
            if isinstance(current_hours.get("openNow"), bool)
            else None
        ),
        "opening_hours": [
            str(item).strip()
            for item in regular_hours.get("weekdayDescriptions") or []
            if str(item).strip()
        ],
        "google_maps_url": (payload.get("googleMapsUri") or "").strip(),
        "photo_url": photo_url,
        "photo_author": photo_author,
    }


def _parse_optional_coordinates(raw_lat, raw_lon):
    raw_lat = (raw_lat or "").strip()
    raw_lon = (raw_lon or "").strip()
    if not raw_lat or not raw_lon:
        return None, None
    latitude = float(raw_lat.replace(",", "."))
    longitude = float(raw_lon.replace(",", "."))
    if abs(latitude) > 90 or abs(longitude) > 180:
        raise ValueError("Coordinate fuori scala.")
    return latitude, longitude


def _normalize_places_session_token(raw_value):
    token = (raw_value or "").strip()
    if not token:
        return None
    # Google accetta stringhe base64 URL-safe fino a 36 caratteri.
    if len(token) > 36 or not re.fullmatch(r"[A-Za-z0-9_-]+", token):
        return None
    return token


@places_bp.route("/api/places/nearby", methods=["GET"])
@login_required
def api_places_nearby():
    """Restituisce locali Google Places nella zona richiesta."""
    lat = request.args.get("lat", "").strip()
    lon = request.args.get("lon", "").strip()
    radius = request.args.get("radius", "7000").strip()
    max_results = request.args.get("max_results", "36").strip()
    rank = request.args.get("rank", "popularity").strip().lower()

    if not google_places_enabled():
        return jsonify({
            "success": False,
            "error": "Google Places non configurato su questo ambiente.",
        }), 503

    try:
        latitude = float(lat.replace(",", "."))
        longitude = float(lon.replace(",", "."))
        radius_m = int(float(radius.replace(",", ".")))
        max_results_value = int(float(max_results.replace(",", ".")))
    except ValueError:
        return jsonify({
            "success": False,
            "error": "Coordinate, raggio o numero risultati non validi.",
        }), 400

    try:
        places = search_google_nearby_places(
            latitude,
            longitude,
            radius=radius_m,
            max_results=max_results_value,
            rank="distance" if rank == "distance" else "popularity",
        )
    except Exception as exc:
        print(f"[GOOGLE_PLACES_ERROR] {exc}")
        return jsonify({
            "success": False,
            "error": "Impossibile recuperare i locali vicini in questo momento.",
        }), 502

    return jsonify({
        "success": True,
        "places": places,
    })


@places_bp.route("/api/places/autocomplete", methods=["GET"])
@login_required
def api_places_autocomplete():
    """Suggerimenti di locali e zone mentre l'utente scrive nella mappa."""
    if not google_places_enabled():
        return jsonify({
            "success": False,
            "error": "Google Places non configurato su questo ambiente.",
        }), 503

    query = re.sub(r"\s+", " ", request.args.get("q", "")).strip()
    if len(query) < 2:
        return jsonify({"success": True, "suggestions": []})

    try:
        latitude, longitude = _parse_optional_coordinates(
            request.args.get("lat"),
            request.args.get("lon"),
        )
    except ValueError:
        return jsonify({
            "success": False,
            "error": "Coordinate non valide.",
        }), 400

    try:
        suggestions = search_google_place_suggestions(
            query,
            latitude=latitude,
            longitude=longitude,
            session_token=_normalize_places_session_token(request.args.get("session")),
        )
    except Exception as exc:
        print(f"[GOOGLE_PLACES_AUTOCOMPLETE_ERROR] {exc}")
        return jsonify({
            "success": False,
            "error": "Ricerca non disponibile in questo momento.",
        }), 502

    return jsonify({"success": True, "suggestions": suggestions})


@places_bp.route("/api/places/<path:place_id>", methods=["GET"])
@login_required
def api_place_details(place_id):
    """Dettagli del locale scelto, oppure posizione di una zona (mode=area)."""
    if not google_places_enabled():
        return jsonify({
            "success": False,
            "error": "Google Places non configurato su questo ambiente.",
        }), 503

    safe_place_id = (place_id or "").strip()
    if not safe_place_id:
        return jsonify({
            "success": False,
            "error": "Identificativo locale mancante.",
        }), 400

    session_token = _normalize_places_session_token(request.args.get("session"))
    mode = request.args.get("mode", "").strip().lower()

    if mode == "area":
        try:
            area = get_google_place_location(safe_place_id, session_token=session_token)
        except Exception as exc:
            print(f"[GOOGLE_PLACE_AREA_ERROR] {exc}")
            return jsonify({
                "success": False,
                "error": "Impossibile trovare questa zona in questo momento.",
            }), 502
        return jsonify({"success": True, "area": area})

    try:
        place = get_google_place_details(safe_place_id, session_token=session_token)
    except Exception as exc:
        print(f"[GOOGLE_PLACE_DETAILS_ERROR] {exc}")
        return jsonify({
            "success": False,
            "error": str(exc),
        }), 502

    if not is_google_place_relevant(
        place.get("name"),
        place.get("address"),
        place.get("primary_type"),
    ):
        return jsonify({
            "success": False,
            "error": "Seleziona solo bar, ristoranti, pizzerie o pub.",
        }), 422

    return jsonify({
        "success": True,
        "place": place,
    })
