-- =====================================================
-- AWR Performance Monitoring and Analysis Framework
-- Advanced performance tracking with snapshot comparison
-- =====================================================

SET ECHO ON
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE 1000000
SET LINESIZE 150
SET PAGESIZE 1000

PROMPT ==========================================
PROMPT AWR Performance Monitoring Framework
PROMPT Oracle Partition Management Suite
PROMPT ==========================================

-- Check if AWR is available and enabled
PROMPT
PROMPT 1. AWR Availability Check
PROMPT =========================

DECLARE
    v_awr_enabled VARCHAR2(10);
    v_snap_interval NUMBER;
    v_retention NUMBER;
    v_dbid NUMBER;
BEGIN
    -- Check if AWR is enabled
    SELECT value INTO v_awr_enabled 
    FROM v$parameter 
    WHERE name = 'statistics_level';
    
    DBMS_OUTPUT.PUT_LINE('Statistics Level: ' || v_awr_enabled);
    
    IF UPPER(v_awr_enabled) NOT IN ('TYPICAL', 'ALL') THEN
        DBMS_OUTPUT.PUT_LINE('❌ AWR is not enabled. Statistics level must be TYPICAL or ALL.');
        DBMS_OUTPUT.PUT_LINE('   To enable: ALTER SYSTEM SET statistics_level = TYPICAL;');
        RETURN;
    END IF;
    
    -- Get AWR configuration
    SELECT snap_interval, retention INTO v_snap_interval, v_retention
    FROM dba_hist_wr_control
    WHERE dbid = (SELECT dbid FROM v$database);
    
    SELECT dbid INTO v_dbid FROM v$database;
    
    DBMS_OUTPUT.PUT_LINE('✅ AWR is enabled and available');
    DBMS_OUTPUT.PUT_LINE('Database ID: ' || v_dbid);
    DBMS_OUTPUT.PUT_LINE('Snapshot Interval: ' || v_snap_interval || ' minutes');
    DBMS_OUTPUT.PUT_LINE('Retention Period: ' || v_retention || ' days');
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('❌ AWR not available - this may be Oracle Express Edition');
        DBMS_OUTPUT.PUT_LINE('   Using alternative performance monitoring...');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Error checking AWR: ' || SQLERRM);
END;
/

-- Create AWR test management table
PROMPT
PROMPT 2. Creating AWR Test Management Infrastructure
PROMPT ============================================

-- Drop existing table if it exists
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE awr_test_sessions PURGE';
    DBMS_OUTPUT.PUT_LINE('Dropped existing awr_test_sessions table');
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Table doesn't exist
END;
/

-- Create test session tracking table
CREATE TABLE awr_test_sessions (
    session_id VARCHAR2(50) PRIMARY KEY,
    test_name VARCHAR2(100) NOT NULL,
    test_description VARCHAR2(500),
    start_time TIMESTAMP DEFAULT SYSTIMESTAMP,
    end_time TIMESTAMP,
    start_snap_id NUMBER,
    end_snap_id NUMBER,
    dbid NUMBER,
    instance_number NUMBER DEFAULT 1,
    status VARCHAR2(20) DEFAULT 'ACTIVE',
    test_type VARCHAR2(50), -- 'PACKAGE', 'PERFORMANCE', 'LOAD', 'COMPARISON'
    test_parameters CLOB, -- JSON-like test configuration
    created_by VARCHAR2(100) DEFAULT USER,
    CONSTRAINT chk_status CHECK (status IN ('ACTIVE', 'COMPLETED', 'FAILED', 'ARCHIVED'))
);

-- Create indexes for performance
CREATE INDEX idx_awr_test_name ON awr_test_sessions(test_name);
CREATE INDEX idx_awr_start_time ON awr_test_sessions(start_time);
CREATE INDEX idx_awr_status ON awr_test_sessions(status);

-- Create test results summary table
CREATE TABLE awr_test_results (
    result_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id VARCHAR2(50) REFERENCES awr_test_sessions(session_id),
    metric_name VARCHAR2(100),
    metric_value NUMBER,
    metric_unit VARCHAR2(50),
    baseline_value NUMBER,
    variance_pct NUMBER,
    result_timestamp TIMESTAMP DEFAULT SYSTIMESTAMP,
    notes VARCHAR2(500)
);

CREATE INDEX idx_awr_results_session ON awr_test_results(session_id);
CREATE INDEX idx_awr_results_metric ON awr_test_results(metric_name);

