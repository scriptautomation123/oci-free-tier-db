-- ==================================================================
-- Optimized Partitioned Table Size Query with BLOB Support
-- ==================================================================
-- Purpose: Get comprehensive size for partitioned tables with LOB columns
-- Optimizations: Reduced joins, better performance, cleaner structure
-- ==================================================================

WITH table_segments AS (
    -- Single query to get all related segments
    SELECT 
        segment_name,
        segment_type,
        bytes,
        -- Categorize segment types for easier aggregation
        CASE 
            WHEN segment_type IN ('TABLE', 'TABLE PARTITION', 'TABLE SUBPARTITION') THEN 'TABLE_DATA'
            WHEN segment_type IN ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION') THEN 'INDEX_DATA'
            WHEN segment_type IN ('LOBSEGMENT', 'LOB PARTITION', 'LOBINDEX') THEN 'LOB_DATA'
            ELSE 'OTHER'
        END AS segment_category
    FROM all_segments s
    WHERE s.owner = UPPER('&schema_name')
      AND (
          -- Direct table segments
          (s.segment_type IN ('TABLE', 'TABLE PARTITION', 'TABLE SUBPARTITION') 
           AND s.segment_name = UPPER('&table_name'))
          OR
          -- Index segments belonging to this table
          (s.segment_type IN ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
           AND s.segment_name IN (
               SELECT index_name 
               FROM all_indexes 
               WHERE owner = UPPER('&schema_name') 
                 AND table_name = UPPER('&table_name')
           ))
          OR
          -- LOB segments belonging to this table (including LOBINDEX)
          (s.segment_type IN ('LOBSEGMENT', 'LOB PARTITION', 'LOBINDEX')
           AND s.segment_name IN (
               SELECT segment_name 
               FROM all_lobs 
               WHERE owner = UPPER('&schema_name') 
                 AND table_name = UPPER('&table_name')
           ))
      )
)


SELECT 
    UPPER('&schema_name') AS schema_owner,
    UPPER('&table_name') AS table_name,
    
    -- Size breakdown by category
    ROUND(SUM(CASE WHEN segment_category = 'TABLE_DATA' THEN bytes ELSE 0 END) / POWER(1024, 3), 4) AS table_data_gb,
    ROUND(SUM(CASE WHEN segment_category = 'INDEX_DATA' THEN bytes ELSE 0 END) / POWER(1024, 3), 4) AS index_data_gb,
    ROUND(SUM(CASE WHEN segment_category = 'LOB_DATA' THEN bytes ELSE 0 END) / POWER(1024, 3), 4) AS lob_data_gb,
    
    -- Total size
    ROUND(SUM(bytes) / POWER(1024, 3), 4) AS total_size_gb,
    
    -- Additional metrics
    COUNT(DISTINCT CASE WHEN segment_category = 'TABLE_DATA' THEN segment_name END) AS table_segments,
    COUNT(DISTINCT CASE WHEN segment_category = 'INDEX_DATA' THEN segment_name END) AS index_segments,
    COUNT(DISTINCT CASE WHEN segment_category = 'LOB_DATA' THEN segment_name END) AS lob_segments,
    COUNT(*) AS total_segments   
FROM table_segments
WHERE segment_category IN ('TABLE_DATA', 'INDEX_DATA', 'LOB_DATA');

-- ==================================================================
-- Alternative: Detailed Segment Breakdown
-- ==================================================================
-- Use this version if you need to see individual segment details

SELECT 
    UPPER('&schema_name') AS schema_owner,
    UPPER('&table_name') AS table_name,
    s.segment_name,
    s.segment_type,
    s.partition_name,
    ROUND(s.bytes / POWER(1024, 2), 2) AS size_mb,
    ROUND(s.bytes / POWER(1024, 3), 4) AS size_gb,
    
    -- Categorize for easier understanding
    CASE 
        WHEN s.segment_type IN ('TABLE', 'TABLE PARTITION', 'TABLE SUBPARTITION') THEN 'Table Data'
        WHEN s.segment_type IN ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION') THEN 'Index Data'
        WHEN s.segment_type = 'LOBSEGMENT' THEN 'LOB Data'
        WHEN s.segment_type = 'LOB PARTITION' THEN 'LOB Partition Data'
        WHEN s.segment_type = 'LOBINDEX' THEN 'LOB Index'
        ELSE s.segment_type
    END AS segment_description
    
