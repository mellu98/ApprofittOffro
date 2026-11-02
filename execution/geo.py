"""Calcoli geografici condivisi: distanze e riquadro di ricerca.

Il riquadro (bounding box) serve a far filtrare al database le righe vicine
prima di calcolare la distanza esatta in Python: si scaricano solo gli eventi
della zona invece di tutti quelli del Paese.
"""
import math

EARTH_RADIUS_KM = 6371.0
KM_PER_DEGREE_LATITUDE = 111.32


def calculate_distance(lat1, lon1, lat2, lon2):
    """Distanza in km tra due coordinate GPS (formula di Haversine)."""
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)

    dlon = lon2_rad - lon1_rad
    dlat = lat2_rad - lat1_rad

    a = math.sin(dlat / 2) ** 2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return EARTH_RADIUS_KM * c


def bounding_box(latitude, longitude, radius_km):
    """Riquadro che contiene tutto il cerchio di raggio radius_km attorno al punto.

    Restituisce (lat_min, lat_max, lon_min, lon_max), oppure None quando il
    riquadro non e utile (vicino ai poli o a cavallo del meridiano 180): in
    quel caso chi chiama deve semplicemente non filtrare.
    """
    if latitude is None or longitude is None or radius_km is None:
        return None
    try:
        latitude = float(latitude)
        longitude = float(longitude)
        radius_km = float(radius_km)
    except (TypeError, ValueError):
        return None
    if radius_km <= 0 or abs(latitude) > 90 or abs(longitude) > 180:
        return None

    # Un piccolo margine evita di scartare punti proprio sul bordo per arrotondamenti.
    padded_km = radius_km * 1.01 + 0.05
    delta_lat = padded_km / KM_PER_DEGREE_LATITUDE
    lat_min = latitude - delta_lat
    lat_max = latitude + delta_lat
    if lat_min <= -90 or lat_max >= 90:
        return None

    cos_lat = math.cos(math.radians(max(abs(lat_min), abs(lat_max))))
    if cos_lat <= 0.01:
        return None
    delta_lon = padded_km / (KM_PER_DEGREE_LATITUDE * cos_lat)
    lon_min = longitude - delta_lon
    lon_max = longitude + delta_lon
    if lon_min < -180 or lon_max > 180:
        return None

    return lat_min, lat_max, lon_min, lon_max
