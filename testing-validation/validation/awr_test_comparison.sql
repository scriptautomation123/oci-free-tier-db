-- =====================================================
-- AWR Test Comparison Framework
-- Compare performance metrics across different test runs
-- =====================================================

SET ECHO ON
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE 1000000
SET LINESIZE 150
SET PAGESIZE 1000

PROMPT ==========================================
PROMPT AWR Test Comparison Framework
PROMPT Performance Regression and Improvement Analysis
PROMPT ==========================================

-- Create test comparison package
CREATE OR REPLACE PACKAGE awr_test_comparator AS
    -- Compare two test sessions
    PROCEDURE compare_sessions(
        p_baseline_session VARCHAR2,
        p_comparison_session VARCHAR2,
        p_threshold_pct NUMBER DEFAULT 10
    );
    
    -- Compare multiple sessions against baseline
    PROCEDURE compare_multiple_sessions(
        p_baseline_session VARCHAR2,
        p_comparison_sessions VARCHAR2, -- Comma-separated list
        p_threshold_pct NUMBER DEFAULT 10
    );
    
    -- Identify performance regressions
    PROCEDURE identify_regressions(
        p_baseline_session VARCHAR2,
        p_comparison_session VARCHAR2,
        p_regression_threshold NUMBER DEFAULT 20
    );
    
    -- Generate trend analysis
    PROCEDURE analyze_performance_trends(
        p_test_pattern VARCHAR2 DEFAULT '%', -- Pattern to match session IDs
        p_metric_name VARCHAR2 DEFAULT '%'
    );
    
    -- Create baseline from session
    PROCEDURE create_baseline(
        p_session_id VARCHAR2,
        p_baseline_name VARCHAR2
    );
    
    -- Compare against baseline
    PROCEDURE compare_to_baseline(
        p_session_id VARCHAR2,
        p_baseline_name VARCHAR2
    );
    
    -- Export comparison results
    PROCEDURE export_comparison_results(
        p_baseline_session VARCHAR2,
        p_comparison_session VARCHAR2,
        p_format VARCHAR2 DEFAULT 'TEXT' -- TEXT, CSV, HTML
    );
    
END awr_test_comparator;
/

