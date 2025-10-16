-- ==================================================================
-- Enterprise Table Analysis Inline Script (v2.0)
-- ==================================================================
-- Purpose: Comprehensive table analysis with size, row count, and 
--          average row length calculation; NO procedures/functions.
-- Author: Principal Engineer Review
-- Version: 2.0 (Enterprise Grade, Inline)
-- Security: SQL Injection Protected, Input Validated
-- Performance: Optimized with bulk operations and CTEs
-- Maintainability: All logic in one block for TOAD/SQL*Plus
--
-- ==================================================================
-- USAGE EXAMPLES:
-- ==================================================================
-- Basic usage with statistics:
-- DEFINE schema_name = 'SCOTT'
-- DEFINE analysis_mode = 'STATS'
-- @table_analysis_enterprise_v2_inline.sql
--
-- Real-time analysis (slower but more accurate):
-- DEFINE schema_name = 'SCOTT' 
-- DEFINE analysis_mode = 'REAL'
-- @table_analysis_enterprise_v2_inline.sql
--
-- Bind variable usage (recommended for jobs/Scheduler/SQL Developer):
-- VARIABLE schema_name VARCHAR2(128)
-- VARIABLE analysis_mode VARCHAR2(20)
-- EXEC :schema_name := 'SCOTT'; :analysis_mode := 'STATS';
-- @table_analysis_enterprise_v2_inline.sql
--
-- ==================================================================
-- LIMITATIONS & MODE IMPLICATIONS:
-- ==================================================================
-- STATS Mode: Fast, uses Oracle statistics; may be inaccurate if stats are stale.
-- REAL Mode: Accurate, scans tables for actual row/column sizes; can be SLOW and IMPACTFUL on production databases due to full-table scans.
--            Use with care and avoid running in peak hours or on large production schemas.
-- ==================================================================

SET SERVEROUTPUT ON
SET LINESIZE 200
SET PAGESIZE 1000

