-- =====================================================
-- Oracle Partition Management Suite - Validation Report
-- Comprehensive validation of all packages and functionality
-- =====================================================

SET ECHO ON
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE 1000000
SET LINESIZE 120
SET PAGESIZE 1000

PROMPT ==========================================
PROMPT Oracle Partition Management Suite
PROMPT Comprehensive Validation Report
PROMPT ==========================================

-- Test database connectivity
PROMPT
PROMPT 1. Database Connectivity Test
PROMPT ==============================

SELECT 
    'CONNECTION_SUCCESS' as status,
    USER as current_user,
    TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') as test_timestamp
FROM dual;

-- Check Oracle version and features
PROMPT
PROMPT 2. Database Version and Features
PROMPT =================================

SELECT 
    banner as oracle_version
FROM v$version 
WHERE banner LIKE 'Oracle%';

SELECT 
    'Partitioning: ' || 
    CASE WHEN value = 'TRUE' THEN 'ENABLED' ELSE 'DISABLED' END as feature_status
FROM v$option 
WHERE parameter = 'Partitioning';

-- Validate package compilation status
PROMPT
PROMPT 3. Package Compilation Status
PROMPT ==============================

SELECT 
    object_name,
    object_type,
    status,
    last_ddl_time
FROM user_objects 
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY')
ORDER BY object_name, 
    CASE object_type 
        WHEN 'PACKAGE' THEN 1 
        WHEN 'PACKAGE BODY' THEN 2 
    END;

-- Check for any compilation errors
PROMPT
PROMPT 4. Compilation Errors Check
PROMPT ============================

DECLARE
    v_error_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_error_count FROM user_errors;
    
    IF v_error_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('✅ No compilation errors found');
    ELSE
        DBMS_OUTPUT.PUT_LINE('❌ Found ' || v_error_count || ' compilation errors:');
        
        FOR err IN (SELECT name, type, line, position, text 
                   FROM user_errors 
                   ORDER BY name, type, line) LOOP
            DBMS_OUTPUT.PUT_LINE('  ' || err.name || ' (' || err.type || ') Line ' || 
                               err.line || ': ' || err.text);
        END LOOP;
    END IF;
END;
/

-- Validate required tables exist
PROMPT
PROMPT 5. Required Tables Validation
PROMPT ==============================

DECLARE
    TYPE table_list_t IS TABLE OF VARCHAR2(30);
    v_required_tables table_list_t := table_list_t(
        'PARTITION_STRATEGY_CONFIG',
        'PARTITION_MAINTENANCE_JOBS', 
        'PARTITION_OPERATION_LOG',
        'OPERATION_LOG'
    );
    v_table_count NUMBER;
    v_missing_tables NUMBER := 0;
BEGIN
    FOR i IN 1..v_required_tables.COUNT LOOP
        SELECT COUNT(*) INTO v_table_count
        FROM user_tables 
        WHERE table_name = v_required_tables(i);
        
        IF v_table_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('❌ Missing table: ' || v_required_tables(i));
            v_missing_tables := v_missing_tables + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('✅ Found table: ' || v_required_tables(i));
        END IF;
    END LOOP;
    
    IF v_missing_tables = 0 THEN
        DBMS_OUTPUT.PUT_LINE('✅ All required tables exist');
    ELSE
        DBMS_OUTPUT.PUT_LINE('❌ Missing ' || v_missing_tables || ' required tables');
    END IF;
END;
/

-- Test package functionality
PROMPT
PROMPT 6. Package Functionality Tests
PROMPT ===============================

-- Test partition_utils_pkg
PROMPT Testing partition_utils_pkg...
DECLARE
    v_version VARCHAR2(100);
BEGIN
    v_version := partition_utils_pkg.get_version;
    DBMS_OUTPUT.PUT_LINE('✅ partition_utils_pkg.get_version: ' || v_version);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ partition_utils_pkg.get_version failed: ' || SQLERRM);
END;
/

