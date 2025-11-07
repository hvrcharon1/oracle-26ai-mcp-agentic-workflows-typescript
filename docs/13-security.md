# Security Best Practices

## Overview

Security considerations for AI agents with Oracle 26ai.

## Database Security

### Principle of Least Privilege

```sql
-- Create role for AI agents
CREATE ROLE ai_agent_role;

-- Grant only necessary privileges
GRANT SELECT, INSERT ON document_embeddings TO ai_agent_role;
GRANT SELECT ON agent_conversations TO ai_agent_role;
GRANT EXECUTE ON agent_context_pkg TO ai_agent_role;

-- Assign role to user
GRANT ai_agent_role TO ai_agent;
```

### Virtual Private Database (VPD)

```sql
-- Create policy function
CREATE OR REPLACE FUNCTION agent_security_policy(
    schema VARCHAR2,
    table_name VARCHAR2
) RETURN VARCHAR2 IS
BEGIN
    -- Only allow access to own conversations
    RETURN 'user_id = SYS_CONTEXT(''USERENV'', ''SESSION_USER'')';
END;
/

-- Apply policy
BEGIN
    DBMS_RLS.ADD_POLICY(
        object_schema => 'AI_AGENT',
        object_name => 'AGENT_CONVERSATIONS',
        policy_name => 'USER_ISOLATION_POLICY',
        function_schema => 'AI_AGENT',
        policy_function => 'AGENT_SECURITY_POLICY',
        statement_types => 'SELECT, INSERT, UPDATE, DELETE'
    );
END;
/
```

### Data Encryption

```sql
-- Enable Transparent Data Encryption
ALTER TABLESPACE vector_data ENCRYPTION ONLINE;

-- Encrypt specific columns
ALTER TABLE document_embeddings 
MODIFY (document_text ENCRYPT);
```

## API Security

### TypeScript: Secure API Key Management

```typescript
import { SecretsManager } from 'aws-sdk';

class SecureCredentialManager {
    private secretsManager: SecretsManager;

    constructor() {
        this.secretsManager = new SecretsManager({
            region: process.env.AWS_REGION
        });
    }

    async getOpenAIKey(): Promise<string> {
        const secret = await this.secretsManager.getSecretValue({
            SecretId: 'oracle-ai-agent/openai-key'
        }).promise();

        return JSON.parse(secret.SecretString!).apiKey;
    }

    async getDBPassword(): Promise<string> {
        const secret = await this.secretsManager.getSecretValue({
            SecretId: 'oracle-ai-agent/db-password'
        }).promise();

        return JSON.parse(secret.SecretString!).password;
    }
}
```

### Input Validation

```typescript
class InputValidator {
    static validateQuery(query: string): void {
        // Length check
        if (query.length > 10000) {
            throw new Error('Query too long');
        }

        // SQL injection prevention
        const dangerousPatterns = [
            /;\s*(DROP|DELETE|TRUNCATE|ALTER)/i,
            /UNION\s+SELECT/i,
            /--/,
            /\/\*/
        ];

        for (const pattern of dangerousPatterns) {
            if (pattern.test(query)) {
                throw new Error('Invalid input detected');
            }
        }
    }

    static sanitizeMetadata(metadata: any): any {
        // Remove potentially dangerous fields
        const sanitized = { ...metadata };
        delete sanitized.__proto__;
        delete sanitized.constructor;
        delete sanitized.prototype;
        return sanitized;
    }
}
```

## Rate Limiting

```typescript
class RateLimiter {
    private requests = new Map<string, number[]>();
    private readonly maxRequests = 100;
    private readonly windowMs = 60000; // 1 minute

    async checkLimit(userId: string): Promise<boolean> {
        const now = Date.now();
        const userRequests = this.requests.get(userId) || [];

        // Remove old requests
        const validRequests = userRequests.filter(
            time => now - time < this.windowMs
        );

        if (validRequests.length >= this.maxRequests) {
            return false;
        }

        validRequests.push(now);
        this.requests.set(userId, validRequests);
        return true;
    }
}
```

## Audit Logging

