# AWR Performance Monitoring Framework

This directory contains a comprehensive AWR (Automatic Workload Repository) performance monitoring framework designed for Oracle Database environments, with specific support for Oracle Cloud Infrastructure Always Free tier.

## Overview

The AWR performance monitoring framework provides enterprise-level performance monitoring capabilities including:

- **Automatic snapshot management** - Start/end snapshots for test sessions
- **Performance metric collection** - System stats, SQL performance, wait events, I/O analysis
- **Test comparison framework** - Compare performance across different test runs
- **Regression detection** - Identify performance degradations with configurable thresholds
- **Trend analysis** - Track performance metrics over time
- **Baseline management** - Create and compare against performance baselines

## Files Description

### Core Framework Files

| File | Purpose | Description |
|------|---------|-------------|
| `awr_performance_framework.sql` | Main framework | Core AWR test management package with snapshot handling |
| `awr_analysis_queries.sql` | Performance analysis | Comprehensive performance metrics extraction and analysis |
| `awr_test_comparison.sql` | Test comparison | Compare performance metrics across different test runs |
| `validation_report.sql` | Package validation | Validates Oracle partition management suite deployment |
| `infrastructure_checks.sql` | Infrastructure validation | Database configuration and Always Free tier compliance |
| `performance_benchmarks.sql` | Performance testing | Standard performance benchmark tests |

### Integration Files

| File | Purpose | Description |
|------|---------|-------------|
| `test-and-validate.yml` | Ansible integration | Automated deployment and testing with AWR monitoring |
| `test-and-validate-only.yml` | Standalone testing | Independent test execution playbook |

## Quick Start

### 1. Deploy AWR Framework

```sql
-- Initialize the main AWR framework
@awr_performance_framework.sql

-- Deploy analysis queries
@awr_analysis_queries.sql

-- Deploy comparison framework
@awr_test_comparison.sql
```

### 2. Run Performance Test Session

```sql
-- Start a test session
DECLARE
  v_session_id VARCHAR2(100) := 'MY_TEST_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS');
  v_start_snap NUMBER;
  v_end_snap NUMBER;
BEGIN
  -- Start test with AWR snapshot
  v_start_snap := awr_test_manager.start_test_session(v_session_id, 'My Performance Test');

  -- Run your tests here
  -- ... test code ...

  -- End test session
  v_end_snap := awr_test_manager.end_test_session(v_session_id);

  -- Generate performance report
  awr_performance_analyzer.generate_performance_summary(v_session_id);
END;
/
```

### 3. Compare Test Results

```sql
-- Compare two test sessions
EXEC awr_test_comparator.compare_sessions('baseline_session', 'current_session');

-- Identify regressions with 20% threshold
EXEC awr_test_comparator.identify_regressions('baseline_session', 'current_session', 20);
```

## AWR Framework Components

### AWR Test Manager Package (`awr_test_manager`)

Core functionality for test session management with AWR integration:

```sql
-- Start a new test session with AWR snapshot
FUNCTION start_test_session(
  p_session_id VARCHAR2,
  p_test_name VARCHAR2,
  p_description VARCHAR2 DEFAULT NULL
) RETURN NUMBER;

-- End test session and take final snapshot
FUNCTION end_test_session(p_session_id VARCHAR2) RETURN NUMBER;

-- Take manual snapshot
FUNCTION take_snapshot RETURN NUMBER;

-- Get performance delta between snapshots
FUNCTION get_performance_delta(
  p_start_snap NUMBER,
  p_end_snap NUMBER,
  p_metric_type VARCHAR2 DEFAULT 'ALL'
) RETURN SYS_REFCURSOR;

-- Compare two test sessions
PROCEDURE compare_test_sessions(
  p_session1 VARCHAR2,
  p_session2 VARCHAR2
);

-- Generate comprehensive test report
PROCEDURE generate_test_report(p_session_id VARCHAR2);

-- Cleanup old sessions (retention management)
PROCEDURE cleanup_old_sessions(p_days_old NUMBER DEFAULT 30);
```

### AWR Performance Analyzer Package (`awr_performance_analyzer`)

Detailed performance metrics extraction and analysis:

