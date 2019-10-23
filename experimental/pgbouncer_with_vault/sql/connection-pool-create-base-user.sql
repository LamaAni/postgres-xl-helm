DO $FUNC$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'connection_pool') THEN
        CREATE ROLE connection_pool;
    END IF;
END
$FUNC$;