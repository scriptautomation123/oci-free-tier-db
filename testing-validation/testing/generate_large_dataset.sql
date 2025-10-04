-- =====================================================
-- Generate Large Test Dataset for Performance Testing
-- Configurable data size for scalability testing
-- =====================================================

SET ECHO ON
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE 1000000

PROMPT ==========================================
PROMPT Generating Large Test Dataset
PROMPT Oracle Partition Management Suite
PROMPT ==========================================

-- Configuration parameters
DEFINE DATA_SIZE = '&1'  -- small, medium, large

-- Set row counts based on data size
COLUMN rows_per_quarter NEW_VALUE v_rows_per_quarter
COLUMN customer_count NEW_VALUE v_customer_count  
COLUMN days_of_logs NEW_VALUE v_days_of_logs
COLUMN product_count NEW_VALUE v_product_count

SELECT 
    CASE UPPER('&DATA_SIZE')
        WHEN 'SMALL' THEN 1000
        WHEN 'MEDIUM' THEN 100000  
        WHEN 'LARGE' THEN 1000000
        ELSE 10000
    END as rows_per_quarter,
    CASE UPPER('&DATA_SIZE') 
        WHEN 'SMALL' THEN 500
        WHEN 'MEDIUM' THEN 50000
        WHEN 'LARGE' THEN 500000  
        ELSE 5000
    END as customer_count,
    CASE UPPER('&DATA_SIZE')
        WHEN 'SMALL' THEN 30
        WHEN 'MEDIUM' THEN 365
        WHEN 'LARGE' THEN 730
        ELSE 90  
    END as days_of_logs,
    CASE UPPER('&DATA_SIZE')
        WHEN 'SMALL' THEN 100
        WHEN 'MEDIUM' THEN 1000
        WHEN 'LARGE' THEN 10000
        ELSE 500
    END as product_count
FROM dual;

-- Connect as test user
CONNECT partition_test/TestPass123@&2

PROMPT Generating &DATA_SIZE dataset...
PROMPT - Sales records per quarter: &v_rows_per_quarter
PROMPT - Customer records: &v_customer_count  
PROMPT - Days of log data: &v_days_of_logs
PROMPT - Product variations: &v_product_count

-- Clean existing data
TRUNCATE TABLE sales_data;
TRUNCATE TABLE customer_data;
TRUNCATE TABLE region_data;
TRUNCATE TABLE log_data;

-- Generate customer data first (for referential integrity)
PROMPT Generating customer data...

DECLARE
    v_customer_count NUMBER := &v_customer_count;
    v_batch_size NUMBER := 10000;
    v_batches NUMBER;
    v_start_id NUMBER;
    v_end_id NUMBER;
BEGIN
    v_batches := CEIL(v_customer_count / v_batch_size);
    
    FOR batch IN 1..v_batches LOOP
        v_start_id := (batch - 1) * v_batch_size + 1;
        v_end_id := LEAST(batch * v_batch_size, v_customer_count);
        
        INSERT /*+ APPEND */ INTO customer_data
        SELECT 
            LEVEL + v_start_id - 1 as customer_id,
            'Customer_' || TO_CHAR(LEVEL + v_start_id - 1, 'FM000000') as name,
            'customer' || TO_CHAR(LEVEL + v_start_id - 1) || '@example.com' as email,
            DATE '2020-01-01' + DBMS_RANDOM.VALUE(0, 1460) as registration_date
        FROM dual
        CONNECT BY LEVEL <= (v_end_id - v_start_id + 1);
        
        COMMIT;
        
        IF MOD(batch, 10) = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Generated ' || (batch * v_batch_size) || ' customers...');
        END IF;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('Generated ' || v_customer_count || ' customers total');
END;
/

-- Generate sales data (partitioned by quarters)
PROMPT Generating sales data...