```sql
-- Analyze system statistics between snapshots
PROCEDURE analyze_system_stats(
  p_session_id VARCHAR2,
  p_start_snap NUMBER,
  p_end_snap NUMBER
);

-- Analyze top SQL performance
PROCEDURE analyze_sql_performance(
  p_session_id VARCHAR2,
  p_start_snap NUMBER,
  p_end_snap NUMBER,
  p_top_n NUMBER DEFAULT 10
);

-- Analyze wait events and bottlenecks
PROCEDURE analyze_wait_events(
  p_session_id VARCHAR2,
  p_start_snap NUMBER,
  p_end_snap NUMBER,
  p_top_n NUMBER DEFAULT 10
);

-- Analyze I/O performance by tablespace
PROCEDURE analyze_io_stats(
  p_session_id VARCHAR2,
  p_start_snap NUMBER,
  p_end_snap NUMBER
);

-- Memory usage analysis
PROCEDURE analyze_memory_usage(
  p_session_id VARCHAR2,
  p_start_snap NUMBER,
  p_end_snap NUMBER
);

-- Time model analysis (where time is spent)
PROCEDURE analyze_time_model(
  p_session_id VARCHAR2,
  p_start_snap NUMBER,
  p_end_snap NUMBER
);

-- Comprehensive performance summary
PROCEDURE generate_performance_summary(p_session_id VARCHAR2);
```

### AWR Test Comparator Package (`awr_test_comparator`)

Advanced test comparison and regression detection:

```sql
-- Compare two test sessions with configurable thresholds
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

-- Identify performance regressions with detailed analysis
PROCEDURE identify_regressions(
  p_baseline_session VARCHAR2,
  p_comparison_session VARCHAR2,
  p_regression_threshold NUMBER DEFAULT 20
);

-- Analyze performance trends over time
PROCEDURE analyze_performance_trends(
  p_test_pattern VARCHAR2 DEFAULT '%', -- Pattern to match session IDs
  p_metric_name VARCHAR2 DEFAULT '%'
);

-- Create baseline from session for future comparisons
PROCEDURE create_baseline(
  p_session_id VARCHAR2,
  p_baseline_name VARCHAR2
);

-- Compare current session against established baseline
PROCEDURE compare_to_baseline(
  p_session_id VARCHAR2,
  p_baseline_name VARCHAR2
);

-- Export comparison results in various formats
PROCEDURE export_comparison_results(
  p_baseline_session VARCHAR2,
  p_comparison_session VARCHAR2,
  p_format VARCHAR2 DEFAULT 'TEXT' -- TEXT, CSV, HTML
);
```

## Data Structures

### AWR Test Sessions Table

Tracks all test sessions with AWR snapshot information:

```sql
CREATE TABLE awr_test_sessions (
  session_id VARCHAR2(100) PRIMARY KEY,
  test_name VARCHAR2(200) NOT NULL,
  description VARCHAR2(500),
  start_time DATE NOT NULL,
  end_time DATE,
  start_snap_id NUMBER,
  end_snap_id NUMBER,
  status VARCHAR2(20) DEFAULT 'RUNNING',
  created_date DATE DEFAULT SYSDATE
);
```

### AWR Test Results Table

Stores detailed performance metrics for analysis and comparison:

```sql
CREATE TABLE awr_test_results (
  id NUMBER PRIMARY KEY,
  session_id VARCHAR2(100) NOT NULL,
  metric_name VARCHAR2(100) NOT NULL,
  metric_value NUMBER,
  metric_unit VARCHAR2(50),
  notes VARCHAR2(500),
  created_date DATE DEFAULT SYSDATE
);
```

### AWR Test Comparison View

Provides easy access to test comparison data:

