"""Cinephile — a small, production-shaped Flask application.

SQLite is the zero-configuration default. Set DATABASE_URL to a sqlite path if
you want the database elsewhere (for example: sqlite:////data/cinephile.db).
"""
from __future__ import annotations

import os
import re
import secrets
import sqlite3
from datetime import date
from functools import wraps
from pathlib import Path
from urllib.parse import urlparse

from flask import (
    Flask, abort, flash, g, jsonify, redirect, render_template, request,
    session, url_for,
)
from werkzeug.security import check_password_hash, generate_password_hash

BASE_DIR = Path(__file__).resolve().parent


def create_app(test_config: dict | None = None) -> Flask:
    app = Flask(__name__)
    app.config.from_mapping(
        SECRET_KEY=os.getenv("SECRET_KEY") or secrets.token_hex(32),
        DATABASE=_database_path(),
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
        SESSION_COOKIE_SECURE=os.getenv("COOKIE_SECURE", "false").lower() == "true",
        MAX_CONTENT_LENGTH=1 * 1024 * 1024,
    )
    if test_config:
        app.config.update(test_config)

    app.teardown_appcontext(close_db)
    app.cli.command("init-db")(init_db_command)

    @app.before_request
    def ensure_database_and_csrf() -> None:
        init_db()
        session.setdefault("csrf_token", secrets.token_urlsafe(24))
        if request.method in {"POST", "PUT", "PATCH", "DELETE"}:
            token = request.form.get("csrf_token") or request.headers.get("X-CSRF-Token")
            if not token or not secrets.compare_digest(token, session["csrf_token"]):
                abort(400, "Invalid or missing CSRF token")

    @app.context_processor
    def template_helpers() -> dict:
        return {"csrf_token": lambda: session.get("csrf_token", ""), "current_year": date.today().year}

    @app.get("/")
    def home():
        featured = query_all("""
            SELECT c.*, g.name AS genre_name FROM content c
            JOIN genres g ON g.id = c.genre_id
            WHERE c.featured = 1 ORDER BY c.rating DESC LIMIT 5
        """)
        trending = query_all("""
            SELECT c.*, g.name AS genre_name FROM content c
            JOIN genres g ON g.id = c.genre_id
            ORDER BY c.rating DESC, c.release_date DESC LIMIT 8
        """)
        return render_template("index.html", featured=featured, trending=trending)

    @app.route("/register", methods=["GET", "POST"])
    def register():
        if g.user:
            return redirect(url_for("dashboard"))
        if request.method == "POST":
            username = request.form.get("username", "").strip()
            email = request.form.get("email", "").strip().lower()
            password = request.form.get("password", "")
            error = validate_registration(username, email, password)
            if not error:
                try:
                    execute(
                        "INSERT INTO users (username, email, password_hash) VALUES (?, ?, ?)",
                        (username, email, generate_password_hash(password)),
                    )
                except sqlite3.IntegrityError:
                    error = "That username or email is already registered."
            if error:
                flash(error, "error")
            else:
                flash("Account created. Welcome to the club!", "success")
                return redirect(url_for("login"))
        return render_template("register.html")

    @app.route("/login", methods=["GET", "POST"])
    def login():
        if g.user:
            return redirect(url_for("dashboard"))
        if request.method == "POST":
            identity = request.form.get("identity", "").strip()
            user = query_one("SELECT * FROM users WHERE username = ? OR email = ?", (identity, identity.lower()))
            if user and check_password_hash(user["password_hash"], request.form.get("password", "")):
                session.clear()
                session.update(user_id=user["id"], csrf_token=secrets.token_urlsafe(24))
                return redirect(safe_next_url() or url_for("dashboard"))
            flash("Incorrect username/email or password.", "error")
        return render_template("login.html")

    @app.post("/logout")
    def logout():
        session.clear()
        flash("You have been signed out.", "success")
        return redirect(url_for("home"))

    @app.before_request
    def load_user() -> None:
        user_id = session.get("user_id")
        g.user = query_one("SELECT id, username, email, created_at FROM users WHERE id = ?", (user_id,)) if user_id else None

    @app.get("/dashboard")
    @login_required
    def dashboard():
        stats = query_one("""
            SELECT
              (SELECT COUNT(*) FROM watchlist WHERE user_id = ?) AS saved,
              (SELECT COUNT(*) FROM watch_history WHERE user_id = ?) AS watched,
              (SELECT COUNT(*) FROM reviews WHERE user_id = ?) AS reviews
        """, (g.user["id"],) * 3)
        recent = query_all("""
            SELECT c.*, h.watched_at FROM watch_history h
            JOIN content c ON c.id = h.content_id
            WHERE h.user_id = ? ORDER BY h.watched_at DESC LIMIT 4
        """, (g.user["id"],))
        return render_template("dashboard.html", stats=stats, recent=recent)

    @app.get("/movies")
    def movies():
        return catalog("movie", "Movies")

    @app.get("/tv_shows")
    def tv_shows():
        return catalog("show", "TV Shows")

    def catalog(kind: str, title: str):
        search = request.args.get("q", "").strip()
        genre = request.args.get("genre", "").strip()
        sort = request.args.get("sort", "rating")
        order = {
            "rating": "c.rating DESC", "newest": "c.release_date DESC",
            "title": "c.title COLLATE NOCASE ASC",
        }.get(sort, "c.rating DESC")
        sql = """SELECT c.*, g.name AS genre_name,
                 EXISTS(SELECT 1 FROM watchlist w WHERE w.content_id=c.id AND w.user_id=?) AS saved
                 FROM content c JOIN genres g ON g.id=c.genre_id WHERE c.kind=?"""
        params: list = [g.user["id"] if g.user else -1, kind]
        if search:
            sql += " AND (c.title LIKE ? OR c.description LIKE ?)"
            params += [f"%{search}%", f"%{search}%"]
        if genre:
            sql += " AND g.slug = ?"
            params.append(genre)
        items = query_all(sql + f" ORDER BY {order}", params)
        return render_template("catalog.html", items=items, genres=query_all("SELECT * FROM genres ORDER BY name"),
                               kind=kind, page_title=title, search=search, selected_genre=genre, selected_sort=sort)

    @app.get("/genres")
    def genres():
        rows = query_all("""
            SELECT g.*, COUNT(c.id) AS item_count FROM genres g
            LEFT JOIN content c ON c.genre_id=g.id GROUP BY g.id ORDER BY g.name
        """)
        return render_template("genres.html", genres=rows)

    @app.get("/new_popular")
    def new_popular():
        items = query_all("""SELECT c.*, g.name AS genre_name FROM content c JOIN genres g ON g.id=c.genre_id
                           ORDER BY c.release_date DESC, c.rating DESC LIMIT 12""")
        return render_template("catalog.html", items=items, genres=[], kind="all", page_title="New & Popular",
                               search="", selected_genre="", selected_sort="newest", simple=True)

    @app.get("/content/<int:content_id>")
    def content_detail(content_id: int):
        item = query_one("""SELECT c.*, g.name AS genre_name FROM content c JOIN genres g ON g.id=c.genre_id
                          WHERE c.id=?""", (content_id,))
        if not item:
            abort(404)
        user_review = query_one("SELECT * FROM reviews WHERE user_id=? AND content_id=?", (g.user["id"], content_id)) if g.user else None
        reviews = query_all("""SELECT r.*, u.username FROM reviews r JOIN users u ON u.id=r.user_id
                             WHERE r.content_id=? ORDER BY r.created_at DESC""", (content_id,))
        saved = bool(query_one("SELECT 1 FROM watchlist WHERE user_id=? AND content_id=?", (g.user["id"], content_id))) if g.user else False
        return render_template("detail.html", item=item, reviews=reviews, user_review=user_review, saved=saved)

    @app.get("/mylist")
    @login_required
    def mylist():
        items = query_all("""SELECT c.*, g.name AS genre_name, w.created_at AS saved_at FROM watchlist w
                           JOIN content c ON c.id=w.content_id JOIN genres g ON g.id=c.genre_id
                           WHERE w.user_id=? ORDER BY w.created_at DESC""", (g.user["id"],))
        return render_template("mylist.html", items=items)

    @app.post("/api/watchlist/<int:content_id>")
    @login_required_api
    def toggle_watchlist(content_id: int):
        ensure_content(content_id)
        existing = query_one("SELECT 1 FROM watchlist WHERE user_id=? AND content_id=?", (g.user["id"], content_id))
        if existing:
            execute("DELETE FROM watchlist WHERE user_id=? AND content_id=?", (g.user["id"], content_id))
            return jsonify(saved=False, message="Removed from My List")
        execute("INSERT INTO watchlist (user_id, content_id) VALUES (?, ?)", (g.user["id"], content_id))
        return jsonify(saved=True, message="Added to My List")

    @app.get("/watch_history")
    @login_required
    def watch_history():
        items = query_all("""SELECT c.*, g.name AS genre_name, h.watched_at FROM watch_history h
                           JOIN content c ON c.id=h.content_id JOIN genres g ON g.id=c.genre_id
                           WHERE h.user_id=? ORDER BY h.watched_at DESC""", (g.user["id"],))
        return render_template("history.html", items=items)

    @app.post("/api/history/<int:content_id>")
    @login_required_api
    def mark_watched(content_id: int):
        ensure_content(content_id)
        execute("""INSERT INTO watch_history (user_id, content_id) VALUES (?, ?)
                 ON CONFLICT(user_id, content_id) DO UPDATE SET watched_at=CURRENT_TIMESTAMP""",
                (g.user["id"], content_id))
        return jsonify(success=True, message="Marked as watched")

    @app.get("/reviews")
    def reviews():
        rows = query_all("""SELECT r.*, u.username, c.title, c.poster FROM reviews r
                          JOIN users u ON u.id=r.user_id JOIN content c ON c.id=r.content_id
                          ORDER BY r.created_at DESC LIMIT 30""")
        return render_template("reviews.html", reviews=rows)

    @app.post("/content/<int:content_id>/review")
    @login_required
    def save_review(content_id: int):
        ensure_content(content_id)
        try:
            rating = int(request.form.get("rating", ""))
        except ValueError:
            rating = 0
        comment = request.form.get("comment", "").strip()
        if not 1 <= rating <= 10 or not 10 <= len(comment) <= 1000:
            flash("Choose a rating from 1–10 and write at least 10 characters.", "error")
        else:
            execute("""INSERT INTO reviews (user_id, content_id, rating, comment) VALUES (?, ?, ?, ?)
                     ON CONFLICT(user_id, content_id) DO UPDATE SET rating=excluded.rating,
                     comment=excluded.comment, created_at=CURRENT_TIMESTAMP""",
                    (g.user["id"], content_id, rating, comment))
            flash("Your review has been saved.", "success")
        return redirect(url_for("content_detail", content_id=content_id))

    @app.get("/health")
    def health():
        query_one("SELECT 1")
        return jsonify(status="ok")

    @app.errorhandler(404)
    def not_found(_error):
        return render_template("error.html", code=404, message="That page slipped out of frame."), 404

    @app.errorhandler(400)
    def bad_request(error):
        return render_template("error.html", code=400, message=str(error.description)), 400

    return app


