-- Extensions the PostgreSQL tests use, created when docker-compose.yml's postgresql
-- container initializes its data volume. test/schema/postgresql_schema.rb creates them
-- too, but that only works when connecting as a superuser.
CREATE EXTENSION IF NOT EXISTS hstore;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;
