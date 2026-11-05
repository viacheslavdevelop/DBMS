import json
import os
import psycopg2
from psycopg2.extras import execute_values
from pathlib import Path

FILE_PATH = Path(__file__).resolve().parent.parent / "data" / "goodreads_books.json"
POSTGRES_DSN = "postgresql://postgres:postgres@localhost:5432/books_db"
BATCH_SIZE = 5000

def to_int(val):
    try:
        return int(val) if val else None
    except (ValueError, TypeError):
        return None

def to_float(val):
    try:
        return float(val) if val else None
    except (ValueError, TypeError):
        return None

conn = psycopg2.connect(POSTGRES_DSN)
cur = conn.cursor()

rows = []
insert_query = """
    INSERT INTO books (isbn, title, description, year, rating, rating_count, pages, authors)
    VALUES %s
"""

with open(FILE_PATH, "r", encoding="utf-8") as f:
    for line in f:
        try:
            record = json.loads(line)
            authors_raw = record.get("authors") or []
            authors = [to_int(a.get("author_id")) for a in authors_raw if to_int(a.get("author_id")) is not None]
            rows.append((
                record.get("isbn") or None,
                record.get("title") or None,
                record.get("description") or None,
                to_int(record.get("publication_year")),
                to_float(record.get("average_rating")),
                to_int(record.get("ratings_count")),
                to_int(record.get("num_pages")),
                authors if authors else None
            ))
            if len(rows) >= BATCH_SIZE:
                execute_values(cur, insert_query, rows)
                conn.commit()
                rows.clear()
        except Exception as e:
            print(e)

if rows:
    execute_values(cur, insert_query, rows)
    conn.commit()

cur.close()
conn.close()
