# Performance Optimization Guide

## Overview

This guide covers performance optimization strategies for AI agents using Oracle 26ai.

## Vector Index Optimization

### Choosing the Right Index Type

```sql
-- HNSW for high accuracy (95%+)
CREATE VECTOR INDEX idx_hnsw ON embeddings(vector)
ORGANIZATION NEIGHBOR PARTITIONS
WITH TARGET ACCURACY 95
PARAMETERS (TYPE HNSW, NEIGHBORS 32);

-- IVF for large datasets
CREATE VECTOR INDEX idx_ivf ON embeddings(vector)
ORGANIZATION NEIGHBOR PARTITIONS
WITH TARGET ACCURACY 90
PARAMETERS (TYPE IVF, NEIGHBOR PARTITIONS 100);
```

### Index Monitoring

```sql
-- Check index statistics
SELECT 
    index_name,
    num_rows,
    last_analyzed,
    status
FROM user_indexes
WHERE index_type = 'VECTOR';

-- Rebuild if needed
ALTER INDEX idx_hnsw REBUILD ONLINE;
```

## Query Optimization

### Use Approximate Search

```sql
-- Fast approximate search
SELECT /*+ VECTOR_APPROX_SEARCH(docs, embedding, 95) */
    doc_id, text
FROM documents docs
ORDER BY VECTOR_DISTANCE(embedding, :query_vec, COSINE)
FETCH FIRST 10 ROWS ONLY;
```

### Batch Operations

```typescript
// Batch insert with executeMany
async function batchInsert(documents: Document[]) {
    const sql = `INSERT INTO documents VALUES (:1, :2, :3)`;
    
    await connection.executeMany(
        sql,
        documents.map(d => [d.text, d.vector, d.meta]),
        { autoCommit: true, batchErrors: true }
    );
}
```

## Connection Pooling

### TypeScript

```typescript
import oracledb from 'oracledb';

// Create connection pool
const pool = await oracledb.createPool({
    user: 'ai_agent',
    password: process.env.DB_PASSWORD,
    connectionString: 'localhost:1521/FREEPDB1',
    poolMin: 2,
    poolMax: 10,
    poolIncrement: 1,
    poolTimeout: 60
});

// Get connection from pool
const conn = await pool.getConnection();
try {
    // Use connection
} finally {
    await conn.close(); // Returns to pool
}
```

### Java

```java
import oracle.ucp.jdbc.PoolDataSource;
import oracle.ucp.jdbc.PoolDataSourceFactory;

PoolDataSource pds = PoolDataSourceFactory.getPoolDataSource();
pds.setConnectionFactoryClassName("oracle.jdbc.pool.OracleDataSource");
pds.setURL("jdbc:oracle:thin:@localhost:1521/FREEPDB1");
pds.setUser("ai_agent");
pds.setPassword(System.getenv("DB_PASSWORD"));
pds.setInitialPoolSize(2);
pds.setMinPoolSize(2);
pds.setMaxPoolSize(10);

Connection conn = pds.getConnection();
```

## Caching Strategies

```typescript
class CachedVectorSearch {
    private cache = new Map<string, any[]>();
    private cacheTimeout = 300000; // 5 minutes

    async search(query: string): Promise<any[]> {
        const cacheKey = this.getCacheKey(query);
        
        if (this.cache.has(cacheKey)) {
            return this.cache.get(cacheKey)!;
        }

        const results = await this.performSearch(query);
        this.cache.set(cacheKey, results);
        
        setTimeout(() => {
            this.cache.delete(cacheKey);
        }, this.cacheTimeout);

        return results;
    }
}
```

## Memory Management

```sql
-- Configure vector memory
ALTER SYSTEM SET vector_memory_size = 4G SCOPE=SPFILE;

-- Check memory usage
SELECT 
    pool, 
    name,
    bytes / 1024 / 1024 AS mb
FROM v$sgastat
WHERE name LIKE '%vector%';
```

## Monitoring

```sql
-- Create monitoring view
CREATE OR REPLACE VIEW agent_performance AS
SELECT 
    action_type,
    tool_name,
    AVG(execution_time_ms) as avg_time_ms,
    MAX(execution_time_ms) as max_time_ms,
    COUNT(*) as total_calls,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failures
FROM agent_actions
WHERE created_at > SYSTIMESTAMP - INTERVAL '1' DAY
GROUP BY action_type, tool_name;
```

---

**Next**: [Security Best Practices →](13-security.md)