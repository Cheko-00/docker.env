-- Bases de datos requeridas por las aplicaciones

SELECT 'CREATE DATABASE tickets'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'tickets'
)\gexec

SELECT 'CREATE DATABASE reports'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'reports'
)\gexec