def _database_path() -> str:
    value = os.getenv("DATABASE_URL", "")
    if value.startswith("sqlite:///"):
        return value.removeprefix("sqlite:///")
    return str(BASE_DIR / "instance" / "cinephile.db")


def get_db() -> sqlite3.Connection:
    if "db" not in g:
        path = Path(current_app_config("DATABASE"))
        path.parent.mkdir(parents=True, exist_ok=True)
        g.db = sqlite3.connect(path)
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA foreign_keys = ON")
    return g.db


def current_app_config(key: str):
    from flask import current_app
    return current_app.config[key]


def close_db(_error=None) -> None:
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db() -> None:
    db = get_db()
    db.executescript((BASE_DIR / "schema.sql").read_text(encoding="utf-8"))
    db.commit()


def init_db_command() -> None:
    init_db()
    print("Database initialized.")


def query_one(sql: str, params=()):
    return get_db().execute(sql, params).fetchone()


def query_all(sql: str, params=()):
    return get_db().execute(sql, params).fetchall()


def execute(sql: str, params=()) -> None:
    db = get_db()
    db.execute(sql, params)
    db.commit()


def login_required(view):
    @wraps(view)
    def wrapped(**kwargs):
        if not g.user:
            return redirect(url_for("login", next=request.path))
        return view(**kwargs)
    return wrapped


def login_required_api(view):
    @wraps(view)
    def wrapped(**kwargs):
        if not g.user:
            return jsonify(success=False, message="Please sign in first."), 401
        return view(**kwargs)
    return wrapped


def ensure_content(content_id: int) -> None:
    if not query_one("SELECT 1 FROM content WHERE id=?", (content_id,)):
        abort(404)


def validate_registration(username: str, email: str, password: str) -> str | None:
    if not re.fullmatch(r"[A-Za-z0-9_]{3,24}", username):
        return "Username must be 3–24 characters using letters, numbers, or underscores."
    if not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email):
        return "Enter a valid email address."
    if len(password) < 8 or not re.search(r"[A-Za-z]", password) or not re.search(r"\d", password):
        return "Password must be 8+ characters and include a letter and a number."
    return None


def safe_next_url() -> str | None:
    target = request.args.get("next", "")
    parsed = urlparse(target)
    return target if target.startswith("/") and not parsed.netloc else None


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")), debug=os.getenv("FLASK_DEBUG") == "1")