DECLARE
    -- =============================================================
    -- CONFIGURATION CONSTANTS
    -- =============================================================
    C_MIN_SIZE_GB         CONSTANT NUMBER := 0.01;
    C_MIN_ROWS            CONSTANT NUMBER := 1;
    C_MAX_SCHEMA_NAME_LEN CONSTANT NUMBER := 128;
    C_CSV_DELIMITER       CONSTANT VARCHAR2(1) := ',';
    C_NULL_DISPLAY        CONSTANT VARCHAR2(10) := 'N/A';
    
    -- =============================================================
    -- VARIABLES
    -- =============================================================
    v_schema_name         VARCHAR2(128);
    v_analysis_mode       VARCHAR2(20) := 'STATS';
    v_error_count         NUMBER := 0;
    v_table_count         NUMBER := 0;
    v_start_time          TIMESTAMP := SYSTIMESTAMP;
    v_end_time            TIMESTAMP;
    v_elapsed_seconds     NUMBER;
    v_elapsed_hours       NUMBER;
    v_elapsed_minutes     NUMBER;
    v_elapsed_str         VARCHAR2(32);

    -- Inline quoting utility
    FUNCTION quote_csv(val VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF val IS NULL THEN
            RETURN '"' || C_NULL_DISPLAY || '"';
        ELSE
            RETURN '"' || REPLACE(val, '"', '""') || '"';
        END IF;
    END;
BEGIN
    -- Accept bind or substitution variables
    BEGIN
        v_schema_name := UPPER(TRIM(:schema_name));
    EXCEPTION
        WHEN OTHERS THEN
            v_schema_name := UPPER(TRIM('&schema_name'));
    END;
    
    IF v_schema_name IS NULL OR LENGTH(v_schema_name) = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Schema name cannot be null or empty');
    END IF;
    IF LENGTH(v_schema_name) > C_MAX_SCHEMA_NAME_LEN THEN
        RAISE_APPLICATION_ERROR(-20002, 'Schema name exceeds maximum length of ' || C_MAX_SCHEMA_NAME_LEN);
    END IF;
    
    -- Validate schema exists
    DECLARE v_schema_exists NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_schema_exists FROM all_users WHERE username = v_schema_name;
        IF v_schema_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Schema "' || v_schema_name || '" does not exist or is not accessible');
        END IF;
    END;
    
    -- Get analysis mode
    BEGIN
        v_analysis_mode := UPPER(TRIM(:analysis_mode));
    EXCEPTION
        WHEN OTHERS THEN
            v_analysis_mode := UPPER(TRIM(NVL('&analysis_mode', 'STATS')));
    END;
    IF v_analysis_mode NOT IN ('STATS', 'REAL') THEN
        RAISE_APPLICATION_ERROR(-20004, 'Analysis mode must be either STATS or REAL');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('-- Configuration validated successfully');
    DBMS_OUTPUT.PUT_LINE('-- Schema: ' || v_schema_name);
    DBMS_OUTPUT.PUT_LINE('-- Analysis Mode: ' || v_analysis_mode);
    DBMS_OUTPUT.PUT_LINE('-- Minimum Size Threshold: ' || C_MIN_SIZE_GB || ' GB');
    DBMS_OUTPUT.PUT_LINE('--');
    
    -- Print enhanced quoted CSV header
    DBMS_OUTPUT.PUT_LINE('"schema_owner","table_name","num_rows","total_size_gb","avg_row_length","table_size_gb","index_size_gb","lob_size_gb"');
    
    IF v_analysis_mode = 'STATS' THEN
        FOR rec IN (
            WITH table_segments AS (
                SELECT 
                    s.owner,
                    CASE 
                        WHEN s.segment_type = 'TABLE' THEN s.segment_name
                        WHEN s.segment_type IN ('INDEX', 'INDEX PARTITION') THEN i.table_name
                        WHEN s.segment_type IN ('LOBSEGMENT', 'LOB PARTITION', 'LOBINDEX') THEN l.table_name
                        ELSE NULL
                    END AS table_name,
                    s.segment_type,
                    s.bytes
                FROM all_segments s
                LEFT JOIN all_indexes i ON (s.segment_type IN ('INDEX', 'INDEX PARTITION') 
                                           AND s.owner = i.owner 
                                           AND s.segment_name = i.index_name)
                LEFT JOIN all_lobs l ON (s.segment_type IN ('LOBSEGMENT', 'LOB PARTITION', 'LOBINDEX')
                                       AND s.owner = l.owner 
                                       AND s.segment_name = l.segment_name)
                WHERE s.owner = v_schema_name
            ),
            table_sizes AS (
                SELECT 
                    table_name,
                    SUM(CASE WHEN segment_type = 'TABLE' THEN bytes ELSE 0 END) AS table_bytes,
                    SUM(CASE WHEN segment_type IN ('INDEX', 'INDEX PARTITION') THEN bytes ELSE 0 END) AS index_bytes,
                    SUM(CASE WHEN segment_type IN ('LOBSEGMENT', 'LOB PARTITION', 'LOBINDEX') THEN bytes ELSE 0 END) AS lob_bytes,
                    SUM(bytes) AS total_bytes
                FROM table_segments
                WHERE table_name IS NOT NULL
                GROUP BY table_name
            )
            SELECT 
                t.table_name,
                NVL(t.num_rows, 0) AS num_rows,
                NVL(t.avg_row_len, 0) AS avg_row_len,
                NVL(ts.total_bytes, 0) AS total_bytes,
                NVL(ts.table_bytes, 0) AS table_bytes,
                NVL(ts.index_bytes, 0) AS index_bytes,
                NVL(ts.lob_bytes, 0) AS lob_bytes
            FROM all_tables t
            LEFT JOIN table_sizes ts ON t.table_name = ts.table_name
            WHERE t.owner = v_schema_name
              AND NVL(t.num_rows, 0) >= C_MIN_ROWS
              AND NVL(ts.total_bytes, 0) / POWER(1024, 3) >= C_MIN_SIZE_GB
            ORDER BY ts.total_bytes DESC NULLS LAST, t.table_name
        ) LOOP
            BEGIN
                v_table_count := v_table_count + 1;
                DBMS_OUTPUT.PUT_LINE(
                    quote_csv(v_schema_name) || C_CSV_DELIMITER ||
                    quote_csv(rec.table_name) || C_CSV_DELIMITER ||
                    quote_csv(TO_CHAR(rec.num_rows)) || C_CSV_DELIMITER ||
                    quote_csv(TO_CHAR(ROUND(rec.total_bytes / POWER(1024, 3), 3))) || C_CSV_DELIMITER ||
                    quote_csv(CASE WHEN rec.avg_row_len > 0 THEN TO_CHAR(ROUND(rec.avg_row_len, 1)) ELSE C_NULL_DISPLAY END) || C_CSV_DELIMITER ||
                    quote_csv(TO_CHAR(ROUND(rec.table_bytes / POWER(1024, 3), 3))) || C_CSV_DELIMITER ||
                    quote_csv(TO_CHAR(ROUND(rec.index_bytes / POWER(1024, 3), 3))) || C_CSV_DELIMITER ||
                    quote_csv(TO_CHAR(ROUND(rec.lob_bytes / POWER(1024, 3), 3)))
                );
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_count := v_error_count + 1;
                    DBMS_OUTPUT.PUT_LINE('ERROR processing table "' || rec.table_name || '": ' || SQLERRM);
            END;
        END LOOP;
    ELSE
        FOR rec IN (
            SELECT table_name
              FROM all_tables
             WHERE owner = v_schema_name
               AND NVL(num_rows, 0) >= C_MIN_ROWS
             ORDER BY NVL(num_rows, 0) DESC, table_name
        ) LOOP
            DECLARE
                v_sql      VARCHAR2(4000);
                v_avg_row_len NUMBER := NULL;
                v_num_rows NUMBER;
                v_total_bytes NUMBER;
                v_table_bytes NUMBER;
                v_index_bytes NUMBER;
                v_lob_bytes NUMBER;
                v_col_count NUMBER := 0;
                v_expr CLOB := '';
            BEGIN
                -- Row count
                v_sql := 'SELECT COUNT(*) FROM ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema_name) || '.' || DBMS_ASSERT.ENQUOTE_NAME(rec.table_name);
                EXECUTE IMMEDIATE v_sql INTO v_num_rows;
                IF v_num_rows >= C_MIN_ROWS THEN
                    -- Build column sum expr inline
                    FOR col IN (
                        SELECT column_name, data_type
                        FROM all_tab_columns
                        WHERE owner = v_schema_name 
                          AND table_name = rec.table_name
                        ORDER BY column_id
                    ) LOOP
                        v_col_count := v_col_count + 1;
                        IF col.data_type IN ('CLOB', 'BLOB', 'NCLOB') THEN
                            v_expr := v_expr || 'NVL(DBMS_LOB.GETLENGTH(' || DBMS_ASSERT.ENQUOTE_NAME(col.column_name) || '), 0) + ';
                        ELSE
                            v_expr := v_expr || 'NVL(VSIZE(' || DBMS_ASSERT.ENQUOTE_NAME(col.column_name) || '), 0) + ';
                        END IF;
                    END LOOP;
                    IF v_col_count = 0 THEN
                        v_expr := '0';
                    ELSE
                        v_expr := RTRIM(v_expr, ' + ');
                    END IF;
                    v_sql := 'SELECT AVG(' || v_expr || ') FROM ' || DBMS_ASSERT.ENQUOTE_NAME(v_schema_name) || '.' || DBMS_ASSERT.ENQUOTE_NAME(rec.table_name);
                    BEGIN
                        EXECUTE IMMEDIATE v_sql INTO v_avg_row_len;
                    EXCEPTION
                        WHEN OTHERS THEN
                            v_avg_row_len := NULL;
                    END;
                    -- Segment sizes
                    SELECT 
                        NVL(SUM(CASE WHEN segment_type = 'TABLE' THEN bytes ELSE 0 END), 0),
                        NVL(SUM(CASE WHEN segment_type IN ('INDEX', 'INDEX PARTITION') THEN bytes ELSE 0 END), 0),
                        NVL(SUM(CASE WHEN segment_type IN ('LOBSEGMENT', 'LOB PARTITION', 'LOBINDEX') THEN bytes ELSE 0 END), 0),
                        NVL(SUM(bytes), 0)
                    INTO v_table_bytes, v_index_bytes, v_lob_bytes, v_total_bytes
                    FROM (
                        SELECT s.segment_type, s.bytes
                        FROM all_segments s
                        WHERE s.owner = v_schema_name
                          AND (
                              (s.segment_type = 'TABLE' AND s.segment_name = rec.table_name)
                              OR (s.segment_type IN ('INDEX', 'INDEX PARTITION') AND s.segment_name IN (
                                  SELECT index_name FROM all_indexes 
                                  WHERE owner = v_schema_name AND table_name = rec.table_name
                              ))
                              OR (s.segment_type IN ('LOBSEGMENT', 'LOB PARTITION', 'LOBINDEX') AND s.segment_name IN (
                                  SELECT segment_name FROM all_lobs 
                                  WHERE owner = v_schema_name AND table_name = rec.table_name
                              ))
                          )
                    );
                    IF v_total_bytes / POWER(1024, 3) >= C_MIN_SIZE_GB THEN
                        v_table_count := v_table_count + 1;
                        DBMS_OUTPUT.PUT_LINE(
                            quote_csv(v_schema_name) || C_CSV_DELIMITER ||
                            quote_csv(rec.table_name) || C_CSV_DELIMITER ||
                            quote_csv(TO_CHAR(v_num_rows)) || C_CSV_DELIMITER ||
                            quote_csv(TO_CHAR(ROUND(v_total_bytes / POWER(1024, 3), 3))) || C_CSV_DELIMITER ||
                            quote_csv(CASE WHEN v_avg_row_len > 0 THEN TO_CHAR(ROUND(v_avg_row_len, 1)) ELSE C_NULL_DISPLAY END) || C_CSV_DELIMITER ||
                            quote_csv(TO_CHAR(ROUND(v_table_bytes / POWER(1024, 3), 3))) || C_CSV_DELIMITER ||
                            quote_csv(TO_CHAR(ROUND(v_index_bytes / POWER(1024, 3), 3))) || C_CSV_DELIMITER ||
                            quote_csv(TO_CHAR(ROUND(v_lob_bytes / POWER(1024, 3), 3)))
                        );
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    v_error_count := v_error_count + 1;
                    DBMS_OUTPUT.PUT_LINE('ERROR processing table "' || rec.table_name || '": ' || SQLERRM);
            END;
        END LOOP;
    END IF;
    
    -- Print summary with improved timing breakdown
    v_end_time := SYSTIMESTAMP;
    v_elapsed_seconds := EXTRACT(SECOND FROM (v_end_time - v_start_time))
                      + EXTRACT(MINUTE FROM (v_end_time - v_start_time))*60
                      + EXTRACT(HOUR FROM (v_end_time - v_start_time))*3600;
    v_elapsed_hours := TRUNC(v_elapsed_seconds / 3600);
    v_elapsed_minutes := TRUNC(MOD(v_elapsed_seconds, 3600) / 60);
    v_elapsed_str := TO_CHAR(v_elapsed_hours) || 'h:' || TO_CHAR(v_elapsed_minutes) || 'm:' ||
                     TO_CHAR(TRUNC(MOD(v_elapsed_seconds, 60))) || 's';
    DBMS_OUTPUT.PUT_LINE('--');
    DBMS_OUTPUT.PUT_LINE('-- Analysis Summary');
    DBMS_OUTPUT.PUT_LINE('-- Schema: ' || v_schema_name);
    DBMS_OUTPUT.PUT_LINE('-- Analysis Mode: ' || v_analysis_mode);
    DBMS_OUTPUT.PUT_LINE('-- Tables Processed: ' || v_table_count);
    DBMS_OUTPUT.PUT_LINE('-- Errors Encountered: ' || v_error_count);
    DBMS_OUTPUT.PUT_LINE('-- Execution Time: ' || v_elapsed_str);
    DBMS_OUTPUT.PUT_LINE('--');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FATAL ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Error Code: ' || SQLCODE);
        RAISE;
END;
/