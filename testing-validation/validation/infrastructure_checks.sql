-- =====================================================
-- Oracle Cloud Infrastructure Validation Script
-- Always Free Tier compliance and performance checks
-- =====================================================

SET ECHO ON
SET FEEDBACK ON  
SET SERVEROUTPUT ON SIZE 1000000
SET LINESIZE 120
SET PAGESIZE 1000

PROMPT ==========================================
PROMPT Oracle Cloud Infrastructure Validation
PROMPT Always Free Tier Compliance Check
PROMPT ==========================================

-- 1. Database Version and Edition
PROMPT
PROMPT 1. Database Information
PROMPT =======================

SELECT 
    banner,
    CASE WHEN banner LIKE '%Enterprise%' THEN 'Enterprise Edition'
         WHEN banner LIKE '%Express%' THEN 'Express Edition'  
         WHEN banner LIKE '%Standard%' THEN 'Standard Edition'
         ELSE 'Unknown Edition'
    END as edition
FROM v$version 
WHERE banner LIKE 'Oracle%';

SELECT 
    instance_name,
    host_name,
    version,
    startup_time,
    status,
    database_status
FROM v$instance;

-- 2. Always Free Tier Resource Limits
PROMPT
PROMPT 2. Always Free Tier Resource Validation
PROMPT ========================================

DECLARE
    v_cpu_count NUMBER;
    v_sga_size NUMBER;
    v_db_size NUMBER;
    v_session_count NUMBER;
    v_compliance_status VARCHAR2(20) := 'COMPLIANT';
    v_warnings NUMBER := 0;
BEGIN
    -- Check CPU count (Always Free: 1 OCPU, may show as 2 due to hyperthreading)
    SELECT value INTO v_cpu_count FROM v$parameter WHERE name = 'cpu_count';
    DBMS_OUTPUT.PUT_LINE('CPU Count: ' || v_cpu_count);
    IF v_cpu_count > 2 THEN
        DBMS_OUTPUT.PUT_LINE('⚠️  WARNING: CPU count exceeds Always Free limit');
        v_compliance_status := 'WARNING';
        v_warnings := v_warnings + 1;
    ELSE
        DBMS_OUTPUT.PUT_LINE('✅ CPU count within Always Free limits');
    END IF;
    
    -- Check SGA size (Always Free: typically 768MB-1GB)
    SELECT value/1024/1024 INTO v_sga_size FROM v$parameter WHERE name = 'sga_target';
    DBMS_OUTPUT.PUT_LINE('SGA Target: ' || ROUND(v_sga_size) || ' MB');
    IF v_sga_size > 2048 THEN
        DBMS_OUTPUT.PUT_LINE('⚠️  WARNING: SGA size may exceed Always Free guidelines');
        v_compliance_status := 'WARNING';
        v_warnings := v_warnings + 1;
    ELSE
        DBMS_OUTPUT.PUT_LINE('✅ SGA size within expected range');
    END IF;
    
    -- Check database size (Always Free: 20GB limit)
    SELECT ROUND(SUM(bytes)/1024/1024/1024,2) INTO v_db_size
    FROM (
        SELECT bytes FROM dba_data_files
        UNION ALL
        SELECT bytes FROM dba_temp_files
    );
    DBMS_OUTPUT.PUT_LINE('Database Size: ' || v_db_size || ' GB');
    IF v_db_size > 18 THEN
        DBMS_OUTPUT.PUT_LINE('⚠️  WARNING: Database size approaching 20GB Always Free limit');
        v_compliance_status := 'WARNING';
        v_warnings := v_warnings + 1;
    ELSE
        DBMS_OUTPUT.PUT_LINE('✅ Database size within Always Free limits');
    END IF;
    
    -- Check active sessions (Always Free: typically 50-100 concurrent)
    SELECT COUNT(*) INTO v_session_count FROM v$session WHERE type = 'USER' AND status = 'ACTIVE';
    DBMS_OUTPUT.PUT_LINE('Active User Sessions: ' || v_session_count);
    IF v_session_count > 50 THEN
        DBMS_OUTPUT.PUT_LINE('⚠️  WARNING: High session count may impact Always Free performance');
        v_compliance_status := 'WARNING';
        v_warnings := v_warnings + 1;
    ELSE
        DBMS_OUTPUT.PUT_LINE('✅ Session count within reasonable limits');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Overall Compliance Status: ' || v_compliance_status);
    DBMS_OUTPUT.PUT_LINE('Warnings: ' || v_warnings);
END;
/

-- 3. Performance and Feature Availability
PROMPT
PROMPT 3. Performance and Features
PROMPT ============================

-- Check partitioning availability
SELECT 
    parameter,
    value,
    CASE value 
        WHEN 'TRUE' THEN '✅ Available'
        ELSE '❌ Not Available'
    END as status
FROM v$option 
WHERE parameter IN ('Partitioning', 'Advanced Compression', 'OLAP', 'Data Mining');

-- Check parallel execution capability
PROMPT
PROMPT Parallel Execution Configuration:
SELECT 
    name,
    value,
    description
FROM v$parameter 
WHERE name IN ('parallel_max_servers', 'parallel_min_servers', 'cpu_count')
ORDER BY name;

