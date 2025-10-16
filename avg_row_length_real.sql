SET SERVEROUTPUT ON
DECLARE
    v_owner           VARCHAR2(128) := :schema_name;
    v_tablename       VARCHAR2(128);
    v_column_list     VARCHAR2(4000);
    v_sql             VARCHAR2(4000);
    v_size_thresh_gb  NUMBER := 0.01; -- Minimum table size in GB
    v_num_rows        NUMBER;
    v_avg_row_len     NUMBER;
    v_table_bytes     NUMBER;
    v_index_bytes     NUMBER;
    v_lob_bytes       NUMBER;
    v_total_bytes     NUMBER;
    v_csv_row         VARCHAR2(4000);

    -- Helper function to build column sum expressions (includes LOBs)
    FUNCTION get_column_sum(p_owner VARCHAR2, p_table VARCHAR2) RETURN VARCHAR2 IS
        v_expr VARCHAR2(4000) := '';
    BEGIN
        FOR col IN (
            SELECT column_name, data_type
            FROM all_tab_columns
            WHERE owner = p_owner AND table_name = p_table
            ORDER BY column_id
        ) LOOP
            IF col.data_type IN ('CLOB','BLOB','NCLOB') THEN
                v_expr := v_expr || 'NVL(DBMS_LOB.GETLENGTH("' || col.column_name || '"),0)+';
            ELSE
                v_expr := v_expr || 'NVL(VSIZE("' || col.column_name || '"),0)+';
            END IF;
        END LOOP;
        IF v_expr IS NOT NULL THEN
            RETURN RTRIM(v_expr, '+');
        ELSE
            RETURN '0';
        END IF;
    END;

BEGIN
    -- Print CSV header
    DBMS_OUTPUT.PUT_LINE('schema owner,table-name,num rows,size in gb,avg row length');
    FOR t IN (
        SELECT table_name
        FROM all_tables
        WHERE owner = v_owner
        ORDER BY table_name
    ) LOOP
        v_tablename := t.table_name;

        -- Get row count
        SELECT NVL(num_rows,0) INTO v_num_rows
        FROM all_tables
        WHERE owner = v_owner AND table_name = v_tablename;

        IF v_num_rows > 0 THEN
            -- Table segment size
            SELECT NVL(SUM(bytes),0) INTO v_table_bytes
            FROM all_segments
            WHERE owner = v_owner AND segment_type = 'TABLE' AND segment_name = v_tablename;

            -- All index segment sizes
            SELECT NVL(SUM(bytes),0) INTO v_index_bytes
            FROM all_segments
            WHERE owner = v_owner AND segment_type IN ('INDEX','INDEX PARTITION') AND segment_name IN (
                SELECT index_name FROM all_indexes WHERE owner = v_owner AND table_name = v_tablename
            );

            -- All LOB segment sizes (including SecureFile LOBs)
            SELECT NVL(SUM(bytes),0) INTO v_lob_bytes
            FROM all_segments
            WHERE owner = v_owner
              AND segment_type IN ('LOBSEGMENT','LOB PARTITION','LOBINDEX')
              AND segment_name IN (
                  SELECT segment_name FROM all_lobs WHERE owner = v_owner AND table_name = v_tablename
              );

            v_total_bytes := v_table_bytes + v_index_bytes + v_lob_bytes;

            -- Build dynamic SQL for avg row length including LOBs
            v_column_list := get_column_sum(v_owner, v_tablename);
            v_sql := 'SELECT AVG(' || v_column_list || ') FROM "' || v_owner || '"."' || v_tablename || '"';
            BEGIN
                EXECUTE IMMEDIATE v_sql INTO v_avg_row_len;
            EXCEPTION
                WHEN OTHERS THEN
                    v_avg_row_len := NULL;
            END;

            -- Compose CSV row using dynamically computed avg row length
            v_csv_row := v_owner || ',' ||
                         v_tablename || ',' ||
                         v_num_rows || ',' ||
                         ROUND(v_total_bytes/1024/1024/1024,3) || ',' ||
                         NVL(ROUND(v_avg_row_len,1), 'N/A');
            DBMS_OUTPUT.PUT_LINE(v_csv_row);
        END IF;
    END LOOP;
END;
/