import tempfile
from pathlib import Path

import pytest

from app import create_app


@pytest.fixture()
def client():
    with tempfile.TemporaryDirectory() as directory:
        app = create_app({"TESTING": True, "SECRET_KEY": "test", "DATABASE": str(Path(directory) / "test.db")})
        yield app.test_client()


def csrf(client):
    client.get("/")
    with client.session_transaction() as session:
        return session["csrf_token"]


def test_public_pages_and_health(client):
    assert client.get("/").status_code == 200
    movies = client.get("/movies")
    shows = client.get("/tv_shows")
    assert movies.status_code == 200
    assert shows.status_code == 200
    assert b"Inception" in movies.data
    assert b"Breaking Bad" in shows.data
    assert client.get("/health").json == {"status": "ok"}


def test_register_login_and_member_actions(client):
    token = csrf(client)
    response = client.post("/register", data={
        "csrf_token": token, "username": "filmfan", "email": "fan@example.com", "password": "movies123"
    })
    assert response.status_code == 302
    response = client.post("/login", data={"csrf_token": token, "identity": "filmfan", "password": "movies123"})
    assert response.status_code == 302
    with client.session_transaction() as session:
        token = session["csrf_token"]
    assert client.post("/api/watchlist/1", headers={"X-CSRF-Token": token}).json["saved"] is True
    assert client.post("/api/history/1", headers={"X-CSRF-Token": token}).json["success"] is True
    assert client.get("/mylist").status_code == 200
