CREATE INDEX idx_tickets_session ON Tickets(id_session);
CREATE INDEX idx_sessions_datetime ON Sessions(session_datetime);
CREATE INDEX idx_sessions_movie ON Sessions(id_movie); 
CREATE INDEX idx_preorders_client ON Preorders(id_client);