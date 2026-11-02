"""Controllo di salute usato da Render (healthCheckPath)."""


def test_healthz_reports_database_ok(anon_client):
    res = anon_client.get("/healthz")

    assert res.status_code == 200
    assert res.get_json() == {"ok": True, "database": True}