DECLARE
    v_rows_per_quarter NUMBER := &v_rows_per_quarter;
    v_customer_count NUMBER := &v_customer_count;
    v_product_count NUMBER := &v_product_count;
    v_batch_size NUMBER := 5000;
    v_batches NUMBER;
    v_quarter_start DATE;
    v_quarter_end DATE;
    
    TYPE date_array IS TABLE OF DATE;
    v_quarters date_array := date_array(
        DATE '2024-01-01', -- Q1 start
        DATE '2024-04-01', -- Q2 start  
        DATE '2024-07-01', -- Q3 start
        DATE '2024-10-01'  -- Q4 start
    );
    
    TYPE varchar_array IS TABLE OF VARCHAR2(50);
    v_regions varchar_array := varchar_array('NORTH', 'SOUTH', 'EAST', 'WEST');
    v_products varchar_array := varchar_array('LAPTOP', 'DESKTOP', 'TABLET', 'PHONE', 'MONITOR', 'KEYBOARD', 'MOUSE', 'HEADSET');
    
BEGIN
    -- Generate data for each quarter
    FOR q IN 1..4 LOOP
        v_quarter_start := v_quarters(q);
        v_quarter_end := ADD_MONTHS(v_quarter_start, 3) - 1;
        
        DBMS_OUTPUT.PUT_LINE('Generating Q' || q || ' data (' || TO_CHAR(v_quarter_start, 'YYYY-MM-DD') || ' to ' || TO_CHAR(v_quarter_end, 'YYYY-MM-DD') || ')...');
        
        v_batches := CEIL(v_rows_per_quarter / v_batch_size);
        
        FOR batch IN 1..v_batches LOOP
            INSERT /*+ APPEND */ INTO sales_data
            SELECT 
                ((q-1) * v_rows_per_quarter) + ((batch-1) * v_batch_size) + LEVEL as sale_id,
                v_quarter_start + DBMS_RANDOM.VALUE(0, v_quarter_end - v_quarter_start) as sale_date,
                ROUND(DBMS_RANDOM.VALUE(100, 10000), 2) as amount,
                MOD(DBMS_RANDOM.VALUE(1, v_customer_count), v_customer_count) + 1 as customer_id,
                v_regions(MOD(LEVEL, 4) + 1) as region,
                v_products(MOD(LEVEL, 8) + 1) || '_' || MOD(LEVEL, v_product_count) as product
            FROM dual
            CONNECT BY LEVEL <= LEAST(v_batch_size, v_rows_per_quarter - (batch-1) * v_batch_size);
            
            COMMIT;
            
            IF MOD(batch, 20) = 0 THEN
                DBMS_OUTPUT.PUT_LINE('  Generated ' || (batch * v_batch_size) || ' sales records for Q' || q);
            END IF;
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('Completed Q' || q || ': ' || v_rows_per_quarter || ' records');
    END LOOP;
END;
/

-- Generate log data (interval partitioned)
PROMPT Generating log data...

DECLARE
    v_days NUMBER := &v_days_of_logs;
    v_logs_per_day NUMBER := CASE UPPER('&DATA_SIZE')
        WHEN 'SMALL' THEN 100
        WHEN 'MEDIUM' THEN 1000  
        WHEN 'LARGE' THEN 10000
        ELSE 500
    END;
    
    TYPE varchar_array IS TABLE OF VARCHAR2(10);
    v_log_levels varchar_array := varchar_array('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL');
    
    v_log_id NUMBER := 1;
    v_current_date DATE;
BEGIN
    FOR day_offset IN 0..v_days-1 LOOP
        v_current_date := DATE '2024-01-01' + day_offset;
        
        -- Generate logs for this day
        FOR log_num IN 1..v_logs_per_day LOOP
            INSERT INTO log_data VALUES (
                v_log_id,
                v_current_date + (log_num / v_logs_per_day), -- Spread throughout the day
                v_log_levels(MOD(log_num, 5) + 1),
                'Log message ' || v_log_id || ' - ' || 
                CASE MOD(log_num, 4)
                    WHEN 0 THEN 'System operation completed successfully'
                    WHEN 1 THEN 'User authentication event logged'  
                    WHEN 2 THEN 'Database connection established'
                    ELSE 'Application performance metric recorded'
                END
            );
            
            v_log_id := v_log_id + 1;
            
            -- Commit every 1000 records
            IF MOD(log_num, 1000) = 0 THEN
                COMMIT;
            END IF;
        END LOOP;
        
        COMMIT;
        
        -- Progress indicator
        IF MOD(day_offset + 1, 30) = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Generated logs for ' || (day_offset + 1) || ' days...');
        END IF;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('Generated ' || (v_days * v_logs_per_day) || ' log records total');
END;
/

-- Update region data with more comprehensive data
PROMPT Updating region data...

