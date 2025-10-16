SET SERVEROUTPUT ON
DECLARE
    v_owner            VARCHAR2(128) := :schema_name;
    v_tablename        VARCHAR2(128);
    v_size_thresh_gb   NUMBER := 0.01; -- Minimum table size in GB
    v_num_rows         NUMBER;
    v_avg_row_len      NUMBER;
    v_table_bytes      NUMBER;
    v_index_bytes      NUMBER;
    v_lob_bytes        NUMBER;
    v_total_bytes      NUMBER;
    v_last_analyzed    DATE;
    v_csv_row          VARCHAR2(4000);
BEGIN
    -- Print CSV header
    DBMS_OUTPUT.PUT_LINE('schema owner,table-name,num rows,size in gb,avg row length');
    FOR t IN (
        SELECT table_name, num_rows, avg_row_len
        FROM all_tables
        WHERE owner = v_owner
        ORDER BY table_name
    ) LOOP
        v_tablename := t.table_name;

        -- Table segment size
        SELECT NVL(SUM(bytes),0)
        INTO v_table_bytes
        FROM all_segments
        WHERE owner = v_owner AND segment_type = 'TABLE' AND segment_name = v_tablename;

        -- All index segment sizes
        SELECT NVL(SUM(bytes),0)
        INTO v_index_bytes
        FROM all_segments
        WHERE owner = v_owner AND segment_type IN ('INDEX','INDEX PARTITION') AND segment_name IN (
            SELECT index_name FROM all_indexes WHERE owner = v_owner AND table_name = v_tablename
        );

        -- All LOB segment sizes (including SecureFile LOBs)
        SELECT NVL(SUM(bytes),0)
        INTO v_lob_bytes
        FROM all_segments
        WHERE owner = v_owner
          AND segment_type IN ('LOBSEGMENT','LOB PARTITION','LOBINDEX')
          AND segment_name IN (
              SELECT segment_name FROM all_lobs WHERE owner = v_owner AND table_name = v_tablename
          );

        v_total_bytes := v_table_bytes + v_index_bytes + v_lob_bytes;

        IF NVL(t.num_rows, 0) > 0 AND ROUND(v_total_bytes/1024/1024/1024,3) >= v_size_thresh_gb THEN
            -- Compose CSV row using avg_row_len from ALL_TABLES
            v_csv_row := v_owner || ',' ||
                         v_tablename || ',' ||
                         NVL(t.num_rows, 0) || ',' ||
                         ROUND(v_total_bytes/1024/1024/1024,3) || ',' ||
                         NVL(ROUND(t.avg_row_len,1), 'N/A');
            DBMS_OUTPUT.PUT_LINE(v_csv_row);
        END IF;
    END LOOP;
END;
/