CREATE OR REPLACE PACKAGE BODY awr_test_comparator AS

    PROCEDURE compare_sessions(
        p_baseline_session VARCHAR2,
        p_comparison_session VARCHAR2,
        p_threshold_pct NUMBER DEFAULT 10
    ) IS
        CURSOR c_comparison IS
            SELECT 
                b.metric_name,
                b.metric_value as baseline_value,
                c.metric_value as comparison_value,
                b.metric_unit,
                CASE 
                    WHEN b.metric_value > 0 THEN 
                        ROUND(((c.metric_value - b.metric_value) / b.metric_value) * 100, 2)
                    ELSE 0 
                END as pct_change,
                CASE 
                    WHEN b.metric_value > 0 THEN 
                        c.metric_value - b.metric_value
                    ELSE 0 
                END as absolute_change,
                CASE 
                    WHEN b.metric_value > 0 AND ABS(((c.metric_value - b.metric_value) / b.metric_value) * 100) > p_threshold_pct THEN
                        CASE 
                            WHEN c.metric_value > b.metric_value THEN 'REGRESSION'
                            ELSE 'IMPROVEMENT'
                        END
                    ELSE 'STABLE'
                END as performance_status
            FROM (
                SELECT metric_name, AVG(metric_value) as metric_value, metric_unit
                FROM awr_test_results 
                WHERE session_id = p_baseline_session
                GROUP BY metric_name, metric_unit
            ) b
            JOIN (
                SELECT metric_name, AVG(metric_value) as metric_value, metric_unit
                FROM awr_test_results 
                WHERE session_id = p_comparison_session
                GROUP BY metric_name, metric_unit
            ) c ON b.metric_name = c.metric_name
            ORDER BY ABS(c.metric_value - b.metric_value) DESC;
            
        v_baseline_info awr_test_sessions%ROWTYPE;
        v_comparison_info awr_test_sessions%ROWTYPE;
        v_regression_count NUMBER := 0;
        v_improvement_count NUMBER := 0;
        v_stable_count NUMBER := 0;
    BEGIN
        -- Get session information
        SELECT * INTO v_baseline_info FROM awr_test_sessions WHERE session_id = p_baseline_session;
        SELECT * INTO v_comparison_info FROM awr_test_sessions WHERE session_id = p_comparison_session;
        
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('TEST SESSION COMPARISON ANALYSIS');
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('Baseline Session: ' || p_baseline_session);
        DBMS_OUTPUT.PUT_LINE('  Test Name: ' || v_baseline_info.test_name);
        DBMS_OUTPUT.PUT_LINE('  Start Time: ' || TO_CHAR(v_baseline_info.start_time, 'DD-MON-YYYY HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('  Duration: ' || ROUND((v_baseline_info.end_time - v_baseline_info.start_time) * 24 * 60, 2) || ' minutes');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Comparison Session: ' || p_comparison_session);
        DBMS_OUTPUT.PUT_LINE('  Test Name: ' || v_comparison_info.test_name);
        DBMS_OUTPUT.PUT_LINE('  Start Time: ' || TO_CHAR(v_comparison_info.start_time, 'DD-MON-YYYY HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('  Duration: ' || ROUND((v_comparison_info.end_time - v_comparison_info.start_time) * 24 * 60, 2) || ' minutes');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('Performance Threshold: ' || p_threshold_pct || '%');
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE(RPAD('Metric', 30) || RPAD('Baseline', 15) || RPAD('Current', 15) || RPAD('Change%', 10) || RPAD('Status', 12) || 'Unit');
        DBMS_OUTPUT.PUT_LINE(RPAD('-', 30, '-') || RPAD('-', 15, '-') || RPAD('-', 15, '-') || RPAD('-', 10, '-') || RPAD('-', 12, '-') || RPAD('-', 10, '-'));
        
        FOR rec IN c_comparison LOOP
            DBMS_OUTPUT.PUT_LINE(
                RPAD(SUBSTR(rec.metric_name, 1, 29), 30) ||
                RPAD(TO_CHAR(rec.baseline_value, '999999999.99'), 15) ||
                RPAD(TO_CHAR(rec.comparison_value, '999999999.99'), 15) ||
                RPAD(TO_CHAR(rec.pct_change, 'S9990.9'), 10) ||
                RPAD(
                    CASE rec.performance_status
                        WHEN 'REGRESSION' THEN '🔴 ' || rec.performance_status
                        WHEN 'IMPROVEMENT' THEN '🟢 ' || rec.performance_status
                        ELSE '⚪ ' || rec.performance_status
                    END, 12) ||
                rec.metric_unit
            );
            
            -- Count status types
            CASE rec.performance_status
                WHEN 'REGRESSION' THEN v_regression_count := v_regression_count + 1;
                WHEN 'IMPROVEMENT' THEN v_improvement_count := v_improvement_count + 1;
                ELSE v_stable_count := v_stable_count + 1;
            END CASE;
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('SUMMARY');
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('🔴 Regressions: ' || v_regression_count);
        DBMS_OUTPUT.PUT_LINE('🟢 Improvements: ' || v_improvement_count);
        DBMS_OUTPUT.PUT_LINE('⚪ Stable: ' || v_stable_count);
        DBMS_OUTPUT.PUT_LINE('');
        
        IF v_regression_count > 0 THEN
            DBMS_OUTPUT.PUT_LINE('⚠️  ATTENTION: Performance regressions detected!');
        ELSIF v_improvement_count > v_regression_count THEN
            DBMS_OUTPUT.PUT_LINE('✅ Overall performance improvement detected');
        ELSE
            DBMS_OUTPUT.PUT_LINE('ℹ️  Performance is stable within threshold');
        END IF;
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('❌ One or both test sessions not found');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error comparing sessions: ' || SQLERRM);
    END compare_sessions;

    PROCEDURE identify_regressions(
        p_baseline_session VARCHAR2,
        p_comparison_session VARCHAR2,
        p_regression_threshold NUMBER DEFAULT 20
    ) IS
        CURSOR c_regressions IS
            SELECT 
                b.metric_name,
                b.metric_value as baseline_value,
                c.metric_value as comparison_value,
                b.metric_unit,
                ROUND(((c.metric_value - b.metric_value) / b.metric_value) * 100, 2) as pct_change,
                b.notes as baseline_notes,
                c.notes as comparison_notes
            FROM (
                SELECT metric_name, AVG(metric_value) as metric_value, metric_unit, 
                       LISTAGG(notes, '; ') WITHIN GROUP (ORDER BY created_date) as notes
                FROM awr_test_results 
                WHERE session_id = p_baseline_session
                GROUP BY metric_name, metric_unit
            ) b
            JOIN (
                SELECT metric_name, AVG(metric_value) as metric_value, metric_unit,
                       LISTAGG(notes, '; ') WITHIN GROUP (ORDER BY created_date) as notes
                FROM awr_test_results 
                WHERE session_id = p_comparison_session
                GROUP BY metric_name, metric_unit
            ) c ON b.metric_name = c.metric_name
            WHERE b.metric_value > 0 
            AND ((c.metric_value - b.metric_value) / b.metric_value) * 100 > p_regression_threshold
            ORDER BY ((c.metric_value - b.metric_value) / b.metric_value) DESC;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('PERFORMANCE REGRESSION ANALYSIS');
        DBMS_OUTPUT.PUT_LINE('Regression Threshold: ' || p_regression_threshold || '%');
        DBMS_OUTPUT.PUT_LINE('==========================================');
        
        FOR rec IN c_regressions LOOP
            DBMS_OUTPUT.PUT_LINE('🔴 REGRESSION DETECTED:');
            DBMS_OUTPUT.PUT_LINE('  Metric: ' || rec.metric_name);
            DBMS_OUTPUT.PUT_LINE('  Baseline: ' || TO_CHAR(rec.baseline_value, '999,999,999.99') || ' ' || rec.metric_unit);
            DBMS_OUTPUT.PUT_LINE('  Current: ' || TO_CHAR(rec.comparison_value, '999,999,999.99') || ' ' || rec.metric_unit);
            DBMS_OUTPUT.PUT_LINE('  Regression: ' || TO_CHAR(rec.pct_change, '990.99') || '%');
            
            IF rec.baseline_notes IS NOT NULL THEN
                DBMS_OUTPUT.PUT_LINE('  Baseline Context: ' || SUBSTR(rec.baseline_notes, 1, 100));
            END IF;
            
            IF rec.comparison_notes IS NOT NULL THEN
                DBMS_OUTPUT.PUT_LINE('  Current Context: ' || SUBSTR(rec.comparison_notes, 1, 100));
            END IF;
            
            DBMS_OUTPUT.PUT_LINE('  ');
        END LOOP;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error identifying regressions: ' || SQLERRM);
    END identify_regressions;

    PROCEDURE analyze_performance_trends(
        p_test_pattern VARCHAR2 DEFAULT '%',
        p_metric_name VARCHAR2 DEFAULT '%'
    ) IS
        CURSOR c_trends IS
            SELECT 
                s.session_id,
                s.test_name,
                s.start_time,
                r.metric_name,
                AVG(r.metric_value) as avg_value,
                r.metric_unit,
                ROW_NUMBER() OVER (PARTITION BY r.metric_name ORDER BY s.start_time) as time_order
            FROM awr_test_sessions s
            JOIN awr_test_results r ON s.session_id = r.session_id
            WHERE s.session_id LIKE p_test_pattern
            AND r.metric_name LIKE p_metric_name
            GROUP BY s.session_id, s.test_name, s.start_time, r.metric_name, r.metric_unit
            ORDER BY r.metric_name, s.start_time;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('PERFORMANCE TREND ANALYSIS');
        DBMS_OUTPUT.PUT_LINE('Test Pattern: ' || p_test_pattern);
        DBMS_OUTPUT.PUT_LINE('Metric Pattern: ' || p_metric_name);
        DBMS_OUTPUT.PUT_LINE('==========================================');
        
        FOR rec IN c_trends LOOP
            DBMS_OUTPUT.PUT_LINE(
                TO_CHAR(rec.start_time, 'DD-MON HH24:MI') || ' | ' ||
                RPAD(rec.session_id, 20) || ' | ' ||
                RPAD(rec.metric_name, 25) || ' | ' ||
                TO_CHAR(rec.avg_value, '999,999.99') || ' ' || rec.metric_unit
            );
        END LOOP;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error analyzing trends: ' || SQLERRM);
    END analyze_performance_trends;

    PROCEDURE create_baseline(
        p_session_id VARCHAR2,
        p_baseline_name VARCHAR2
    ) IS
    BEGIN
        -- Create a baseline entry by copying results with baseline flag
        INSERT INTO awr_test_results (session_id, metric_name, metric_value, metric_unit, notes, created_date)
        SELECT 
            p_baseline_name || '_BASELINE',
            metric_name,
            metric_value,
            metric_unit,
            'BASELINE from ' || session_id || ' - ' || NVL(notes, ''),
            SYSDATE
        FROM awr_test_results
        WHERE session_id = p_session_id;
        
        -- Create baseline session entry
        INSERT INTO awr_test_sessions (session_id, test_name, start_time, end_time, start_snap_id, end_snap_id, description)
        SELECT 
            p_baseline_name || '_BASELINE',
            'BASELINE: ' || test_name,
            start_time,
            end_time,
            start_snap_id,
            end_snap_id,
            'Baseline created from session ' || session_id
        FROM awr_test_sessions
        WHERE session_id = p_session_id;
        
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('✅ Baseline created: ' || p_baseline_name || '_BASELINE');
        DBMS_OUTPUT.PUT_LINE('   Source session: ' || p_session_id);
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('❌ Error creating baseline: ' || SQLERRM);
    END create_baseline;

    PROCEDURE compare_to_baseline(
        p_session_id VARCHAR2,
        p_baseline_name VARCHAR2
    ) IS
    BEGIN
        compare_sessions(p_baseline_name || '_BASELINE', p_session_id);
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error comparing to baseline: ' || SQLERRM);
    END compare_to_baseline;

    PROCEDURE export_comparison_results(
        p_baseline_session VARCHAR2,
        p_comparison_session VARCHAR2,
        p_format VARCHAR2 DEFAULT 'TEXT'
    ) IS
    BEGIN
        IF UPPER(p_format) = 'CSV' THEN
            DBMS_OUTPUT.PUT_LINE('Session,Metric,Baseline_Value,Comparison_Value,Percent_Change,Status,Unit');
            
            FOR rec IN (
                SELECT 
                    p_comparison_session as session_id,
                    b.metric_name,
                    b.metric_value as baseline_value,
                    c.metric_value as comparison_value,
                    CASE 
                        WHEN b.metric_value > 0 THEN 
                            ROUND(((c.metric_value - b.metric_value) / b.metric_value) * 100, 2)
                        ELSE 0 
                    END as pct_change,
                    CASE 
                        WHEN b.metric_value > 0 AND ABS(((c.metric_value - b.metric_value) / b.metric_value) * 100) > 10 THEN
                            CASE 
                                WHEN c.metric_value > b.metric_value THEN 'REGRESSION'
                                ELSE 'IMPROVEMENT'
                            END
                        ELSE 'STABLE'
                    END as performance_status,
                    b.metric_unit
                FROM (
                    SELECT metric_name, AVG(metric_value) as metric_value, metric_unit
                    FROM awr_test_results 
                    WHERE session_id = p_baseline_session
                    GROUP BY metric_name, metric_unit
                ) b
                JOIN (
                    SELECT metric_name, AVG(metric_value) as metric_value, metric_unit
                    FROM awr_test_results 
                    WHERE session_id = p_comparison_session
                    GROUP BY metric_name, metric_unit
                ) c ON b.metric_name = c.metric_name
            ) LOOP
                DBMS_OUTPUT.PUT_LINE(
                    rec.session_id || ',' ||
                    rec.metric_name || ',' ||
                    rec.baseline_value || ',' ||
                    rec.comparison_value || ',' ||
                    rec.pct_change || ',' ||
                    rec.performance_status || ',' ||
                    rec.metric_unit
                );
            END LOOP;
        ELSE
            -- Default to TEXT format
            compare_sessions(p_baseline_session, p_comparison_session);
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error exporting results: ' || SQLERRM);
    END export_comparison_results;

    PROCEDURE compare_multiple_sessions(
        p_baseline_session VARCHAR2,
        p_comparison_sessions VARCHAR2,
        p_threshold_pct NUMBER DEFAULT 10
    ) IS
        v_session_list VARCHAR2(4000) := p_comparison_sessions;
        v_session VARCHAR2(100);
        v_pos NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('==========================================');
        DBMS_OUTPUT.PUT_LINE('MULTIPLE SESSION COMPARISON');
        DBMS_OUTPUT.PUT_LINE('Baseline: ' || p_baseline_session);
        DBMS_OUTPUT.PUT_LINE('==========================================');
        
        -- Parse comma-separated list
        WHILE LENGTH(v_session_list) > 0 LOOP
            v_pos := INSTR(v_session_list, ',');
            
            IF v_pos > 0 THEN
                v_session := TRIM(SUBSTR(v_session_list, 1, v_pos - 1));
                v_session_list := TRIM(SUBSTR(v_session_list, v_pos + 1));
            ELSE
                v_session := TRIM(v_session_list);
                v_session_list := '';
            END IF;
            
            IF LENGTH(v_session) > 0 THEN
                DBMS_OUTPUT.PUT_LINE('');
                DBMS_OUTPUT.PUT_LINE('Comparing session: ' || v_session);
                DBMS_OUTPUT.PUT_LINE('==========================================');
                compare_sessions(p_baseline_session, v_session, p_threshold_pct);
            END IF;
        END LOOP;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('❌ Error comparing multiple sessions: ' || SQLERRM);
    END compare_multiple_sessions;

END awr_test_comparator;
/

DBMS_OUTPUT.PUT_LINE('✅ AWR Test Comparator package created successfully');

-- Create a test comparison report view
CREATE OR REPLACE VIEW v_awr_test_comparison AS
SELECT 
    s1.session_id as baseline_session,
    s1.test_name as baseline_test,
    s1.start_time as baseline_start,
    s2.session_id as comparison_session,
    s2.test_name as comparison_test,
    s2.start_time as comparison_start,
    r1.metric_name,
    r1.metric_value as baseline_value,
    r2.metric_value as comparison_value,
    r1.metric_unit,
    CASE 
        WHEN r1.metric_value > 0 THEN 
            ROUND(((r2.metric_value - r1.metric_value) / r1.metric_value) * 100, 2)
        ELSE 0 
    END as pct_change,
    CASE 
        WHEN r1.metric_value > 0 AND ABS(((r2.metric_value - r1.metric_value) / r1.metric_value) * 100) > 10 THEN
            CASE 
                WHEN r2.metric_value > r1.metric_value THEN 'REGRESSION'
                ELSE 'IMPROVEMENT'
            END
        ELSE 'STABLE'
    END as performance_status
FROM awr_test_sessions s1
JOIN awr_test_results r1 ON s1.session_id = r1.session_id
JOIN awr_test_sessions s2 ON s2.session_id != s1.session_id
JOIN awr_test_results r2 ON s2.session_id = r2.session_id AND r1.metric_name = r2.metric_name;

DBMS_OUTPUT.PUT_LINE('✅ AWR test comparison view created successfully');

PROMPT
PROMPT ==========================================
PROMPT AWR Test Comparison Framework Ready!
PROMPT ==========================================
PROMPT
PROMPT Usage Examples:
PROMPT ---------------
PROMPT -- Compare two sessions
PROMPT EXEC awr_test_comparator.compare_sessions('baseline_session', 'comparison_session');
PROMPT
PROMPT -- Identify regressions with 20% threshold
PROMPT EXEC awr_test_comparator.identify_regressions('baseline_session', 'comparison_session', 20);
PROMPT
PROMPT -- Create baseline for future comparisons
PROMPT EXEC awr_test_comparator.create_baseline('session_id', 'my_baseline');
PROMPT
PROMPT -- Compare against baseline
PROMPT EXEC awr_test_comparator.compare_to_baseline('current_session', 'my_baseline');
PROMPT
PROMPT -- Analyze trends across multiple sessions
PROMPT EXEC awr_test_comparator.analyze_performance_trends('test_%', 'CPU%');
PROMPT
PROMPT -- Export comparison results as CSV
PROMPT EXEC awr_test_comparator.export_comparison_results('baseline', 'comparison', 'CSV');
PROMPT
PROMPT -- Query comparison view
PROMPT SELECT * FROM v_awr_test_comparison WHERE performance_status = 'REGRESSION';
PROMPT

EXIT;