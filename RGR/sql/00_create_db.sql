SELECT 'CREATE DATABASE oildepotdb ENCODING ''UTF8'' TEMPLATE template0'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'oildepotdb')\gexec