```sql
CREATE OR REPLACE VIEW v_awr_test_comparison AS
SELECT
  s1.session_id as baseline_session,
  s1.test_name as baseline_test,
  s2.session_id as comparison_session,
  s2.test_name as comparison_test,
  r1.metric_name,
  r1.metric_value as baseline_value,
  r2.metric_value as comparison_value,
  ROUND(((r2.metric_value - r1.metric_value) / r1.metric_value) * 100, 2) as pct_change,
  CASE
    WHEN ABS(((r2.metric_value - r1.metric_value) / r1.metric_value) * 100) > 10 THEN
      CASE WHEN r2.metric_value > r1.metric_value THEN 'REGRESSION' ELSE 'IMPROVEMENT' END
    ELSE 'STABLE'
  END as performance_status
FROM awr_test_sessions s1
JOIN awr_test_results r1 ON s1.session_id = r1.session_id
JOIN awr_test_sessions s2 ON s2.session_id != s1.session_id
JOIN awr_test_results r2 ON s2.session_id = r2.session_id AND r1.metric_name = r2.metric_name;
```

## Usage Examples

### Basic Performance Testing

```sql
-- Example 1: Simple performance test with AWR monitoring
DECLARE
  v_session_id VARCHAR2(100) := 'PARTITION_TEST_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS');
  v_start_snap NUMBER;
  v_end_snap NUMBER;
BEGIN
  -- Start AWR test session
  v_start_snap := awr_test_manager.start_test_session(
    v_session_id,
    'Partition Management Performance Test'
  );

  -- Run partition management operations
  FOR i IN 1..100 LOOP
    -- Test partition strategy evaluation
    SELECT partition_strategy_pkg.evaluate_strategy('TEST_TABLE_' || i, SYSDATE)
    INTO :result FROM dual;

    -- Test logging performance
    partition_logger_pkg.log_info('Performance test iteration ' || i);
  END LOOP;

  -- End test session and take final snapshot
  v_end_snap := awr_test_manager.end_test_session(v_session_id);

  -- Generate comprehensive performance analysis
  awr_performance_analyzer.generate_performance_summary(v_session_id);
END;
/
```

### Regression Detection and Baseline Comparison

```sql
-- Example 2: Detect performance regressions after code changes
DECLARE
  v_baseline_session VARCHAR2(100) := 'BASELINE_V1_0';
  v_current_session VARCHAR2(100) := 'CURRENT_V1_1';
BEGIN
  -- Create baseline from a good performing session
  awr_test_comparator.create_baseline(v_baseline_session, 'PRODUCTION_BASELINE');

  -- Compare current performance against baseline
  awr_test_comparator.compare_to_baseline(v_current_session, 'PRODUCTION_BASELINE');

  -- Identify specific regressions with 15% threshold
  awr_test_comparator.identify_regressions(
    'PRODUCTION_BASELINE_BASELINE',
    v_current_session,
    15
  );

  -- Analyze trends over multiple releases
  awr_test_comparator.analyze_performance_trends('RELEASE_%', 'CPU%');
END;
/
```

### Comprehensive Performance Analysis

```sql
-- Example 3: Full performance analysis with multiple metrics
DECLARE
  v_session_id VARCHAR2(100) := 'COMPREHENSIVE_TEST_' || TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS');
  v_start_snap NUMBER;
  v_end_snap NUMBER;
BEGIN
  -- Start comprehensive test session
  v_start_snap := awr_test_manager.start_test_session(
    v_session_id,
    'Comprehensive Partition Suite Performance Analysis',
    'Full test of all partition management components with detailed AWR analysis'
  );

  -- Test all major partition operations
  -- Partition creation and management
  FOR i IN 1..50 LOOP
    SELECT partition_management_pkg.create_partition('TEST_TABLE', 'P_' || i, 'VALUES LESS THAN (' || (i*1000) || ')')
    INTO :result FROM dual;
  END LOOP;

  -- Online operations testing
  FOR i IN 1..25 LOOP
    SELECT online_table_operations_pkg.check_table_exists('TEST_TABLE_' || i)
    INTO :result FROM dual;
  END LOOP;

  -- Maintenance operations
  FOR i IN 1..10 LOOP
    partition_maintenance_pkg.analyze_partition_performance('TEST_TABLE', 'P_' || i);
  END LOOP;

  -- End session and perform detailed analysis
  v_end_snap := awr_test_manager.end_test_session(v_session_id);

  -- Generate detailed performance reports
  DBMS_OUTPUT.PUT_LINE('=== System Statistics Analysis ===');
  awr_performance_analyzer.analyze_system_stats(v_session_id, v_start_snap, v_end_snap);

  DBMS_OUTPUT.PUT_LINE('=== SQL Performance Analysis ===');
  awr_performance_analyzer.analyze_sql_performance(v_session_id, v_start_snap, v_end_snap, 15);

  DBMS_OUTPUT.PUT_LINE('=== Wait Events Analysis ===');
  awr_performance_analyzer.analyze_wait_events(v_session_id, v_start_snap, v_end_snap, 10);

  DBMS_OUTPUT.PUT_LINE('=== I/O Performance Analysis ===');
  awr_performance_analyzer.analyze_io_stats(v_session_id, v_start_snap, v_end_snap);

  DBMS_OUTPUT.PUT_LINE('=== Memory Usage Analysis ===');
  awr_performance_analyzer.analyze_memory_usage(v_session_id, v_start_snap, v_end_snap);

  DBMS_OUTPUT.PUT_LINE('=== Time Model Analysis ===');
  awr_performance_analyzer.analyze_time_model(v_session_id, v_start_snap, v_end_snap);
END;
/
```

