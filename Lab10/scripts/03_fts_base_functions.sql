SHOW default_text_search_config;

SELECT to_tsvector(
    'english',
    'Full Text Searching (or just text search) ' ||
    'provides the capability to identify natural-language ' ||
    'documents that satisfy a query, and optionally to sort ' ||
    'them by relevance to the query.'
);

SELECT to_tsvector(
    'simple',
    'Harry Potter and the Prisoner of Azkaban'
);

SELECT to_tsquery('full text search');

SELECT to_tsquery(
    'full & text & search & (postgres | pg) & !mysql'
);

SELECT to_tsquery('full & text & search');

SELECT plainto_tsquery('full text search');

SELECT phraseto_tsquery('full text search');

SELECT websearch_to_tsquery('"full text" -mysql');

SELECT to_tsvector(
    'Full Text Searching (or just text search) ' ||
    'provides the capability to identify natural-language ' ||
    'documents that satisfy a query, and optionally to sort ' ||
    'them by relevance to the query.'
) @@ to_tsquery('full & text & search');

SELECT to_tsvector(
    'Full Text Searching (or just text search) ' ||
    'provides the capability to identify natural-language ' ||
    'documents that satisfy a query, and optionally to sort ' ||
    'them by relevance to the query.'
) @@ to_tsquery(
    'full & text & search & (postgres | pg)'
);

SELECT COUNT(*)
FROM books
WHERE to_tsvector(
    'english',
    coalesce(title, '') || ' ' || coalesce(description, '')
) @@ plainto_tsquery('english', 'Harry Potter');
