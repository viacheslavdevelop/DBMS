EXPLAIN ANALYZE
SELECT count(*)
FROM books
WHERE to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, '')) @@ plainto_tsquery('english', 'Harry Potter');

CREATE INDEX search_vector_idx ON books USING GIN (to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, '')));

EXPLAIN ANALYZE
SELECT count(*)
FROM books
WHERE to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, '')) @@ plainto_tsquery('english', 'Harry Potter');

DROP INDEX search_vector_idx;

ALTER TABLE books ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, ''))) STORED;

CREATE INDEX search_vector_idx ON books USING GIN (search_vector);

EXPLAIN ANALYZE
SELECT count(*)
FROM books
WHERE search_vector @@ plainto_tsquery('english', 'Harry Potter');