DBMS_OUTPUT.PUT_LINE('✅ AWR test management infrastructure created');

-- Create AWR snapshot management package
PROMPT
PROMPT 3. Creating AWR Snapshot Management Package
PROMPT ===========================================

CREATE OR REPLACE PACKAGE awr_test_manager AS
    -- Start a new AWR test session
    FUNCTION start_test_session(
        p_test_name VARCHAR2,
        p_test_description VARCHAR2 DEFAULT NULL,
        p_test_type VARCHAR2 DEFAULT 'PERFORMANCE',
        p_test_parameters CLOB DEFAULT NULL
    ) RETURN VARCHAR2;
    
    -- End an AWR test session
    PROCEDURE end_test_session(
        p_session_id VARCHAR2,
        p_notes VARCHAR2 DEFAULT NULL
    );
    
    -- Take manual AWR snapshot
    FUNCTION take_snapshot RETURN NUMBER;
    
    -- Get performance metrics between snapshots
    FUNCTION get_performance_delta(
        p_start_snap NUMBER,
        p_end_snap NUMBER,
        p_metric_name VARCHAR2
    ) RETURN NUMBER;
    
    -- Compare two test sessions
    PROCEDURE compare_test_sessions(
        p_session1_id VARCHAR2,
        p_session2_id VARCHAR2
    );
    
    -- Generate AWR-style report
    PROCEDURE generate_test_report(
        p_session_id VARCHAR2,
        p_report_type VARCHAR2 DEFAULT 'SUMMARY' -- SUMMARY, DETAILED, HTML
    );
    
    -- Cleanup old test sessions
    PROCEDURE cleanup_old_sessions(
        p_days_to_keep NUMBER DEFAULT 30
    );
END awr_test_manager;
/

