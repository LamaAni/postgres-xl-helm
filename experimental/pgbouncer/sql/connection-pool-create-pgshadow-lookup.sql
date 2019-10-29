DO
$FUNC1$
    BEGIN
        IF NOT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'connection_pool') THEN
            CREATE SCHEMA connection_pool;
            GRANT USAGE ON SCHEMA connection_pool TO postgres;
            CREATE OR REPLACE FUNCTION connection_pool.lookup(INOUT p_user name,
                                                              OUT p_password text)
                RETURNS record
                LANGUAGE sql
                SECURITY DEFINER SET search_path = pg_catalog AS
            $FUNC2$
            SELECT usename, passwd FROM pg_shadow WHERE usename = p_user
            $FUNC2$;
            REVOKE EXECUTE ON FUNCTION connection_pool.lookup(name) FROM PUBLIC;
            GRANT EXECUTE ON FUNCTION connection_pool.lookup(name) TO postgres;
        END IF;
    END
$FUNC1$;