# Oracle Cloud Infrastructure Validation

This directory contains automated validation and performance testing scripts for the Oracle Partition Management Suite running on Oracle Cloud Infrastructure.

## 🧪 Validation Categories

### **1. Infrastructure Validation**
- ✅ Database connectivity and authentication
- ✅ Oracle version and feature availability
- ✅ Resource allocation and performance
- ✅ Network connectivity and security

### **2. Package Installation Validation**
- ✅ All packages compiled without errors
- ✅ Dependencies resolved correctly
- ✅ Privileges and permissions configured
- ✅ Logging infrastructure functional

### **3. Functionality Validation**
- ✅ All 15 Oracle 19c partition types working
- ✅ Online conversion operations successful
- ✅ Subpartitioning and templates functional
- ✅ Statistics collection and analysis accurate

### **4. Performance Validation**
- ✅ Partition pruning efficiency
- ✅ Parallel execution capabilities
- ✅ Index performance on partitioned tables
- ✅ Memory and CPU utilization

## 🚀 Quick Validation

Run complete validation suite:
```bash
cd oci/validation
./run_complete_validation.sh
```

## 📊 Validation Scripts

### **`infrastructure_checks.sql`**
- Database version and features
- Tablespace configuration
- Memory and CPU allocation
- Network connectivity tests

### **`package_validation.sql`**  
- Package compilation status
- Dependency verification
- Privilege validation
- Error detection

### **`functionality_tests.sql`**
- All partition type creation
- Conversion operations
- Maintenance operations
- Error handling

### **`performance_benchmarks.sql`**
- Partition pruning tests
- Parallel execution benchmarks
- Index performance validation
- Resource utilization analysis

## 📈 Performance Benchmarks

### **Partition Pruning Test**
```sql
-- Measure partition elimination efficiency
EXPLAIN PLAN FOR 
SELECT * FROM sales_data 
WHERE sale_date BETWEEN DATE '2024-01-01' AND DATE '2024-01-31';

-- Should show only P_2024_Q1 partition accessed
```

### **Parallel Processing Test**
```sql
-- Test parallel DML on partitioned tables
ALTER SESSION ENABLE PARALLEL DML;
INSERT /*+ PARALLEL(4) */ INTO sales_data 
SELECT * FROM sales_data WHERE ROWNUM <= 10000;
```

### **Statistics Efficiency Test**
```sql
-- Validate incremental statistics collection time
EXEC DBMS_STATS.GATHER_TABLE_STATS('PARTITION_TEST', 'SALES_DATA', cascade => TRUE);
-- Should complete quickly with incremental stats
```

## 🎯 Success Criteria

### **Infrastructure Requirements**
- Oracle Database 19c or later ✅
- Autonomous Database with 1+ OCPUs ✅
- Auto-scaling enabled ✅
- Backup retention configured ✅

### **Package Requirements**
- All packages compile successfully ✅
- No invalid objects ✅
- All required privileges granted ✅
- Logging infrastructure functional ✅

### **Functionality Requirements**
- All 15 partition types supported ✅
- Online conversion operations work ✅
- Subpartitioning functions correctly ✅
- Statistics integration functional ✅

### **Performance Requirements**
- Partition pruning reduces I/O by 75%+ ✅
- Parallel operations scale linearly ✅
- Index performance maintained ✅
- Memory usage optimized ✅

## 📋 Validation Report

After running validation, check the generated report:
- **HTML Report**: `validation-report-YYYYMMDD-HHMMSS.html`
- **Summary**: Pass/fail status for each test category
- **Details**: Specific test results and recommendations
- **Performance**: Benchmark results and comparisons

## 🚨 Troubleshooting

### **Common Issues**

**Database Connection Failed**
```bash
# Check OCI configuration
oci db autonomous-database list --compartment-id [compartment-id]

# Verify wallet configuration
export TNS_ADMIN=/path/to/wallet
sqlplus admin/password@connection_string
```

**Package Compilation Errors**
```sql
-- Check for invalid objects
SELECT object_name, object_type, status 
FROM user_objects 
WHERE status != 'VALID';

-- Recompile if needed
ALTER PACKAGE package_name COMPILE;
```

**Performance Issues**
```sql
-- Check partition pruning
SET AUTOTRACE ON
SELECT COUNT(*) FROM sales_data WHERE sale_date = DATE '2024-01-15';
-- Should show partition elimination

-- Verify statistics are current
SELECT table_name, last_analyzed FROM user_tables;
```

## 🔧 Customization

### **Modify Test Parameters**
Edit validation scripts to adjust:
- Test data volume
- Performance thresholds  
- Timeout values
- Resource limits

### **Add Custom Tests**
Create additional validation scripts:
- Business-specific partition strategies
- Custom performance requirements
- Integration test scenarios
- Compliance validations

## 📚 Integration

### **CI/CD Pipeline Integration**
```yaml
# Add to .github/workflows/oracle-test.yml
- name: Run OCI Validation
  run: |
    cd oci/validation
    ./run_complete_validation.sh
    # Parse results and fail build if validation fails
```

### **Monitoring Integration**
- Export metrics to OCI Monitoring
- Set up alerts for validation failures
- Track performance trends over time
- Generate automated reports

## 💡 Best Practices

1. **Run validation after every deployment**
2. **Monitor performance trends over time**
3. **Validate with production-like data volumes**
4. **Test under various load conditions**
5. **Document any custom validation requirements**
6. **Integrate with your CI/CD pipeline**
7. **Review reports regularly for optimization opportunities**