## Oracle Cloud Always Free Tier Considerations

### AWR Availability and Limitations

**Always Free Tier AWR Support:**
- AWR may have reduced retention periods (typically 8 days vs 8 days+ on Enterprise)
- Some advanced AWR features may be limited or unavailable
- Snapshot frequency may be restricted
- The framework includes intelligent fallback mechanisms for limited environments

**Resource Optimization:**
- **CPU:** Designed for 1-2 OCPU Always Free tier limits
- **Memory:** Optimized for 1GB RAM constraints
- **Storage:** Efficient storage usage for 20GB total limit
- **Sessions:** Manages concurrent session limits effectively

### Framework Adaptations for Always Free Tier

```sql
-- Automatic detection of AWR availability
IF awr_test_manager.is_awr_available() THEN
  -- Use full AWR functionality
  v_snap := awr_test_manager.start_test_session(v_session_id, v_test_name);
ELSE
  -- Use alternative performance monitoring
  awr_test_manager.start_basic_session(v_session_id, v_test_name);
END IF;
```

**Fallback Mechanisms:**
- Alternative performance metrics when AWR is unavailable
- Basic session tracking without snapshots
- Current session statistics as fallback
- Graceful degradation with clear messaging

## Integration with Ansible Automation

The AWR framework integrates seamlessly with the Ansible deployment pipeline:

### Ansible Playbook Integration

```yaml
# AWR Framework Deployment and Testing
- name: Initialize AWR performance monitoring framework
  shell: |
    sqlplus {{ database_username }}@{{ database_service_name }} @awr_performance_framework.sql
  register: awr_framework_result
  timeout: 600

- name: Deploy AWR analysis queries
  when: awr_framework_result.rc == 0
  shell: |
    sqlplus {{ database_username }}@{{ database_service_name }} @awr_analysis_queries.sql
  register: awr_analysis_result
  timeout: 600

- name: Run AWR-enabled performance test session
  when: awr_framework_result.rc == 0 and awr_analysis_result.rc == 0
  shell: |
    sqlplus {{ database_username }}@{{ database_service_name }} @awr_test_session.sql
  register: awr_test_result
  timeout: 900
```

### Automated Performance Testing

The framework automatically:
1. **Deploys AWR components** during Ansible execution
2. **Runs performance test sessions** with snapshot management
3. **Generates performance reports** in multiple formats
4. **Compares results** against previous deployments
5. **Alerts on regressions** exceeding defined thresholds

## Troubleshooting Guide

### Common Issues and Solutions