CREATE OR REPLACE PACKAGE BODY awr_test_manager AS

    FUNCTION start_test_session(
        p_test_name VARCHAR2,
        p_test_description VARCHAR2 DEFAULT NULL,
        p_test_type VARCHAR2 DEFAULT 'PERFORMANCE',
        p_test_parameters CLOB DEFAULT NULL
    ) RETURN VARCHAR2 IS
        v_session_id VARCHAR2(50);
        v_start_snap NUMBER;
        v_dbid NUMBER;
    BEGIN
        -- Generate unique session ID
        v_session_id := p_test_name || '_' || TO_CHAR(SYSTIMESTAMP, 'YYYYMMDDHH24MISS');
        
        -- Get database ID
        SELECT dbid INTO v_dbid FROM v$database;
        
        -- Take starting snapshot
        BEGIN
            v_start_snap := DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();
            DBMS_OUTPUT.PUT_LINE('✅ Created AWR snapshot: ' || v_start_snap);
        EXCEPTION
            WHEN OTHERS THEN
                -- Fallback for Express Edition - use current time as pseudo-snapshot
                SELECT TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS')) INTO v_start_snap FROM dual;
                DBMS_OUTPUT.PUT_LINE('⚠️  AWR not available, using timestamp-based tracking: ' || v_start_snap);
        END;
        
        -- Insert test session record
        INSERT INTO awr_test_sessions (
            session_id, test_name, test_description, start_snap_id, 
            dbid, test_type, test_parameters
        ) VALUES (
            v_session_id, p_test_name, p_test_description, v_start_snap,
            v_dbid, p_test_type, p_test_parameters
        );
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('🚀 Started test session: ' || v_session_id);
        DBMS_OUTPUT.PUT_LINE('   Test Name: ' || p_test_name);
        DBMS_OUTPUT.PUT_LINE('   Test Type: ' || p_test_type);
        DBMS_OUTPUT.PUT_LINE('   Start Snapshot: ' || v_start_snap);
        
        RETURN v_session_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('❌ Error starting test session: ' || SQLERRM);
            RAISE;
    END start_test_session;

    PROCEDURE end_test_session(
        p_session_id VARCHAR2,
        p_notes VARCHAR2 DEFAULT NULL
    ) IS
        v_end_snap NUMBER;
        v_test_name VARCHAR2(100);
        v_start_snap NUMBER;
    BEGIN
        -- Get test session info
        SELECT test_name, start_snap_id INTO v_test_name, v_start_snap
        FROM awr_test_sessions 
        WHERE session_id = p_session_id AND status = 'ACTIVE';
        
        -- Take ending snapshot
        BEGIN
            v_end_snap := DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();
            DBMS_OUTPUT.PUT_LINE('✅ Created end AWR snapshot: ' || v_end_snap);
        EXCEPTION
            WHEN OTHERS THEN
                -- Fallback for Express Edition
                SELECT TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS')) INTO v_end_snap FROM dual;
                DBMS_OUTPUT.PUT_LINE('⚠️  Using timestamp-based end tracking: ' || v_end_snap);
        END;
        
        -- Update test session
        UPDATE awr_test_sessions 
        SET end_time = SYSTIMESTAMP,
            end_snap_id = v_end_snap,
            status = 'COMPLETED'
        WHERE session_id = p_session_id;
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('🏁 Completed test session: ' || p_session_id);
        DBMS_OUTPUT.PUT_LINE('   Test Name: ' || v_test_name);
        DBMS_OUTPUT.PUT_LINE('   Start Snapshot: ' || v_start_snap);
        DBMS_OUTPUT.PUT_LINE('   End Snapshot: ' || v_end_snap);
        DBMS_OUTPUT.PUT_LINE('   Duration: ' || ROUND((v_end_snap - v_start_snap)/100, 2) || ' seconds (approx)');
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('❌ Test session not found or already completed: ' || p_session_id);
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('❌ Error ending test session: ' || SQLERRM);
            RAISE;
    END end_test_session;

    FUNCTION take_snapshot RETURN NUMBER IS
        v_snap_id NUMBER;
    BEGIN
        BEGIN
            v_snap_id := DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();
        EXCEPTION
            WHEN OTHERS THEN
                -- Fallback for Express Edition
                SELECT TO_NUMBER(TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS')) INTO v_snap_id FROM dual;
        END;
        
        RETURN v_snap_id;
    END take_snapshot;

    FUNCTION get_performance_delta(
        p_start_snap NUMBER,
        p_end_snap NUMBER,
        p_metric_name VARCHAR2
    ) RETURN NUMBER IS
        v_delta NUMBER := 0;
    BEGIN
        -- Try to get AWR metrics first
        BEGIN
            SELECT end_value - begin_value INTO v_delta
            FROM (
                SELECT 
                    s1.value as begin_value,
                    s2.value as end_value
                FROM dba_hist_sysstat s1, dba_hist_sysstat s2
                WHERE s1.snap_id = p_start_snap
                AND s2.snap_id = p_end_snap
                AND s1.stat_name = p_metric_name
                AND s2.stat_name = p_metric_name
                AND s1.dbid = s2.dbid
                AND s1.instance_number = s2.instance_number
            );
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Fallback to current session statistics
                SELECT value INTO v_delta
                FROM v$sysstat 
                WHERE name = p_metric_name;
        END;
        
        RETURN v_delta;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END get_performance_delta;

    PROCEDURE compare_test_sessions(
        p_session1_id VARCHAR2,
        p_session2_id VARCHAR2
    ) IS
        v_session1 awr_test_sessions%ROWTYPE;
        v_session2 awr_test_sessions%ROWTYPE;
    BEGIN
        -- Get session details
        SELECT * INTO v_session1 FROM awr_test_sessions WHERE session_id = p_session1_id;
        SELECT * INTO v_session2 FROM awr_test_sessions WHERE session_id = p_session2_id;
        
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('AWR TEST SESSION COMPARISON');
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('Session 1: ' || v_session1.test_name || ' (' || v_session1.session_id || ')');
        DBMS_OUTPUT.PUT_LINE('Session 2: ' || v_session2.test_name || ' (' || v_session2.session_id || ')');
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Compare basic metrics
        DBMS_OUTPUT.PUT_LINE('Duration Comparison:');
        DBMS_OUTPUT.PUT_LINE('  Session 1: ' || ROUND(EXTRACT(EPOCH FROM (v_session1.end_time - v_session1.start_time)), 2) || ' seconds');
        DBMS_OUTPUT.PUT_LINE('  Session 2: ' || ROUND(EXTRACT(EPOCH FROM (v_session2.end_time - v_session2.start_time)), 2) || ' seconds');
        DBMS_OUTPUT.PUT_LINE('');
        
        -- Add more detailed comparison logic here
        DBMS_OUTPUT.PUT_LINE('For detailed performance comparison, use generate_test_report procedure.');
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('❌ One or both test sessions not found');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error comparing sessions: ' || SQLERRM);
    END compare_test_sessions;

    PROCEDURE generate_test_report(
        p_session_id VARCHAR2,
        p_report_type VARCHAR2 DEFAULT 'SUMMARY'
    ) IS
        v_session awr_test_sessions%ROWTYPE;
    BEGIN
        SELECT * INTO v_session FROM awr_test_sessions WHERE session_id = p_session_id;
        
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('AWR TEST REPORT - ' || UPPER(p_report_type));
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('Session ID: ' || v_session.session_id);
        DBMS_OUTPUT.PUT_LINE('Test Name: ' || v_session.test_name);
        DBMS_OUTPUT.PUT_LINE('Test Type: ' || v_session.test_type);
        DBMS_OUTPUT.PUT_LINE('Start Time: ' || v_session.start_time);
        DBMS_OUTPUT.PUT_LINE('End Time: ' || v_session.end_time);
        DBMS_OUTPUT.PUT_LINE('Start Snapshot: ' || v_session.start_snap_id);
        DBMS_OUTPUT.PUT_LINE('End Snapshot: ' || v_session.end_snap_id);
        
        IF v_session.end_time IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('Duration: ' || ROUND(EXTRACT(EPOCH FROM (v_session.end_time - v_session.start_time)), 2) || ' seconds');
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('Status: ' || v_session.status);
        DBMS_OUTPUT.PUT_LINE('==========================================');
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('❌ Test session not found: ' || p_session_id);
    END generate_test_report;

    PROCEDURE cleanup_old_sessions(
        p_days_to_keep NUMBER DEFAULT 30
    ) IS
        v_deleted NUMBER;
    BEGIN
        DELETE FROM awr_test_results 
        WHERE session_id IN (
            SELECT session_id FROM awr_test_sessions 
            WHERE start_time < SYSTIMESTAMP - p_days_to_keep
        );
        
        DELETE FROM awr_test_sessions 
        WHERE start_time < SYSTIMESTAMP - p_days_to_keep;
        
        v_deleted := SQL%ROWCOUNT;
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('🧹 Cleaned up ' || v_deleted || ' old test sessions');
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('❌ Error during cleanup: ' || SQLERRM);
    END cleanup_old_sessions;

END awr_test_manager;
/

DBMS_OUTPUT.PUT_LINE('✅ AWR test manager package created successfully');

-- Test the AWR framework
PROMPT
PROMPT 4. Testing AWR Framework
PROMPT =========================

DECLARE
    v_session_id VARCHAR2(50);
BEGIN
    -- Start a test session
    v_session_id := awr_test_manager.start_test_session(
        p_test_name => 'Framework_Validation_Test',
        p_test_description => 'Initial test of AWR framework functionality',
        p_test_type => 'VALIDATION'
    );
    
    -- Simulate some work
    DBMS_LOCK.SLEEP(2);
    
    -- Execute a sample workload
    FOR i IN 1..1000 LOOP
        NULL; -- Minimal CPU work
    END LOOP;
    
    -- End the test session
    awr_test_manager.end_test_session(v_session_id, 'Framework validation completed');
    
    -- Generate a report
    awr_test_manager.generate_test_report(v_session_id, 'SUMMARY');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Framework test failed: ' || SQLERRM);
END;
/

-- Show test sessions
PROMPT
PROMPT 5. Current Test Sessions
PROMPT =========================

SELECT 
    session_id,
    test_name,
    test_type,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') as start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') as end_time,
    status,
    start_snap_id,
    end_snap_id
FROM awr_test_sessions
ORDER BY start_time DESC;

PROMPT
PROMPT ==========================================
PROMPT AWR Performance Framework Ready!
PROMPT ==========================================
PROMPT
PROMPT Usage Examples:
PROMPT ---------------
PROMPT -- Start a test
PROMPT DECLARE
PROMPT   v_session VARCHAR2(50);
PROMPT BEGIN
PROMPT   v_session := awr_test_manager.start_test_session('My_Test', 'Test description');
PROMPT   -- Run your test workload here
PROMPT   awr_test_manager.end_test_session(v_session);
PROMPT END;
PROMPT /
PROMPT
PROMPT -- Compare two tests
PROMPT EXEC awr_test_manager.compare_test_sessions('session1_id', 'session2_id');
PROMPT
PROMPT -- Generate report
PROMPT EXEC awr_test_manager.generate_test_report('session_id', 'DETAILED');
PROMPT

EXIT;