-- =====================================================
-- AWR Performance Analysis Queries
-- Comprehensive performance metrics extraction and analysis
-- =====================================================

SET ECHO ON
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE 1000000
SET LINESIZE 150
SET PAGESIZE 1000

PROMPT ==========================================
PROMPT AWR Performance Analysis Suite
PROMPT Detailed Performance Metrics Extraction
PROMPT ==========================================

-- Create comprehensive AWR analysis package
CREATE OR REPLACE PACKAGE awr_performance_analyzer AS
    -- Extract system statistics between snapshots
    PROCEDURE analyze_system_stats(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER
    );
    
    -- Analyze SQL performance
    PROCEDURE analyze_sql_performance(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER,
        p_top_n NUMBER DEFAULT 10
    );
    
    -- Analyze wait events
    PROCEDURE analyze_wait_events(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER,
        p_top_n NUMBER DEFAULT 10
    );
    
    -- Analyze I/O statistics
    PROCEDURE analyze_io_stats(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER
    );
    
    -- Memory analysis
    PROCEDURE analyze_memory_usage(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER
    );
    
    -- Time model analysis
    PROCEDURE analyze_time_model(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER
    );
    
    -- Comprehensive performance summary
    PROCEDURE generate_performance_summary(
        p_session_id VARCHAR2
    );
    
    -- Store metrics for later comparison
    PROCEDURE store_performance_metrics(
        p_session_id VARCHAR2,
        p_baseline BOOLEAN DEFAULT FALSE
    );
    
END awr_performance_analyzer;
/