| Issue | Symptoms | Diagnosis | Solution |
|-------|----------|-----------|----------|
| **AWR Not Available** | Package creation fails, snapshot errors | `SELECT * FROM dba_hist_snapshot WHERE rownum <= 1;` | Grant AWR privileges or use fallback mode |
| **Insufficient Privileges** | Access denied to DBA_HIST_* views | `SELECT * FROM dba_hist_sysstat WHERE rownum <= 1;` | Grant SELECT on AWR views: `GRANT SELECT ANY DICTIONARY TO user;` |
| **Snapshot Creation Fails** | Manual snapshots fail | `EXEC DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT();` | Enable AWR: `EXEC DBMS_WORKLOAD_REPOSITORY.MODIFY_SNAPSHOT_SETTINGS(interval => 60);` |
| **Performance Data Missing** | Empty analysis results | Check time between snapshots | Ensure sufficient activity and wait time between snapshots |
| **Comparison Failures** | Session comparison errors | `SELECT * FROM awr_test_sessions;` | Verify both sessions exist and have valid snapshots |
| **Package Compilation Errors** | Objects invalid after deployment | `SELECT * FROM user_errors;` | Check dependencies and privileges, recompile packages |

### Diagnostic Queries

```sql
-- 1. Check AWR availability and configuration
SELECT snap_id, begin_interval_time, end_interval_time
FROM dba_hist_snapshot
WHERE rownum <= 5
ORDER BY snap_id DESC;

-- 2. Verify test sessions
SELECT session_id, test_name, status,
       start_time, end_time,
       start_snap_id, end_snap_id
FROM awr_test_sessions
ORDER BY start_time DESC;

-- 3. Check performance metrics collection
SELECT session_id, metric_name, COUNT(*) as metric_count,
       MIN(metric_value) as min_value,
       MAX(metric_value) as max_value,
       AVG(metric_value) as avg_value
FROM awr_test_results
GROUP BY session_id, metric_name
ORDER BY session_id, metric_name;

-- 4. Verify package compilation status
SELECT object_name, object_type, status, last_ddl_time
FROM user_objects
WHERE object_name LIKE '%AWR%'
   OR object_name LIKE '%TEST%'
ORDER BY object_name, object_type;

-- 5. Check for compilation errors
SELECT name, type, line, position, text
FROM user_errors
WHERE name LIKE '%AWR%'
ORDER BY name, type, line;

-- 6. Verify AWR snapshot settings
SELECT snap_interval, retention
FROM dba_hist_wr_control;

-- 7. Check database resource usage
SELECT name, value
FROM v$parameter
WHERE name IN ('cpu_count', 'sga_target', 'pga_aggregate_target');
```

### Performance Optimization Tips

**For Always Free Tier:**

1. **Snapshot Management**
   - Use manual snapshots for important tests
   - Clean up old sessions regularly
   - Avoid frequent snapshot creation

2. **Test Efficiency**
   - Keep test sessions focused and time-bounded
   - Run tests during low-activity periods
   - Use appropriate sample sizes for testing

3. **Resource Management**
   - Monitor CPU and memory usage during tests
   - Avoid running multiple concurrent AWR tests
   - Clean up test data and results regularly

4. **Storage Optimization**
   - Regular cleanup of old AWR data
   - Compress large test result sets
   - Archive historical performance data

## Advanced Features and Customization

### Custom Metric Collection

Extend the framework with custom metrics:

```sql
-- Add custom application metrics
PROCEDURE collect_custom_metrics(p_session_id VARCHAR2) IS
BEGIN
  -- Collect custom business metrics
  INSERT INTO awr_test_results (session_id, metric_name, metric_value, metric_unit, notes)
  SELECT p_session_id, 'PARTITION_COUNT', COUNT(*), 'count', 'Total partitions'
  FROM user_tab_partitions;

  -- Collect custom performance metrics
  INSERT INTO awr_test_results (session_id, metric_name, metric_value, metric_unit, notes)
  SELECT p_session_id, 'AVG_PARTITION_SIZE_MB', AVG(bytes/1024/1024), 'MB', 'Average partition size'
  FROM dba_segments
  WHERE segment_type = 'TABLE PARTITION';

  COMMIT;
END collect_custom_metrics;
```

### Automated Baseline Creation

Set up automated baseline management:

