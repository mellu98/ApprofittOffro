"""Recensioni dopo il pasto e ApprofittOffro Points delle segnalazioni bug."""
from models import (
    BUG_REPORT_STATUS_APPROVED,
    BUG_REPORT_STATUS_PENDING,
    BugReport,
    Review,
    User,
    db,
)


def _review(client, offer, reviewed, rating=5, commento="Serata bellissima"):
    return client.post(
        "/api/reviews",
        json={
            "offer_id": offer.id,
            "reviewed_id": reviewed.id,
            "rating": rating,
            "commento": commento,
        },
    )


def test_guest_reviews_host_after_the_meal(make_user, make_offer, make_claim, client_for):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, hours_from_now=-4)
    make_claim(guest, offer)

    res = _review(client_for(guest), offer, host)

    assert res.status_code == 200, res.get_json()
    review = Review.query.one()
    assert (review.reviewer_id, review.reviewed_id, review.rating) == (guest.id, host.id, 5)


def test_host_reviews_guest(make_user, make_offer, make_claim, client_for):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, hours_from_now=-4)
    make_claim(guest, offer)

    assert _review(client_for(host), offer, guest, rating=4).status_code == 200


def test_review_waits_three_hours_after_start(make_user, make_offer, make_claim, client_for):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, hours_from_now=-1)
    make_claim(guest, offer)

    assert _review(client_for(guest), offer, host).status_code == 400
    assert Review.query.count() == 0


def test_only_participants_can_review(make_user, make_offer, client_for):
    host, stranger = make_user("Host"), make_user("Estraneo")
    offer = make_offer(host, hours_from_now=-4)

    assert _review(client_for(stranger), offer, host).status_code == 403


def test_cannot_review_yourself(make_user, make_offer, client_for):
    host = make_user("Host")
    offer = make_offer(host, hours_from_now=-4)

    assert _review(client_for(host), offer, host).status_code == 400


def test_second_review_updates_the_first(make_user, make_offer, make_claim, client_for):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, hours_from_now=-4)
    make_claim(guest, offer)
    guest_client = client_for(guest)

    _review(guest_client, offer, host, rating=2)
    _review(guest_client, offer, host, rating=5, commento="Ripensandoci, ottima")

    assert Review.query.count() == 1
    assert Review.query.one().rating == 5


def test_rating_must_be_between_one_and_five(make_user, make_offer, make_claim, client_for):
    host, guest = make_user("Host"), make_user("Ospite")
    offer = make_offer(host, hours_from_now=-4)
    make_claim(guest, offer)

    assert _review(client_for(guest), offer, host, rating=6).status_code == 400


def _bug_report(user):
    report = BugReport(user_id=user.id, message="Il tasto non risponde", status=BUG_REPORT_STATUS_PENDING)
    db.session.add(report)
    db.session.commit()
    return report


def test_admin_awards_points_once_and_can_change_them(make_user, client_for):
    admin = make_user("Admin", is_admin=True)
    reporter = make_user("Segnalatore")
    report = _bug_report(reporter)
    admin_client = client_for(admin)
    url = f"/api/admin/bug-reports/{report.id}/review"

    res = admin_client.post(url, json={"status": BUG_REPORT_STATUS_APPROVED, "points": 20})
    assert res.status_code == 200, res.get_json()
    assert res.get_json()["user_points"] == 20

    # Rivedere la stessa segnalazione sostituisce i punti, non li somma.
    res = admin_client.post(url, json={"status": BUG_REPORT_STATUS_APPROVED, "points": 30})
    assert res.get_json()["user_points"] == 30

    res = admin_client.post(url, json={"status": "rejected"})
    assert res.get_json()["user_points"] == 0
    db.session.expire_all()
    assert db.session.get(User, reporter.id).approfittoffro_points == 0


def test_points_are_capped_and_need_a_positive_value(make_user, client_for):
    admin = make_user("Admin", is_admin=True)
    report = _bug_report(make_user("Segnalatore"))
    admin_client = client_for(admin)
    url = f"/api/admin/bug-reports/{report.id}/review"

    assert admin_client.post(url, json={"status": BUG_REPORT_STATUS_APPROVED, "points": 0}).status_code == 400
    res = admin_client.post(url, json={"status": BUG_REPORT_STATUS_APPROVED, "points": 9999})
    assert res.get_json()["user_points"] == 500


def test_only_admins_award_points(make_user, client_for):
    report = _bug_report(make_user("Segnalatore"))
    intruder = make_user("Intruso")

    res = client_for(intruder).post(
        f"/api/admin/bug-reports/{report.id}/review",
        json={"status": BUG_REPORT_STATUS_APPROVED, "points": 100},
    )

    assert res.status_code == 403
