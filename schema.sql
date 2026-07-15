CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(username) BETWEEN 3 AND 24),
    email TEXT NOT NULL COLLATE NOCASE UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS genres (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS content (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    kind TEXT NOT NULL CHECK(kind IN ('movie', 'show')),
    genre_id INTEGER NOT NULL REFERENCES genres(id) ON DELETE RESTRICT,
    description TEXT NOT NULL,
    release_date TEXT NOT NULL,
    rating REAL NOT NULL CHECK(rating BETWEEN 0 AND 10),
    runtime TEXT NOT NULL,
    maturity TEXT NOT NULL DEFAULT '13+',
    seasons INTEGER,
    poster TEXT NOT NULL,
    backdrop TEXT NOT NULL,
    trailer_url TEXT,
    featured INTEGER NOT NULL DEFAULT 0 CHECK(featured IN (0, 1)),
    UNIQUE(title, release_date)
);

CREATE TABLE IF NOT EXISTS watchlist (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content_id INTEGER NOT NULL REFERENCES content(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(user_id, content_id)
);

CREATE TABLE IF NOT EXISTS watch_history (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content_id INTEGER NOT NULL REFERENCES content(id) ON DELETE CASCADE,
    watched_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(user_id, content_id)
);

CREATE TABLE IF NOT EXISTS reviews (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content_id INTEGER NOT NULL REFERENCES content(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK(rating BETWEEN 1 AND 10),
    comment TEXT NOT NULL CHECK(length(comment) BETWEEN 10 AND 1000),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, content_id)
);

CREATE INDEX IF NOT EXISTS idx_content_kind_rating ON content(kind, rating DESC);
CREATE INDEX IF NOT EXISTS idx_content_genre ON content(genre_id);
CREATE INDEX IF NOT EXISTS idx_reviews_content ON reviews(content_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_history_user_date ON watch_history(user_id, watched_at DESC);

INSERT OR IGNORE INTO genres (id, name, slug, description) VALUES
 (1, 'Drama', 'drama', 'Human stories with emotional depth and unforgettable performances.'),
 (2, 'Science Fiction', 'sci-fi', 'Bold futures, strange worlds, and reality-bending ideas.'),
 (3, 'Thriller', 'thriller', 'Tense mysteries and stories that keep you guessing.'),
 (4, 'Comedy', 'comedy', 'Sharp wit, warm laughs, and perfectly timed chaos.'),
 (5, 'Action', 'action', 'High-stakes adventures with momentum to spare.'),
 (6, 'Documentary', 'documentary', 'True stories that reveal a richer view of our world.');

INSERT OR IGNORE INTO content
 (id, title, kind, genre_id, description, release_date, rating, runtime, maturity, seasons, poster, backdrop, trailer_url, featured)
VALUES
 (1, 'Midnight Orbit', 'movie', 2, 'A stranded astronaut discovers that a silent signal from Earth may be the key to returning home.', '2025-11-14', 9.1, '2h 18m', '13+', NULL, '/static/images/1.jpg', '/static/images/bb.jpg', 'https://www.youtube.com/', 1),
 (2, 'The Last Frame', 'movie', 3, 'A film restorer finds a hidden scene that connects a forgotten classic to an unsolved disappearance.', '2025-08-22', 8.7, '1h 56m', '16+', NULL, '/static/images/2.jpg', '/static/images/movies.jpg', 'https://www.youtube.com/', 1),
 (3, 'Paper Kingdoms', 'movie', 1, 'Two estranged siblings return to their coastal hometown to settle an inheritance and rewrite an old story.', '2024-12-06', 8.5, '2h 04m', '13+', NULL, '/static/images/3.jpg', '/static/images/sher.jpg', 'https://www.youtube.com/', 0),
 (4, 'Velocity', 'movie', 5, 'A getaway driver has one night to expose the syndicate that framed her.', '2025-06-27', 8.2, '1h 49m', '16+', NULL, '/static/images/4.jpg', '/static/images/new_popular.jpg', 'https://www.youtube.com/', 1),
 (5, 'Second Take', 'movie', 4, 'An anxious director and a fearless understudy improvise their way through a disastrous opening night.', '2024-09-13', 7.9, '1h 42m', '13+', NULL, '/static/images/5.jpg', '/static/images/movies.jpg', 'https://www.youtube.com/', 0),
 (6, 'Blue Planet Rising', 'movie', 6, 'Scientists and coastal communities collaborate on ambitious experiments to restore the living ocean.', '2025-04-18', 8.8, '1h 38m', 'All', NULL, '/static/images/6.jpg', '/static/images/genres.jpg', 'https://www.youtube.com/', 0),
 (7, 'Neon District', 'show', 2, 'In a city where memories are traded, a detective hunts the person who erased her past.', '2025-10-03', 9.0, '52m episodes', '16+', 2, '/static/images/7.jpg', '/static/images/tvshows.jpg', 'https://www.youtube.com/', 1),
 (8, 'Northbound', 'show', 1, 'Five passengers on a remote night train discover how closely their lives are connected.', '2025-02-21', 8.6, '48m episodes', '13+', 1, '/static/images/8.jpg', '/static/images/bb.jpg', 'https://www.youtube.com/', 0),
 (9, 'Static', 'show', 3, 'A late-night radio host receives calls that predict crimes before they happen.', '2024-10-31', 8.4, '44m episodes', '16+', 3, '/static/images/9.jpg', '/static/images/sher.jpg', 'https://www.youtube.com/', 0),
 (10, 'Roommates of Mars', 'show', 4, 'The first civilian crew on Mars discovers that survival is easier than sharing a kitchen.', '2025-07-11', 8.1, '28m episodes', '13+', 2, '/static/images/10.jpg', '/static/images/tvshows.jpg', 'https://www.youtube.com/', 1),
 (11, 'Breakpoint', 'show', 5, 'An elite rescue team takes on impossible missions across the world’s most dangerous terrain.', '2024-08-16', 7.8, '50m episodes', '16+', 4, '/static/images/11.jpg', '/static/images/new_popular.jpg', 'https://www.youtube.com/', 0),
 (12, 'The Makers', 'show', 6, 'A joyful tour of workshops where craftspeople keep rare skills alive.', '2025-01-17', 8.9, '42m episodes', 'All', 1, '/static/images/12.jpg', '/static/images/genres.jpg', 'https://www.youtube.com/', 0);