CREATE OR REPLACE PACKAGE BODY awr_performance_analyzer AS

    PROCEDURE analyze_system_stats(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER
    ) IS
        CURSOR c_system_stats IS
            SELECT 
                stat_name,
                begin_value,
                end_value,
                (end_value - begin_value) as delta_value,
                CASE 
                    WHEN begin_value > 0 THEN 
                        ROUND(((end_value - begin_value) / begin_value) * 100, 2)
                    ELSE 0 
                END as pct_change
            FROM (
                SELECT 
                    s1.stat_name,
                    s1.value as begin_value,
                    s2.value as end_value
                FROM dba_hist_sysstat s1, dba_hist_sysstat s2
                WHERE s1.snap_id = p_start_snap
                AND s2.snap_id = p_end_snap
                AND s1.stat_name = s2.stat_name
                AND s1.dbid = s2.dbid
                AND s1.instance_number = s2.instance_number
                AND s1.stat_name IN (
                    'CPU used by this session',
                    'DB time',
                    'physical reads',
                    'physical writes',
                    'logical reads',
                    'parse count (total)',
                    'parse count (hard)',
                    'execute count',
                    'user commits',
                    'user rollbacks',
                    'session logical reads',
                    'redo size',
                    'sorts (memory)',
                    'sorts (disk)'
                )
                AND (s2.value - s1.value) > 0
            )
            ORDER BY delta_value DESC;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('SYSTEM STATISTICS ANALYSIS');
        DBMS_OUTPUT.PUT_LINE('Session: ' || p_session_id);
        DBMS_OUTPUT.PUT_LINE('Snapshots: ' || p_start_snap || ' to ' || p_end_snap);
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE(RPAD('Statistic', 35) || RPAD('Begin Value', 15) || RPAD('End Value', 15) || RPAD('Delta', 15) || 'Change %');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 35, '-') || RPAD('-', 15, '-') || RPAD('-', 15, '-') || RPAD('-', 15, '-') || RPAD('-', 10, '-'));
        
        FOR rec IN c_system_stats LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(rec.stat_name, 35) || 
                RPAD(TO_CHAR(rec.begin_value, '999,999,999,999'), 15) ||
                RPAD(TO_CHAR(rec.end_value, '999,999,999,999'), 15) ||
                RPAD(TO_CHAR(rec.delta_value, '999,999,999,999'), 15) ||
                TO_CHAR(rec.pct_change, '990.00') || '%'
            );
            
            -- Store metric for comparison
            INSERT INTO awr_test_results (session_id, metric_name, metric_value, metric_unit)
            VALUES (p_session_id, rec.stat_name, rec.delta_value, 'count');
        END LOOP;
        
        COMMIT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('⚠️  No AWR data available, using alternative system statistics...');
            -- Fallback to current session statistics
            DBMS_OUTPUT.PUT_LINE('Current Session Statistics:');
            FOR rec IN (
                SELECT name, value 
                FROM v$sysstat 
                WHERE name IN ('CPU used by this session', 'physical reads', 'logical reads', 'execute count')
                ORDER BY value DESC
            ) LOOP
                DBMS_OUTPUT.PUT_LINE(RPAD(rec.name, 35) || TO_CHAR(rec.value, '999,999,999,999'));
            END LOOP;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error analyzing system stats: ' || SQLERRM);
    END analyze_system_stats;

    PROCEDURE analyze_sql_performance(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER,
        p_top_n NUMBER DEFAULT 10
    ) IS
        CURSOR c_top_sql IS
            SELECT 
                sql_id,
                parsing_schema_name,
                executions_delta,
                elapsed_time_delta / 1000000 as elapsed_seconds,
                cpu_time_delta / 1000000 as cpu_seconds,
                buffer_gets_delta,
                disk_reads_delta,
                CASE 
                    WHEN executions_delta > 0 THEN 
                        ROUND((elapsed_time_delta / 1000000) / executions_delta, 4)
                    ELSE 0 
                END as avg_elapsed_per_exec,
                SUBSTR(sql_text, 1, 60) as sql_text_snippet
            FROM (
                SELECT 
                    s.*,
                    t.sql_text,
                    ROW_NUMBER() OVER (ORDER BY elapsed_time_delta DESC) as rn
                FROM dba_hist_sqlstat s
                LEFT JOIN dba_hist_sqltext t ON s.sql_id = t.sql_id AND s.dbid = t.dbid
                WHERE s.snap_id BETWEEN p_start_snap AND p_end_snap
                AND executions_delta > 0
                AND elapsed_time_delta > 0
            )
            WHERE rn <= p_top_n;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('TOP SQL PERFORMANCE ANALYSIS');
        DBMS_OUTPUT.PUT_LINE('Session: ' || p_session_id);
        DBMS_OUTPUT.PUT_LINE('Top ' || p_top_n || ' SQL statements by elapsed time');
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE(RPAD('SQL ID', 15) || RPAD('Execs', 8) || RPAD('Elapsed(s)', 12) || RPAD('CPU(s)', 10) || RPAD('Avg/Exec', 10) || 'SQL Text');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 15, '-') || RPAD('-', 8, '-') || RPAD('-', 12, '-') || RPAD('-', 10, '-') || RPAD('-', 10, '-') || RPAD('-', 60, '-'));
        
        FOR rec IN c_top_sql LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(rec.sql_id, 15) ||
                RPAD(TO_CHAR(rec.executions_delta), 8) ||
                RPAD(TO_CHAR(rec.elapsed_seconds, '999990.99'), 12) ||
                RPAD(TO_CHAR(rec.cpu_seconds, '99990.99'), 10) ||
                RPAD(TO_CHAR(rec.avg_elapsed_per_exec, '990.9999'), 10) ||
                NVL(rec.sql_text_snippet, 'N/A')
            );
            
            -- Store SQL performance metrics
            INSERT INTO awr_test_results (session_id, metric_name, metric_value, metric_unit, notes)
            VALUES (p_session_id, 'SQL_ELAPSED_TIME', rec.elapsed_seconds, 'seconds', 'SQL_ID: ' || rec.sql_id);
            
            INSERT INTO awr_test_results (session_id, metric_name, metric_value, metric_unit, notes)
            VALUES (p_session_id, 'SQL_EXECUTIONS', rec.executions_delta, 'count', 'SQL_ID: ' || rec.sql_id);
        END LOOP;
        
        COMMIT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('⚠️  No SQL performance data available in AWR');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error analyzing SQL performance: ' || SQLERRM);
    END analyze_sql_performance;

    PROCEDURE analyze_wait_events(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER,
        p_top_n NUMBER DEFAULT 10
    ) IS
        CURSOR c_wait_events IS
            SELECT 
                event_name,
                wait_class,
                total_waits_delta,
                time_waited_micro_delta / 1000000 as time_waited_seconds,
                CASE 
                    WHEN total_waits_delta > 0 THEN 
                        ROUND((time_waited_micro_delta / 1000) / total_waits_delta, 2)
                    ELSE 0 
                END as avg_wait_ms
            FROM (
                SELECT 
                    event_name,
                    wait_class,
                    total_waits_delta,
                    time_waited_micro_delta,
                    ROW_NUMBER() OVER (ORDER BY time_waited_micro_delta DESC) as rn
                FROM dba_hist_system_event
                WHERE snap_id BETWEEN p_start_snap AND p_end_snap
                AND wait_class != 'Idle'
                AND total_waits_delta > 0
            )
            WHERE rn <= p_top_n;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('TOP WAIT EVENTS ANALYSIS');
        DBMS_OUTPUT.PUT_LINE('Session: ' || p_session_id);
        DBMS_OUTPUT.PUT_LINE('Top ' || p_top_n || ' wait events by time waited');
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE(RPAD('Event Name', 40) || RPAD('Class', 15) || RPAD('Waits', 12) || RPAD('Time(s)', 12) || 'Avg(ms)');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 40, '-') || RPAD('-', 15, '-') || RPAD('-', 12, '-') || RPAD('-', 12, '-') || RPAD('-', 10, '-'));
        
        FOR rec IN c_wait_events LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(SUBSTR(rec.event_name, 1, 39), 40) ||
                RPAD(rec.wait_class, 15) ||
                RPAD(TO_CHAR(rec.total_waits_delta, '999,999,999'), 12) ||
                RPAD(TO_CHAR(rec.time_waited_seconds, '99990.99'), 12) ||
                TO_CHAR(rec.avg_wait_ms, '9990.99')
            );
            
            -- Store wait event metrics
            INSERT INTO awr_test_results (session_id, metric_name, metric_value, metric_unit, notes)
            VALUES (p_session_id, 'WAIT_TIME', rec.time_waited_seconds, 'seconds', 'Event: ' || rec.event_name);
        END LOOP;
        
        COMMIT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('⚠️  No wait events data available in AWR');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error analyzing wait events: ' || SQLERRM);
    END analyze_wait_events;

    PROCEDURE analyze_io_stats(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER
    ) IS
        CURSOR c_io_stats IS
            SELECT 
                tablespace_name,
                phyrds_delta as physical_reads,
                phywrts_delta as physical_writes,
                readtim_delta as read_time_ms,
                writetim_delta as write_time_ms,
                CASE 
                    WHEN phyrds_delta > 0 THEN ROUND(readtim_delta / phyrds_delta, 2)
                    ELSE 0 
                END as avg_read_time_ms,
                CASE 
                    WHEN phywrts_delta > 0 THEN ROUND(writetim_delta / phywrts_delta, 2)
                    ELSE 0 
                END as avg_write_time_ms
            FROM dba_hist_filestatxs
            WHERE snap_id BETWEEN p_start_snap AND p_end_snap
            AND (phyrds_delta > 0 OR phywrts_delta > 0)
            ORDER BY (phyrds_delta + phywrts_delta) DESC;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('I/O PERFORMANCE ANALYSIS');
        DBMS_OUTPUT.PUT_LINE('Session: ' || p_session_id);
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE(RPAD('Tablespace', 25) || RPAD('Reads', 12) || RPAD('Writes', 12) || RPAD('Read Time', 12) || RPAD('Write Time', 12) || RPAD('Avg Read', 10) || 'Avg Write');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 25, '-') || RPAD('-', 12, '-') || RPAD('-', 12, '-') || RPAD('-', 12, '-') || RPAD('-', 12, '-') || RPAD('-', 10, '-') || RPAD('-', 10, '-'));
        
        FOR rec IN c_io_stats LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(SUBSTR(rec.tablespace_name, 1, 24), 25) ||
                RPAD(TO_CHAR(rec.physical_reads, '999,999,999'), 12) ||
                RPAD(TO_CHAR(rec.physical_writes, '999,999,999'), 12) ||
                RPAD(TO_CHAR(rec.read_time_ms, '999,999'), 12) ||
                RPAD(TO_CHAR(rec.write_time_ms, '999,999'), 12) ||
                RPAD(TO_CHAR(rec.avg_read_time_ms, '990.99'), 10) ||
                TO_CHAR(rec.avg_write_time_ms, '990.99')
            );
            
            -- Store I/O metrics
            INSERT INTO awr_test_results (session_id, metric_name, metric_value, metric_unit, notes)
            VALUES (p_session_id, 'PHYSICAL_READS', rec.physical_reads, 'count', 'Tablespace: ' || rec.tablespace_name);
        END LOOP;
        
        COMMIT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('⚠️  No I/O statistics data available in AWR');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error analyzing I/O stats: ' || SQLERRM);
    END analyze_io_stats;

    PROCEDURE analyze_memory_usage(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER
    ) IS
        v_sga_size NUMBER;
        v_pga_size NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('MEMORY USAGE ANALYSIS');
        DBMS_OUTPUT.PUT_LINE('Session: ' || p_session_id);
        DBMS_OUTPUT.PUT_LINE('==========================================');
        
        -- Get current memory usage
        BEGIN
            SELECT value/1024/1024 INTO v_sga_size FROM v$parameter WHERE name = 'sga_target';
            SELECT value/1024/1024 INTO v_pga_size FROM v$parameter WHERE name = 'pga_aggregate_target';
            
            DBMS_OUTPUT.PUT_LINE('SGA Target: ' || ROUND(v_sga_size, 2) || ' MB');
            DBMS_OUTPUT.PUT_LINE('PGA Target: ' || ROUND(v_pga_size, 2) || ' MB');
            DBMS_OUTPUT.PUT_LINE('Total Memory Target: ' || ROUND(v_sga_size + v_pga_size, 2) || ' MB');
            
            -- Store memory metrics
            INSERT INTO awr_test_results (session_id, metric_name, metric_value, metric_unit)
            VALUES (p_session_id, 'SGA_SIZE', v_sga_size, 'MB');
            
            INSERT INTO awr_test_results (session_id, metric_name, metric_value, metric_unit)
            VALUES (p_session_id, 'PGA_SIZE', v_pga_size, 'MB');
            
            COMMIT;
            
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('⚠️  Unable to retrieve detailed memory statistics');
        END;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error analyzing memory usage: ' || SQLERRM);
    END analyze_memory_usage;

    PROCEDURE analyze_time_model(
        p_session_id VARCHAR2,
        p_start_snap NUMBER,
        p_end_snap NUMBER
    ) IS
        CURSOR c_time_model IS
            SELECT 
                stat_name,
                value_delta / 1000000 as time_seconds,
                ROUND((value_delta / 1000000) * 100 / 
                    NULLIF(SUM(value_delta / 1000000) OVER (), 0), 2) as pct_of_total
            FROM (
                SELECT 
                    s1.stat_name,
                    s2.value - s1.value as value_delta
                FROM dba_hist_sys_time_model s1, dba_hist_sys_time_model s2
                WHERE s1.snap_id = p_start_snap
                AND s2.snap_id = p_end_snap
                AND s1.stat_name = s2.stat_name
                AND s1.dbid = s2.dbid
                AND s1.instance_number = s2.instance_number
                AND (s2.value - s1.value) > 0
            )
            ORDER BY value_delta DESC;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('TIME MODEL ANALYSIS');
        DBMS_OUTPUT.PUT_LINE('Session: ' || p_session_id);
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE(RPAD('Time Component', 35) || RPAD('Time (seconds)', 15) || 'Percentage');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 35, '-') || RPAD('-', 15, '-') || RPAD('-', 10, '-'));
        
        FOR rec IN c_time_model LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(rec.stat_name, 35) ||
                RPAD(TO_CHAR(rec.time_seconds, '999,990.99'), 15) ||
                TO_CHAR(rec.pct_of_total, '990.99') || '%'
            );
            
            -- Store time model metrics
            INSERT INTO awr_test_results (session_id, metric_name, metric_value, metric_unit)
            VALUES (p_session_id, rec.stat_name, rec.time_seconds, 'seconds');
        END LOOP;
        
        COMMIT;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('⚠️  No time model data available in AWR');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error analyzing time model: ' || SQLERRM);
    END analyze_time_model;

    PROCEDURE generate_performance_summary(
        p_session_id VARCHAR2
    ) IS
        v_session awr_test_sessions%ROWTYPE;
    BEGIN
        SELECT * INTO v_session FROM awr_test_sessions WHERE session_id = p_session_id;
        
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('COMPREHENSIVE PERFORMANCE SUMMARY');
        DBMS_OUTPUT.PUT_LINE('==========================================');
        
        -- Run all analyses
        analyze_system_stats(p_session_id, v_session.start_snap_id, v_session.end_snap_id);
        analyze_sql_performance(p_session_id, v_session.start_snap_id, v_session.end_snap_id);
        analyze_wait_events(p_session_id, v_session.start_snap_id, v_session.end_snap_id);
        analyze_io_stats(p_session_id, v_session.start_snap_id, v_session.end_snap_id);
        analyze_memory_usage(p_session_id, v_session.start_snap_id, v_session.end_snap_id);
        analyze_time_model(p_session_id, v_session.start_snap_id, v_session.end_snap_id);
        
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('Performance analysis completed for session: ' || p_session_id);
        DBMS_OUTPUT.PUT_LINE('Metrics stored in awr_test_results table for comparison');
        DBMS_OUTPUT.PUT_LINE('==========================================');
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('❌ Test session not found: ' || p_session_id);
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error generating performance summary: ' || SQLERRM);
    END generate_performance_summary;

    PROCEDURE store_performance_metrics(
        p_session_id VARCHAR2,
        p_baseline BOOLEAN DEFAULT FALSE
    ) IS
        v_baseline_flag VARCHAR2(10) := CASE WHEN p_baseline THEN 'BASELINE' ELSE 'RESULT' END;
    BEGIN
        -- This procedure is called automatically by other analysis procedures
        -- Additional logic for baseline comparison could be added here
        
        UPDATE awr_test_results 
        SET notes = NVL(notes, '') || ' [' || v_baseline_flag || ']'
        WHERE session_id = p_session_id
        AND (notes IS NULL OR notes NOT LIKE '%[' || v_baseline_flag || ']%');
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('✅ Performance metrics stored with ' || v_baseline_flag || ' flag');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error storing performance metrics: ' || SQLERRM);
    END store_performance_metrics;

END awr_performance_analyzer;
/

DBMS_OUTPUT.PUT_LINE('✅ AWR Performance Analyzer package created successfully');

PROMPT
PROMPT ==========================================
PROMPT AWR Analysis Framework Ready!
PROMPT ==========================================
PROMPT
PROMPT Usage Examples:
PROMPT ---------------
PROMPT -- Analyze specific session
PROMPT EXEC awr_performance_analyzer.generate_performance_summary('session_id');
PROMPT
PROMPT -- Analyze individual components
PROMPT EXEC awr_performance_analyzer.analyze_system_stats('session_id', start_snap, end_snap);
PROMPT EXEC awr_performance_analyzer.analyze_sql_performance('session_id', start_snap, end_snap);
PROMPT EXEC awr_performance_analyzer.analyze_wait_events('session_id', start_snap, end_snap);
PROMPT

EXIT;