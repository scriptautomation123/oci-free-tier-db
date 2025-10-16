-- Partition Analysis Query - Simplified Version
-- Shows partition size, creation date, row count, and average row size
-- Parameters: table_owner, table_name

SELECT
    tp.table_name,
    tp.partition_name,
    TO_CHAR(NVL(SUM(s.bytes), 0) / POWER(1024, 3), '999,999,999.00') AS partition_size_gb,
    o.created AS partition_created_date,
    tp.num_rows,
    CASE
        WHEN tp.num_rows > 0 AND SUM(s.bytes) > 0 
        THEN ROUND(SUM(s.bytes) / tp.num_rows, 2)
        ELSE 0
    END AS avg_row_size_bytes,
    -- Additional useful metrics
    tp.high_value AS partition_boundary,
    tp.tablespace_name,
    CASE 
        WHEN tp.num_rows > 0 THEN 'POPULATED'
        ELSE 'EMPTY'
    END AS partition_status
FROM
    all_tab_partitions tp
LEFT JOIN
    all_segments s ON s.owner = tp.table_owner
    AND s.partition_name = tp.partition_name
    AND (
        -- Table partition
        s.segment_name = tp.table_name
        OR 
        -- Index partitions (any index on this table)
        s.segment_name IN (
            SELECT index_name 
            FROM all_indexes 
            WHERE table_owner = tp.table_owner 
            AND table_name = tp.table_name
        )
        OR
        -- LOB segments
        s.segment_name IN (
            SELECT segment_name 
            FROM all_lobs 
            WHERE owner = tp.table_owner 
            AND table_name = tp.table_name
        )
    )
LEFT JOIN
    all_objects o ON o.owner = tp.table_owner
    AND o.object_name = tp.table_name
    AND o.subobject_name = tp.partition_name
    AND o.object_type = 'TABLE PARTITION'
WHERE
    tp.table_owner = UPPER('&table_owner')
    AND tp.table_name = UPPER('&table_name')
GROUP BY
    tp.table_name,
    tp.partition_name,
    o.created,
    tp.num_rows,
    tp.high_value,
    tp.tablespace_name,
    tp.partition_position
ORDER BY
    o.created NULLS LAST,
    tp.partition_position;

-- Alternative version using bind variables (recommended for application use)
SELECT
    tp.table_name,
    tp.partition_name,
    TO_CHAR(NVL(SUM(s.bytes), 0) / POWER(1024, 3), '999,999,999.00') AS partition_size_gb,
    o.created AS partition_created_date,
    tp.num_rows,
    CASE
        WHEN tp.num_rows > 0 AND SUM(s.bytes) > 0 
        THEN ROUND(SUM(s.bytes) / tp.num_rows, 2)
        ELSE 0
    END AS avg_row_size_bytes,
    tp.high_value AS partition_boundary,
    tp.tablespace_name,
    CASE 
        WHEN tp.num_rows > 0 THEN 'POPULATED'
        ELSE 'EMPTY'
    END AS partition_status
FROM
    all_tab_partitions tp
LEFT JOIN
    all_segments s ON s.owner = tp.table_owner
    AND s.partition_name = tp.partition_name
    AND (
        s.segment_name = :table_name
        OR 
        s.segment_name IN (
            SELECT index_name FROM all_indexes 
            WHERE table_owner = :table_owner AND table_name = :table_name
        )
        OR
        s.segment_name IN (
            SELECT segment_name FROM all_lobs 
            WHERE owner = :table_owner AND table_name = :table_name
        )
    )
LEFT JOIN
    all_objects o ON o.owner = tp.table_owner
    AND o.object_name = tp.table_name
    AND o.subobject_name = tp.partition_name
    AND o.object_type = 'TABLE PARTITION'
WHERE
    tp.table_owner = :table_owner
    AND tp.table_name = :table_name
GROUP BY
    tp.table_name, tp.partition_name, o.created, tp.num_rows,
    tp.high_value, tp.tablespace_name, tp.partition_position
ORDER BY
    o.created NULLS LAST, tp.partition_position;