-- Test partition_logger_pkg
PROMPT Testing partition_logger_pkg...
BEGIN
    partition_logger_pkg.log_info('Validation test message');
    DBMS_OUTPUT.PUT_LINE('✅ partition_logger_pkg.log_info: SUCCESS');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ partition_logger_pkg.log_info failed: ' || SQLERRM);
END;
/

-- Test partition_strategy_pkg
PROMPT Testing partition_strategy_pkg...
DECLARE
    v_strategy VARCHAR2(100);
BEGIN
    v_strategy := partition_strategy_pkg.evaluate_strategy('TEST_TABLE', SYSDATE);
    DBMS_OUTPUT.PUT_LINE('✅ partition_strategy_pkg.evaluate_strategy: ' || v_strategy);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ partition_strategy_pkg.evaluate_strategy failed: ' || SQLERRM);
END;
/

-- Test create_table_pkg
PROMPT Testing create_table_pkg...
DECLARE
    v_result VARCHAR2(100);
BEGIN
    v_result := create_table_pkg.validate_table_definition('TEST_TABLE');
    DBMS_OUTPUT.PUT_LINE('✅ create_table_pkg.validate_table_definition: ' || v_result);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ create_table_pkg.validate_table_definition failed: ' || SQLERRM);
END;
/

-- Test online_table_operations_pkg
PROMPT Testing online_table_operations_pkg...
DECLARE
    v_exists VARCHAR2(10);
BEGIN
    v_exists := online_table_operations_pkg.check_table_exists('DUAL');
    DBMS_OUTPUT.PUT_LINE('✅ online_table_operations_pkg.check_table_exists: ' || v_exists);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ online_table_operations_pkg.check_table_exists failed: ' || SQLERRM);
END;
/

-- Validate privileges and permissions
PROMPT
PROMPT 7. Privileges and Permissions Check
PROMPT ====================================

SELECT 
    'SELECT on V$PARAMETER: ' || 
    CASE WHEN COUNT(*) > 0 THEN 'GRANTED' ELSE 'MISSING' END as privilege_status
FROM user_tab_privs 
WHERE table_name = 'V_$PARAMETER' AND privilege = 'SELECT'
UNION ALL
SELECT 
    'SELECT on DBA_TABLES: ' || 
    CASE WHEN COUNT(*) > 0 THEN 'GRANTED' ELSE 'MISSING' END
FROM user_tab_privs 
WHERE table_name = 'DBA_TABLES' AND privilege = 'SELECT'
UNION ALL
SELECT 
    'CREATE TABLE: ' || 
    CASE WHEN COUNT(*) > 0 THEN 'GRANTED' ELSE 'MISSING' END
FROM user_sys_privs 
WHERE privilege = 'CREATE TABLE';

-- Performance test - partition pruning
PROMPT
PROMPT 8. Performance Validation
PROMPT ==========================

-- Create a test partitioned table for validation
DECLARE
    v_table_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_table_exists 
    FROM user_tables 
    WHERE table_name = 'TEST_PARTITIONED_TABLE';
    
    IF v_table_exists = 0 THEN
        EXECUTE IMMEDIATE '
            CREATE TABLE test_partitioned_table (
                id NUMBER,
                created_date DATE,
                data VARCHAR2(100)
            ) PARTITION BY RANGE (created_date) (
                PARTITION p_2024_q1 VALUES LESS THAN (DATE ''2024-04-01''),
                PARTITION p_2024_q2 VALUES LESS THAN (DATE ''2024-07-01''),
                PARTITION p_2024_q3 VALUES LESS THAN (DATE ''2024-10-01''),
                PARTITION p_2024_q4 VALUES LESS THAN (DATE ''2025-01-01'')
            )';
        DBMS_OUTPUT.PUT_LINE('✅ Created test partitioned table');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✅ Test partitioned table already exists');
    END IF;
END;
/

