"""Richieste di partecipazione: invio, accettazione, rifiuto, annullamento."""
from datetime import timedelta

from models import (
    CLAIM_STATUS_ACCEPTED,
    CLAIM_STATUS_PENDING,
    CLAIM_STATUS_REJECTED,
    Claim,
    Offer,
    db,
)


def _offer(offer_id):
    db.session.expire_all()
    return db.session.get(Offer, offer_id)


def test_request_is_pending_and_does_not_take_a_seat(make_user, make_offer, client_for, sent):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, posti=2)

    res = client_for(guest).post(f"/api/offers/{offer.id}/claim")

    assert res.status_code == 200, res.get_json()
    assert res.get_json()["claim_status"] == "pending"
    claim = Claim.query.filter_by(user_id=guest.id, offer_id=offer.id).one()
    assert claim.status == CLAIM_STATUS_PENDING
    assert _offer(offer.id).posti_disponibili == 2  # il posto si occupa solo all'accettazione


def test_host_accepts_and_last_seat_closes_the_event(make_user, make_offer, make_claim, client_for):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, posti=1)
    claim = make_claim(guest, offer, status=CLAIM_STATUS_PENDING)

    res = client_for(host).post(f"/api/claims/{claim.id}/accept")

    assert res.status_code == 200, res.get_json()
    offer = _offer(offer.id)
    assert offer.posti_disponibili == 0
    assert offer.stato == "completata"
    assert db.session.get(Claim, claim.id).status == CLAIM_STATUS_ACCEPTED


def test_only_the_host_can_accept(make_user, make_offer, make_claim, client_for):
    host, guest, other = make_user("Host"), make_user("Ospite"), make_user("Altro")
    offer = make_offer(host)
    claim = make_claim(guest, offer, status=CLAIM_STATUS_PENDING)

    res = client_for(other).post(f"/api/claims/{claim.id}/accept")

    assert res.status_code == 403
    assert db.session.get(Claim, claim.id).status == CLAIM_STATUS_PENDING


def test_cannot_request_own_offer(make_user, make_offer, client_for):
    host = make_user("Host")
    offer = make_offer(host)

    res = client_for(host).post(f"/api/offers/{offer.id}/claim")

    assert res.status_code == 400
    assert Claim.query.count() == 0


def test_cannot_request_twice_or_after_rejection(make_user, make_offer, make_claim, client_for):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host)
    guest_client = client_for(guest)

    assert guest_client.post(f"/api/offers/{offer.id}/claim").status_code == 200
    assert guest_client.post(f"/api/offers/{offer.id}/claim").status_code == 400

    claim = Claim.query.filter_by(user_id=guest.id).one()
    assert client_for(host).post(f"/api/claims/{claim.id}/reject").status_code == 200
    assert guest_client.post(f"/api/offers/{offer.id}/claim").status_code == 400


def test_full_event_refuses_requests(make_user, make_offer, client_for):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, posti=2, posti_disponibili=0, stato="completata")

    res = client_for(guest).post(f"/api/offers/{offer.id}/claim")

    assert res.status_code == 400


def test_booking_window_closes_six_hours_before_dinner(make_user, make_offer, client_for):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, hours_from_now=4, tipo="cena")

    res = client_for(guest).post(f"/api/offers/{offer.id}/claim")

    assert res.status_code == 400
    assert Claim.query.count() == 0


def test_breakfast_window_is_one_hour(make_user, make_offer, client_for):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, hours_from_now=3, tipo="colazione")

    assert client_for(guest).post(f"/api/offers/{offer.id}/claim").status_code == 200


def test_premium_can_request_last_minute(make_user, make_offer, client_for, now):
    host = make_user("Host")
    premium = make_user("Premium", premium_until=now + timedelta(days=30))
    offer = make_offer(host, hours_from_now=4, tipo="cena")

    res = client_for(premium).post(f"/api/offers/{offer.id}/claim")

    assert res.status_code == 200, res.get_json()
    assert "last minute" in res.get_json()["message"].lower()


def test_started_event_refuses_requests(make_user, make_offer, client_for):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, hours_from_now=-1)

    assert client_for(guest).post(f"/api/offers/{offer.id}/claim").status_code == 400


def test_cancelling_a_pending_request_just_removes_it(make_user, make_offer, make_claim, client_for, sent):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, posti=2)
    claim = make_claim(guest, offer, status=CLAIM_STATUS_PENDING)

    res = client_for(guest).delete(f"/api/claims/{claim.id}")

    assert res.status_code == 200
    assert Claim.query.count() == 0
    assert _offer(offer.id).posti_disponibili == 2
    assert sent["emails"] == []


def test_cancelling_an_accepted_seat_frees_it_and_reopens_the_event(make_user, make_offer, make_claim, client_for, sent):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, posti=1)
    claim = make_claim(guest, offer)
    offer.stato = "completata"
    db.session.commit()

    res = client_for(guest).delete(f"/api/claims/{claim.id}")

    assert res.status_code == 200
    offer = _offer(offer.id)
    assert offer.posti_disponibili == 1
    assert offer.stato == "attiva"
    assert host.email in [to for email in sent["emails"] for to in email["to"]]


def test_deleting_a_rejected_request_does_not_create_a_seat(make_user, make_offer, make_claim, client_for, sent):
    """Una richiesta rifiutata non ha mai occupato un posto: cancellarla non deve liberarne uno."""
    host, accepted, rejected = make_user("Host"), make_user("Accettato"), make_user("Rifiutato")
    offer = make_offer(host, posti=1)
    make_claim(accepted, offer)  # evento pieno
    offer.stato = "completata"
    db.session.commit()
    rejected_claim = make_claim(rejected, offer, status=CLAIM_STATUS_REJECTED)

    res = client_for(rejected).delete(f"/api/claims/{rejected_claim.id}")

    assert res.status_code == 400
    offer = _offer(offer.id)
    assert offer.posti_disponibili == 0
    assert offer.stato == "completata"
    assert db.session.get(Claim, rejected_claim.id) is not None  # non puo richiedere di nuovo
    assert sent["emails"] == [] and sent["pushes"] == []


def test_guest_cannot_cancel_someone_elses_claim(make_user, make_offer, make_claim, client_for):
    host, guest, other = make_user("Host"), make_user("Ospite"), make_user("Altro")
    offer = make_offer(host)
    claim = make_claim(guest, offer)

    assert client_for(other).delete(f"/api/claims/{claim.id}").status_code == 403
    assert db.session.get(Claim, claim.id) is not None
