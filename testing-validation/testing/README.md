# Test Data Generation for Oracle Partition Management Suite

This directory contains scripts for generating comprehensive test data to validate partition management functionality.

## 📊 Test Data Sets

### **Small Dataset (1K-10K rows)**

- Quick testing and development
- Minimal resource usage
- Fast execution

### **Medium Dataset (100K-1M rows)**

- Realistic testing scenarios
- Performance validation
- Resource optimization testing

### **Large Dataset (10M+ rows)**

- Scale testing
- Performance benchmarking
- Production-like scenarios

## 🗂️ Table Types Created

### **1. Sales Data (Range Partitioned)**

- **Partition Key:** sale_date
- **Partitions:** Quarterly (Q1, Q2, Q3, Q4)
- **Use Case:** Time-series partition pruning
- **Size:** Configurable rows per quarter

### **2. Customer Data (Hash Partitioned)**

- **Partition Key:** customer_id
- **Partitions:** 8 hash partitions
- **Use Case:** Even distribution testing
- **Size:** Configurable customer count

### **3. Region Data (List Partitioned)**

- **Partition Key:** region_code
- **Partitions:** Geographic regions
- **Use Case:** Categorical partition testing
- **Size:** Fixed regional data

### **4. Log Data (Interval Partitioned)**

- **Partition Key:** log_date
- **Interval:** Daily partitions
- **Use Case:** Auto-partition creation
- **Size:** Configurable daily volume

### **5. Composite Tables**

- **Range-Hash:** Sales by date + customer
- **List-Range:** Region by category + date
- **Hash-List:** Customer by ID + status

## 🚀 Usage

The test data is automatically loaded when running:

```bash
./scripts/deploy-and-test.sh
```

Or manually:

```bash
sqlplus admin/password@connection @test-data/load_test_data.sql
```

## 📈 Performance Testing

### **Partition Pruning Tests**

```sql
-- Test range partition pruning
SELECT * FROM sales_data
WHERE sale_date BETWEEN DATE '2024-01-01' AND DATE '2024-03-31';

-- Test list partition pruning
SELECT * FROM region_data
WHERE region_code IN ('NORTH', 'SOUTH');

-- Test hash partition benefit
SELECT customer_id, COUNT(*)
FROM customer_data
GROUP BY customer_id;
```

### **Statistics Validation**

```sql
-- Check incremental stats
SELECT table_name, partition_name, last_analyzed, global_stats, user_stats
FROM user_tab_statistics
WHERE table_name IN ('SALES_DATA', 'CUSTOMER_DATA');

-- Validate partition-level stats
SELECT * FROM user_part_col_statistics
WHERE table_name = 'SALES_DATA';
```

## 🔧 Customization

Edit the data generation parameters in `load_test_data.sql`:

```sql
-- Modify these values for different test sizes
DECLARE
    v_rows_per_quarter NUMBER := 1000;   -- Small: 1K, Medium: 100K, Large: 1M
    v_customer_count NUMBER := 500;      -- Small: 500, Medium: 50K, Large: 500K
    v_days_of_logs NUMBER := 30;         -- Small: 30, Medium: 365, Large: 730
BEGIN
    -- Data generation logic
END;
```

## 📋 Test Scenarios Covered

- ✅ **Partition Pruning** - Verify Oracle eliminates unnecessary partitions
- ✅ **Parallel Processing** - Test parallel DML on partitioned tables
- ✅ **Statistics Collection** - Validate incremental statistics work
- ✅ **Index Maintenance** - Ensure local/global indexes perform correctly
- ✅ **Partition Maintenance** - Test add/drop/split operations
- ✅ **Subpartitioning** - Validate composite partition functionality
- ✅ **Online Operations** - Test ALTER TABLE MODIFY ONLINE conversion

## 🎯 Validation Queries

After loading data, verify partitioning is working:

```sql
-- Verify partition counts
SELECT table_name, COUNT(*) as partition_count
FROM user_tab_partitions
GROUP BY table_name;

-- Check data distribution
SELECT table_name, partition_name, num_rows
FROM user_tab_partitions
WHERE table_name IN ('SALES_DATA', 'CUSTOMER_DATA', 'REGION_DATA')
ORDER BY table_name, partition_name;

-- Test partition elimination
EXPLAIN PLAN FOR
SELECT * FROM sales_data WHERE sale_date = DATE '2024-01-15';
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

## 🧪 Integration with Test Suite

This test data integrates with the validation test suite:

- `test_validate_table_ops_pkg.sql` - Uses sales_data for conversion tests
- `test_validate_oracle19c_partition_support.sql` - Creates additional test tables
- `test_validate_partition_analysis_pkg.sql` - Analyzes the loaded data

## 💡 Best Practices

1. **Start Small** - Use small dataset for initial testing
2. **Scale Up** - Use medium/large for performance testing
3. **Clean Statistics** - Gather stats after data loading
4. **Monitor Space** - Watch tablespace usage with large datasets
5. **Test Cleanup** - Verify partition maintenance works correctly
