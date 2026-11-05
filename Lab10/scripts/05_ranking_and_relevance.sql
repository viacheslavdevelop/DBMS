SELECT
    title,
    ts_rank(
        search_vector,
        plainto_tsquery('english', 'Harry Potter')
    ) AS rank
FROM books
WHERE search_vector @@ plainto_tsquery('english', 'Harry Potter')
ORDER BY rank DESC;

SELECT
    title,
    ts_rank(
        search_vector,
        plainto_tsquery('english', 'Harry Potter'),
        2
    ) AS rank
FROM books
WHERE search_vector @@ plainto_tsquery('english', 'Harry Potter')
ORDER BY rank DESC;

SELECT setweight(to_tsvector('Harry Potter'), 'A') || setweight(to_tsvector('and The Philosopher Stone'), 'B');

SELECT
    title,
    ts_rank(
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(description, '')), 'D'),
        plainto_tsquery('english', 'Harry Potter')
    ) AS rank
FROM books
WHERE search_vector @@ plainto_tsquery('english', 'Harry Potter')
ORDER BY rank DESC;

SELECT
    title,
    ts_rank(
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(description, '')), 'D'),
        plainto_tsquery('english', 'Harry Potter')
    ) AS rank
FROM books
WHERE search_vector @@ plainto_tsquery('english', 'Harry Potter')
ORDER BY rank DESC
LIMIT 10;

SELECT
    title,
    rating_count,
    rating,
    ts_rank(
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(description, '')), 'D'),
        plainto_tsquery('english', 'Harry Potter')
    )
    * rating / 5
    * log(rating_count + 1) / log(4899965)
    AS total_rank
FROM books
WHERE search_vector @@ plainto_tsquery('english', 'Harry Potter')
ORDER BY total_rank DESC NULLS LAST
LIMIT 10;