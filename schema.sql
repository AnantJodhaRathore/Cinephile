PRAGMA foreign_keys = ON;

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
 (1, 'Inception', 'movie', 2, 'A skilled thief who steals secrets through dream-sharing technology is offered a chance to erase his criminal history by planting an idea inside a target''s subconscious.', '2010-07-16', 8.8, '148 min', 'PG-13', NULL, '/static/images/1.jpg', 'https://image.tmdb.org/t/p/original/s3TBrRGB1iav7gFOCNx3H31MoES.jpg', 'https://www.youtube.com/watch?v=YoHD9XEInc0', 1),
 (2, 'The Dark Knight', 'movie', 5, 'Batman, Gordon and Harvey Dent confront the Joker, a criminal mastermind who plunges Gotham into chaos and forces Batman to question the limits of justice.', '2008-07-18', 9.0, '152 min', 'PG-13', NULL, '/static/images/2.jpg', 'https://image.tmdb.org/t/p/original/hkBaDkMWbLaf8B1lsWsKX7Ew3Xq.jpg', 'https://www.youtube.com/watch?v=EXeTwQWrcwY', 0),
 (3, 'Interstellar', 'movie', 2, 'When Earth becomes increasingly uninhabitable, a former NASA pilot leads a team through a wormhole in search of a new home for humanity.', '2014-11-05', 8.7, '169 min', 'PG-13', NULL, '/static/images/3.jpg', 'https://image.tmdb.org/t/p/original/xJHokMbljvjADYdit5fK5VQsXEG.jpg', 'https://www.youtube.com/watch?v=zSWdZVtXT7E', 0),
 (4, 'Titanic', 'movie', 1, 'A young aristocrat falls in love with a struggling artist aboard the ill-fated RMS Titanic during its maiden voyage.', '1997-12-19', 8.0, '194 min', 'PG-13', NULL, '/static/images/4.jpg', 'https://image.tmdb.org/t/p/original/rzdPqYx7Um4FUZeD8wpXqjAUcEm.jpg', 'https://www.youtube.com/watch?v=I7c1etV7D7g', 0),
 (5, 'The Conjuring', 'movie', 3, 'Paranormal investigators Ed and Lorraine Warren help a family terrorized by a dark presence in their secluded farmhouse.', '2013-07-19', 7.5, '112 min', 'R', NULL, '/static/images/5.jpg', 'https://image.tmdb.org/t/p/original/xKJTWGvheOMMlTHgrjN18KaD06h.jpg', 'https://www.youtube.com/watch?v=k10ETZ41q5o', 0),
 (6, 'Thor', 'movie', 5, 'The powerful but arrogant warrior Thor is banished from Asgard to Earth, where he learns humility and becomes a defender of humanity.', '2011-05-06', 7.0, '115 min', 'PG-13', NULL, '/static/images/6.jpg', 'https://image.tmdb.org/t/p/original/cDJ61O1STtbWNBwefuqVrRe3d7l.jpg', 'https://www.youtube.com/watch?v=JOddp-nlNvQ', 0),
 (7, 'The Matrix', 'movie', 2, 'A computer hacker discovers that reality is a simulated world controlled by intelligent machines and joins a rebellion to free humanity.', '1999-03-31', 8.7, '136 min', 'R', NULL, 'https://image.tmdb.org/t/p/original/f89U3ADr1oiB1s9GkdPOEpXUk5H.jpg', 'https://image.tmdb.org/t/p/original/l4QHerTSbMI7qgvasqxP36pqjN6.jpg', 'https://www.youtube.com/watch?v=vKQi3bBA1y8', 0),
 (8, 'The Avengers', 'movie', 5, 'Earth''s mightiest heroes must unite to stop Loki and his alien army from conquering humanity.', '2012-05-04', 8.0, '143 min', 'PG-13', NULL, 'https://image.tmdb.org/t/p/original/RYMX2wcKCBAr24UyPD7xwmjaTn.jpg', 'https://image.tmdb.org/t/p/original/9BBTo63ANSmhC4e6r62OJFuK2GL.jpg', 'https://www.youtube.com/watch?v=eOrNdBpGMv8', 0),
 (9, 'Forrest Gump', 'movie', 1, 'A kindhearted Alabama man witnesses and influences major historical events while remaining devoted to his childhood love, Jenny.', '1994-07-06', 8.8, '142 min', 'PG-13', NULL, 'https://image.tmdb.org/t/p/original/arw2vcBveWOVZr6pxd9XTd1TdQa.jpg', 'https://image.tmdb.org/t/p/original/3h1JZGDhZ8nzxdgvkxha0qBqi05.jpg', 'https://www.youtube.com/watch?v=bLvqoHBptjg', 0),
 (10, 'The Lion King', 'movie', 1, 'After the death of his father, a young lion prince flees his kingdom before returning to embrace his destiny and reclaim the throne.', '1994-06-24', 8.5, '88 min', 'G', NULL, 'https://image.tmdb.org/t/p/original/bKPtXn9n4M4s8vvZrbw40mYsefB.jpg', 'https://image.tmdb.org/t/p/original/wXsQvli6tWqja51pYxXNG1LFIGV.jpg', 'https://www.youtube.com/watch?v=lFzVJEksoDY', 0),
 (11, 'The Shawshank Redemption', 'movie', 1, 'A banker sentenced to life in prison forms a lasting friendship with a fellow inmate while holding on to hope and planning for freedom.', '1994-09-23', 9.3, '142 min', 'R', NULL, 'https://image.tmdb.org/t/p/original/q6y0Go1tsGEsmtFryDOJo3dEmqu.jpg', 'https://image.tmdb.org/t/p/original/iNh3BivHyg5sQRPP1KOkzguEX0H.jpg', 'https://www.youtube.com/watch?v=NmzuHjWmXOc', 0),
 (12, 'The Godfather', 'movie', 1, 'The aging patriarch of a powerful crime family transfers control of his empire to his reluctant youngest son.', '1972-03-24', 9.2, '175 min', 'R', NULL, 'https://image.tmdb.org/t/p/original/3bhkrj58Vtu7enYsRolD1fZdja1.jpg', 'https://image.tmdb.org/t/p/original/tmU7GeKVybMWFButWEGl2M4GeiP.jpg', 'https://www.youtube.com/watch?v=UaVTIH8mujA', 0),
 (13, 'Breaking Bad', 'show', 1, 'A chemistry teacher diagnosed with cancer partners with a former student to manufacture and sell methamphetamine, transforming into a powerful criminal.', '2008-01-20', 9.5, '48 min episodes', 'TV-MA', 5, 'https://image.tmdb.org/t/p/original/3xnWaLQjelJDDF7LT1WBo6f4BRe.jpg', 'https://image.tmdb.org/t/p/original/tsRy63Mu5cu8etL1X7ZLyf7UP1M.jpg', 'https://www.youtube.com/watch?v=HhesaQXLuRY', 1),
 (14, 'Sherlock', 'show', 3, 'In modern-day London, brilliant detective Sherlock Holmes and former army doctor John Watson solve complex crimes using sharp observation and deduction.', '2010-07-25', 9.0, '90 min episodes', 'TV-14', 4, 'https://image.tmdb.org/t/p/original/7WTsnHkbA0FaG6R9twfFde0I9hl.jpg', 'https://image.tmdb.org/t/p/original/cUep2Jzb1C1j5Q6as1PpOX93owI.jpg', 'https://www.youtube.com/results?search_query=Sherlock+BBC+official+trailer', 1);