FROM all_segments s
WHERE s.owner = UPPER('&schema_name')
  AND (
      -- Table segments
      (s.segment_type IN ('TABLE', 'TABLE PARTITION', 'TABLE SUBPARTITION') 
       AND s.segment_name = UPPER('&table_name'))
      OR
      -- Index segments
      (s.segment_type IN ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
       AND s.segment_name IN (
           SELECT index_name FROM all_indexes 
           WHERE owner = UPPER('&schema_name') AND table_name = UPPER('&table_name')
       ))
      OR
      -- LOB segments
      (s.segment_type IN ('LOBSEGMENT', 'LOB PARTITION', 'LOBINDEX')
       AND s.segment_name IN (
           SELECT segment_name FROM all_lobs 
           WHERE owner = UPPER('&schema_name') AND table_name = UPPER('&table_name')
       ))
  )
ORDER BY 
    CASE s.segment_type
        WHEN 'TABLE' THEN 1
        WHEN 'TABLE PARTITION' THEN 2
        WHEN 'TABLE SUBPARTITION' THEN 3
        WHEN 'INDEX' THEN 4
        WHEN 'INDEX PARTITION' THEN 5
        WHEN 'INDEX SUBPARTITION' THEN 6
        WHEN 'LOBSEGMENT' THEN 7
        WHEN 'LOB PARTITION' THEN 8
        WHEN 'LOBINDEX' THEN 9
        ELSE 10
    END,
    s.bytes DESC;

-- ==================================================================
-- Performance-Optimized Version for Large Schemas
-- ==================================================================
-- Use this if you have many tables and want better performance

SELECT 
    '&schema_name' AS schema_owner,
    '&table_name' AS table_name,
    ROUND(SUM(table_bytes) / POWER(1024, 3), 4) AS table_data_gb,
    ROUND(SUM(index_bytes) / POWER(1024, 3), 4) AS index_data_gb,
    ROUND(SUM(lob_bytes) / POWER(1024, 3), 4) AS lob_data_gb,
    ROUND(SUM(total_bytes) / POWER(1024, 3), 4) AS total_size_gb
FROM (
    -- Table segments
    SELECT 
        SUM(bytes) AS table_bytes,
        0 AS index_bytes,
        0 AS lob_bytes,
        SUM(bytes) AS total_bytes
    FROM all_segments
    WHERE owner = UPPER('&schema_name')
      AND segment_name = UPPER('&table_name')
      AND segment_type IN ('TABLE', 'TABLE PARTITION', 'TABLE SUBPARTITION')
    
    UNION ALL
    
    -- Index segments
    SELECT 
        0 AS table_bytes,
        SUM(bytes) AS index_bytes,
        0 AS lob_bytes,
        SUM(bytes) AS total_bytes
    FROM all_segments s
    WHERE s.owner = UPPER('&schema_name')
      AND s.segment_type IN ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
      AND s.segment_name IN (
          SELECT index_name FROM all_indexes 
          WHERE owner = UPPER('&schema_name') AND table_name = UPPER('&table_name')
      )
    
    UNION ALL
    
    -- LOB segments
    SELECT 
        0 AS table_bytes,
        0 AS index_bytes,
        SUM(bytes) AS lob_bytes,
        SUM(bytes) AS total_bytes
    FROM all_segments s
    WHERE s.owner = UPPER('&schema_name')
      AND s.segment_type IN ('LOBSEGMENT', 'LOB PARTITION', 'LOBINDEX')
      AND s.segment_name IN (
          SELECT segment_name FROM all_lobs 
          WHERE owner = UPPER('&schema_name') AND table_name = UPPER('&table_name')
      )
);

-- ==================================================================
-- USAGE EXAMPLES:
-- ==================================================================
-- DEFINE schema_name = 'MYSCHEMA'
-- DEFINE table_name = 'MY_PARTITIONED_TABLE_WITH_BLOBS'
-- @optimized_table_size.sql
-- ==================================================================