```sql
-- Create scheduled baseline creation
DECLARE
  v_baseline_name VARCHAR2(100) := 'AUTO_BASELINE_' || TO_CHAR(SYSDATE, 'YYYYMM');
  v_latest_session VARCHAR2(100);
BEGIN
  -- Find the most recent successful session
  SELECT session_id INTO v_latest_session
  FROM awr_test_sessions
  WHERE status = 'COMPLETED'
  AND start_time >= TRUNC(SYSDATE) - 7
  ORDER BY start_time DESC
  FETCH FIRST 1 ROWS ONLY;

  -- Create monthly baseline
  awr_test_comparator.create_baseline(v_latest_session, v_baseline_name);

  -- Cleanup old baselines (keep last 6 months)
  awr_test_manager.cleanup_old_sessions(180);
END;
/
```

### Integration with External Monitoring

Export metrics to external systems:

```sql
-- Export performance metrics for external monitoring
PROCEDURE export_metrics_to_monitoring(p_session_id VARCHAR2) IS
  CURSOR c_metrics IS
    SELECT metric_name, metric_value, metric_unit, created_date
    FROM awr_test_results
    WHERE session_id = p_session_id;
BEGIN
  FOR rec IN c_metrics LOOP
    -- Format for external monitoring system (e.g., Prometheus, CloudWatch)
    DBMS_OUTPUT.PUT_LINE(
      'oracle_performance_metric{' ||
      'session="' || p_session_id || '",' ||
      'metric="' || rec.metric_name || '",' ||
      'unit="' || rec.metric_unit || '"' ||
      '} ' || rec.metric_value || ' ' ||
      TO_CHAR(rec.created_date, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
    );
  END LOOP;
END export_metrics_to_monitoring;
```

## Best Practices and Recommendations

### Test Session Management

1. **Naming Convention**
   - Use descriptive session IDs with timestamps: `PROJECT_TEST_YYYYMMDD_HHMMSS`
   - Include version or build information: `V1_2_RELEASE_CANDIDATE_PERFORMANCE`
   - Use consistent patterns for automated processing

2. **Documentation Standards**
   - Always provide meaningful test names and descriptions
   - Include context about what changed between tests
   - Document expected outcomes and success criteria

3. **Lifecycle Management**
   - Clean up test sessions older than retention period
   - Archive important baseline sessions separately
   - Regular maintenance of AWR data and test results

### Performance Analysis Best Practices

1. **Metric Selection**
   - Focus on metrics relevant to your specific use case
   - Collect both system-level and application-specific metrics
   - Balance comprehensiveness with resource usage

2. **Threshold Configuration**
   - Set appropriate regression thresholds (typically 10-20%)
   - Use different thresholds for different metric types
   - Adjust thresholds based on business requirements

3. **Comparative Analysis**
   - Always compare against established baselines
   - Consider seasonal or time-based variations
   - Account for infrastructure changes between tests

### Oracle Cloud Optimization

1. **Resource Management**
   - Monitor CPU and memory usage during tests
   - Schedule intensive tests during off-peak hours
   - Use appropriate test data volumes for Always Free tier

2. **Cost Optimization**
   - Leverage Always Free tier limits effectively
   - Clean up unused test data and results
   - Use efficient storage strategies for historical data

3. **Scalability Planning**
   - Design tests that can scale with infrastructure growth
   - Plan for migration to paid tiers if needed
   - Consider multi-region testing strategies

## Support and Maintenance

### Framework Updates

The AWR performance monitoring framework is designed for easy maintenance and updates:

1. **Version Control**: All components are version-controlled and can be updated independently
2. **Backward Compatibility**: New versions maintain compatibility with existing test data
3. **Migration Scripts**: Automated migration for schema changes and updates

### Community and Support

For questions, issues, and contributions:

1. **Documentation**: Comprehensive documentation and examples provided
2. **Troubleshooting**: Detailed troubleshooting guide with common solutions
3. **Best Practices**: Proven patterns and recommendations based on real-world usage

### License and Compliance

This AWR performance monitoring framework is designed specifically for Oracle Database environments and complies with Oracle licensing requirements. It's optimized for Oracle Cloud Infrastructure Always Free tier while being scalable to enterprise environments.

---

**Framework Version:** 1.0.0
**Last Updated:** 2024-12-28
**Compatibility:** Oracle Database 19c+, Oracle Cloud Infrastructure
**License:** Compatible with Oracle Database licensing terms