```sql
-- Enable unified auditing
CREATE AUDIT POLICY agent_audit_policy
ACTIONS 
    SELECT ON ai_agent.document_embeddings,
    INSERT ON ai_agent.document_embeddings,
    DELETE ON ai_agent.document_embeddings
WHEN 'SYS_CONTEXT(''USERENV'', ''SESSION_USER'') != ''AI_AGENT'''
EVALUATE PER SESSION;

-- Enable policy
AUDIT POLICY agent_audit_policy;

-- Query audit trail
SELECT 
    event_timestamp,
    dbusername,
    action_name,
    object_name,
    sql_text
FROM unified_audit_trail
WHERE object_name = 'DOCUMENT_EMBEDDINGS'
ORDER BY event_timestamp DESC;
```

## Network Security

### SSL/TLS Configuration

```typescript
import oracledb from 'oracledb';
import fs from 'fs';

const connection = await oracledb.getConnection({
    user: 'ai_agent',
    password: process.env.DB_PASSWORD,
    connectionString: `(DESCRIPTION=
        (ADDRESS=(PROTOCOL=TCPS)(HOST=dbhost)(PORT=1522))
        (CONNECT_DATA=(SERVICE_NAME=FREEPDB1))
        (SECURITY=(SSL_SERVER_CERT_DN="CN=dbhost"))
    )`,
    walletLocation: '/path/to/wallet',
    walletPassword: process.env.WALLET_PASSWORD
});
```

## Secure PL/SQL

```sql
-- Prevent SQL injection in dynamic SQL
CREATE OR REPLACE FUNCTION safe_query(
    p_table_name IN VARCHAR2,
    p_condition IN VARCHAR2
) RETURN SYS_REFCURSOR IS
    v_cursor SYS_REFCURSOR;
    v_sql VARCHAR2(4000);
BEGIN
    -- Validate table name
    IF REGEXP_LIKE(p_table_name, '[^A-Za-z0-9_]') THEN
        RAISE_APPLICATION_ERROR(-20001, 'Invalid table name');
    END IF;

    -- Use bind variables
    v_sql := 'SELECT * FROM ' || DBMS_ASSERT.SIMPLE_SQL_NAME(p_table_name) ||
             ' WHERE condition = :cond';
    
    OPEN v_cursor FOR v_sql USING p_condition;
    RETURN v_cursor;
END;
/
```

## Data Privacy

### PII Masking

```sql
-- Create masking policy
BEGIN
    DBMS_REDACT.ADD_POLICY(
        object_schema => 'AI_AGENT',
        object_name => 'AGENT_CONVERSATIONS',
        column_name => 'USER_ID',
        policy_name => 'MASK_USER_ID',
        function_type => DBMS_REDACT.PARTIAL,
        function_parameters => 'VVVVFVVVV,VVV-VV-,X,1,5',
        expression => '1=1'
    );
END;
/
```

### Data Retention

```sql
-- Auto-delete old data
CREATE OR REPLACE PROCEDURE cleanup_old_data IS
BEGIN
    DELETE FROM agent_actions
    WHERE created_at < SYSTIMESTAMP - INTERVAL '90' DAY;
    
    DELETE FROM agent_conversations
    WHERE status = 'ARCHIVED'
      AND updated_at < SYSTIMESTAMP - INTERVAL '180' DAY;
    
    COMMIT;
END;
/

-- Schedule cleanup job
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'DAILY_CLEANUP',
        job_type => 'STORED_PROCEDURE',
        job_action => 'cleanup_old_data',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY;BYHOUR=2',
        enabled => TRUE
    );
END;
/
```

## Security Checklist

- [ ] Use strong passwords and rotate regularly
- [ ] Enable TDE for sensitive data
- [ ] Implement VPD for multi-tenancy
- [ ] Use connection pooling with SSL
- [ ] Validate all user inputs
- [ ] Implement rate limiting
- [ ] Enable comprehensive audit logging
- [ ] Store API keys in secrets manager
- [ ] Use prepared statements/bind variables
- [ ] Implement data retention policies
- [ ] Regular security assessments
- [ ] Monitor for suspicious activity

---

**Previous**: [Performance Optimization ←](12-performance-optimization.md)