-- Test partition pruning
EXPLAIN PLAN FOR 
SELECT * FROM test_partitioned_table 
WHERE created_date BETWEEN DATE '2024-01-01' AND DATE '2024-03-31';

PROMPT Partition pruning test (should show only P_2024_Q1 accessed):
SELECT plan_table_output 
FROM TABLE(DBMS_XPLAN.DISPLAY('PLAN_TABLE', NULL, 'BASIC +PARTITION'));

-- Resource utilization check (Always Free tier compliance)
PROMPT
PROMPT 9. Always Free Tier Compliance
PROMPT ===============================

SELECT 
    'CPU_COUNT: ' || value as metric 
FROM v$parameter 
WHERE name = 'cpu_count'
UNION ALL
SELECT 
    'SGA_TARGET: ' || ROUND(value/1024/1024) || ' MB'
FROM v$parameter 
WHERE name = 'sga_target'
UNION ALL
SELECT 
    'DB_SIZE_GB: ' || ROUND(SUM(bytes)/1024/1024/1024,2)
FROM (
    SELECT bytes FROM dba_data_files
    UNION ALL
    SELECT bytes FROM dba_temp_files
    UNION ALL  
    SELECT bytes * members FROM v$log
)
UNION ALL
SELECT 
    'SESSIONS: ' || COUNT(*)
FROM v$session 
WHERE type = 'USER';

-- Final validation summary
PROMPT
PROMPT 10. Final Validation Summary
PROMPT =============================

DECLARE
    v_invalid_objects NUMBER;
    v_compilation_errors NUMBER;
    v_missing_tables NUMBER;
    v_overall_status VARCHAR2(20);
    
    TYPE table_list_t IS TABLE OF VARCHAR2(30);
    v_required_tables table_list_t := table_list_t(
        'PARTITION_STRATEGY_CONFIG',
        'PARTITION_MAINTENANCE_JOBS', 
        'PARTITION_OPERATION_LOG',
        'OPERATION_LOG'
    );
    v_table_count NUMBER;
BEGIN
    -- Count invalid objects
    SELECT COUNT(*) INTO v_invalid_objects
    FROM user_objects 
    WHERE object_type IN ('PACKAGE', 'PACKAGE BODY') 
    AND status != 'VALID';
    
    -- Count compilation errors
    SELECT COUNT(*) INTO v_compilation_errors FROM user_errors;
    
    -- Count missing tables
    v_missing_tables := 0;
    FOR i IN 1..v_required_tables.COUNT LOOP
        SELECT COUNT(*) INTO v_table_count
        FROM user_tables 
        WHERE table_name = v_required_tables(i);
        
        IF v_table_count = 0 THEN
            v_missing_tables := v_missing_tables + 1;
        END IF;
    END LOOP;
    
    -- Determine overall status
    IF v_invalid_objects = 0 AND v_compilation_errors = 0 AND v_missing_tables = 0 THEN
        v_overall_status := 'PASSED';
    ELSE
        v_overall_status := 'FAILED';
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('VALIDATION SUMMARY');
    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('Invalid Objects: ' || v_invalid_objects);
    DBMS_OUTPUT.PUT_LINE('Compilation Errors: ' || v_compilation_errors); 
    DBMS_OUTPUT.PUT_LINE('Missing Tables: ' || v_missing_tables);
    DBMS_OUTPUT.PUT_LINE('Overall Status: ' || v_overall_status);
    DBMS_OUTPUT.PUT_LINE('==========================================');
    
    IF v_overall_status = 'PASSED' THEN
        DBMS_OUTPUT.PUT_LINE('✅ ALL PACKAGES VALIDATED SUCCESSFULLY');
        DBMS_OUTPUT.PUT_LINE('🎉 Oracle Partition Management Suite is ready for use!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('❌ VALIDATION FAILED - Please review errors above');
    END IF;
END;
/

-- Cleanup test table
DROP TABLE test_partitioned_table PURGE;

PROMPT
PROMPT Validation report completed.
PROMPT Check output above for detailed results.

EXIT;