TRUNCATE TABLE region_data;

INSERT INTO region_data
SELECT 
    LEVEL as id,
    CASE MOD(LEVEL, 8)
        WHEN 1 THEN 'NORTH'
        WHEN 2 THEN 'SOUTH' 
        WHEN 3 THEN 'EAST'
        WHEN 4 THEN 'WEST'
        WHEN 5 THEN 'NE'
        WHEN 6 THEN 'SE'
        WHEN 7 THEN 'NW'
        WHEN 0 THEN 'SW'
    END as region_code,
    CASE MOD(LEVEL, 8)
        WHEN 1 THEN 'Northern Region'
        WHEN 2 THEN 'Southern Region'
        WHEN 3 THEN 'Eastern Region' 
        WHEN 4 THEN 'Western Region'
        WHEN 5 THEN 'Northeast Region'
        WHEN 6 THEN 'Southeast Region'
        WHEN 7 THEN 'Northwest Region'
        WHEN 0 THEN 'Southwest Region'
    END as region_name,
    CASE MOD(LEVEL, 3)
        WHEN 1 THEN 'USA'
        WHEN 2 THEN 'Canada'
        WHEN 0 THEN 'Mexico'
    END as country
FROM dual
CONNECT BY LEVEL <= &v_product_count;

COMMIT;

-- Gather comprehensive statistics
PROMPT Gathering statistics...

BEGIN
    -- Gather table stats
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => 'PARTITION_TEST',
        tabname => 'SALES_DATA',
        cascade => TRUE,
        degree => 4,
        method_opt => 'FOR ALL COLUMNS SIZE AUTO'
    );
    
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => 'PARTITION_TEST', 
        tabname => 'CUSTOMER_DATA',
        cascade => TRUE,
        degree => 4
    );
    
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => 'PARTITION_TEST',
        tabname => 'LOG_DATA', 
        cascade => TRUE,
        degree => 4
    );
    
    DBMS_STATS.GATHER_TABLE_STATS(
        ownname => 'PARTITION_TEST',
        tabname => 'REGION_DATA',
        cascade => TRUE
    );
    
    DBMS_OUTPUT.PUT_LINE('Statistics gathered for all tables');
END;
/

-- Create additional indexes for performance testing
PROMPT Creating performance test indexes...

-- Sales data indexes
CREATE INDEX idx_sales_customer ON sales_data(customer_id) LOCAL;
CREATE INDEX idx_sales_region ON sales_data(region) LOCAL;
CREATE INDEX idx_sales_amount ON sales_data(amount) LOCAL;

-- Customer data indexes  
CREATE INDEX idx_customer_email ON customer_data(email) LOCAL;
CREATE INDEX idx_customer_reg_date ON customer_data(registration_date) LOCAL;

-- Log data indexes
CREATE INDEX idx_log_level ON log_data(log_level) LOCAL;

-- Display final statistics
PROMPT 
PROMPT ==========================================
PROMPT Large Dataset Generation Complete
PROMPT ==========================================

SELECT 
    'SALES_DATA' as table_name,
    COUNT(*) as total_rows,
    MIN(sale_date) as min_date,
    MAX(sale_date) as max_date
FROM sales_data
UNION ALL
SELECT 
    'CUSTOMER_DATA',
    COUNT(*),
    MIN(registration_date),
    MAX(registration_date)  
FROM customer_data
UNION ALL
SELECT
    'LOG_DATA',
    COUNT(*),
    MIN(log_date),
    MAX(log_date)
FROM log_data
UNION ALL
SELECT
    'REGION_DATA',
    COUNT(*),
    NULL,
    NULL
FROM region_data;

-- Show partition distribution
PROMPT
PROMPT Partition Distribution:
SELECT 
    table_name,
    partition_name,
    num_rows,
    ROUND(num_rows * 100.0 / SUM(num_rows) OVER (PARTITION BY table_name), 1) as pct_total
FROM user_tab_partitions 
WHERE table_name IN ('SALES_DATA', 'CUSTOMER_DATA', 'LOG_DATA')
  AND num_rows > 0
ORDER BY table_name, partition_name;

PROMPT
PROMPT Dataset generation completed successfully!
PROMPT Ready for performance testing and validation.

-- Connect back as admin
CONNECT &2