-- 4. Storage and Tablespace Analysis
PROMPT
PROMPT 4. Storage Analysis
PROMPT ===================

SELECT 
    tablespace_name,
    ROUND(total_mb/1024, 2) as total_gb,
    ROUND(used_mb/1024, 2) as used_gb,
    ROUND(free_mb/1024, 2) as free_gb,
    ROUND((used_mb/total_mb)*100, 1) as pct_used
FROM (
    SELECT 
        ts.tablespace_name,
        NVL(df.total_mb, 0) as total_mb,
        NVL(df.total_mb - fs.free_mb, 0) as used_mb,
        NVL(fs.free_mb, 0) as free_mb
    FROM 
        (SELECT DISTINCT tablespace_name FROM dba_tablespaces) ts
    LEFT JOIN 
        (SELECT tablespace_name, ROUND(SUM(bytes)/1024/1024) as total_mb
         FROM dba_data_files GROUP BY tablespace_name) df
        ON ts.tablespace_name = df.tablespace_name
    LEFT JOIN
        (SELECT tablespace_name, ROUND(SUM(bytes)/1024/1024) as free_mb
         FROM dba_free_space GROUP BY tablespace_name) fs
        ON ts.tablespace_name = fs.tablespace_name
)
ORDER BY used_gb DESC;

-- 5. Network and Connectivity
PROMPT
PROMPT 5. Network Configuration
PROMPT =========================

-- Check TNS configuration
SHOW PARAMETER service_names;
SHOW PARAMETER dispatchers;

-- Check database services
SELECT 
    name,
    network_name,
    enabled,
    CASE enabled 
        WHEN 'YES' THEN '✅ Enabled'
        ELSE '❌ Disabled'
    END as status
FROM v$services
WHERE name NOT LIKE 'SYS%'
ORDER BY name;

-- 6. Security Configuration
PROMPT
PROMPT 6. Security Configuration
PROMPT ==========================

-- Check password policies
SELECT 
    profile,
    resource_name,
    limit
FROM dba_profiles 
WHERE profile = 'DEFAULT' 
AND resource_type = 'PASSWORD'
ORDER BY resource_name;

-- Check audit configuration
SELECT 
    parameter_name,
    parameter_value,
    CASE parameter_value
        WHEN 'TRUE' THEN '✅ Enabled'
        WHEN 'FALSE' THEN '⚠️  Disabled'
        ELSE parameter_value
    END as status
FROM v$option 
WHERE parameter_name LIKE '%AUDIT%';

-- 7. Backup and Recovery Readiness
PROMPT
PROMPT 7. Backup Configuration
PROMPT ========================

-- Check archivelog mode
SELECT 
    name,
    log_mode,
    CASE log_mode
        WHEN 'ARCHIVELOG' THEN '✅ Archive logging enabled'
        ELSE '⚠️  Archive logging disabled'
    END as backup_readiness
FROM v$database;

-- Check automatic backup configuration
SELECT 
    'RMAN Configuration' as component,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ RMAN configured'
        ELSE '⚠️  RMAN not configured'
    END as status
FROM v$rman_configuration;

-- 8. Overall Health Check
PROMPT
PROMPT 8. Database Health Summary
PROMPT ===========================

DECLARE
    v_invalid_objects NUMBER;
    v_failed_jobs NUMBER;
    v_alert_log_errors NUMBER;
    v_health_status VARCHAR2(20);
BEGIN
    -- Check for invalid objects
    SELECT COUNT(*) INTO v_invalid_objects
    FROM dba_objects 
    WHERE status = 'INVALID' 
    AND owner NOT IN ('SYS', 'SYSTEM', 'AUDSYS', 'GSMADMIN_INTERNAL');
    
    -- Check for failed scheduled jobs
    SELECT COUNT(*) INTO v_failed_jobs
    FROM dba_scheduler_jobs 
    WHERE state = 'FAILED' 
    AND last_start_date > SYSDATE - 1;
    
    -- Simple health assessment
    IF v_invalid_objects = 0 AND v_failed_jobs = 0 THEN
        v_health_status := 'HEALTHY';
    ELSIF v_invalid_objects <= 5 AND v_failed_jobs <= 2 THEN
        v_health_status := 'WARNING';
    ELSE
        v_health_status := 'ATTENTION_NEEDED';
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('DATABASE HEALTH SUMMARY');
    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('Invalid Objects: ' || v_invalid_objects);
    DBMS_OUTPUT.PUT_LINE('Failed Jobs (24h): ' || v_failed_jobs);
    DBMS_OUTPUT.PUT_LINE('Overall Health: ' || v_health_status);
    DBMS_OUTPUT.PUT_LINE('==========================================');
    
    CASE v_health_status
        WHEN 'HEALTHY' THEN
            DBMS_OUTPUT.PUT_LINE('✅ Database is healthy and ready for production use');
        WHEN 'WARNING' THEN  
            DBMS_OUTPUT.PUT_LINE('⚠️  Database has minor issues - review recommended');
        ELSE
            DBMS_OUTPUT.PUT_LINE('❌ Database needs attention - review issues above');
    END CASE;
END;
/

PROMPT
PROMPT Infrastructure validation completed.
PROMPT Check output above for compliance and performance details.

EXIT;