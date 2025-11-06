# Agentic AI Workflows with Oracle 26ai Database and MCP Protocol

## Overview

This repository provides a comprehensive implementation guide for building Agentic AI workflows using Oracle Database 26ai features integrated with the Model Context Protocol (MCP). This guide demonstrates how to leverage Oracle's advanced AI capabilities with modern communication protocols to create intelligent, autonomous agents.

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Documentation](#documentation)
6. [Examples](#examples)
7. [Best Practices](#best-practices)

## Introduction

Oracle Database 26ai introduces groundbreaking AI capabilities:
- **AI Vector Search**: Semantic search using embeddings
- **JSON Relational Duality**: Unified data model  
- **In-Database Machine Learning**: Native ML operations
- **Property Graphs**: Advanced relationship modeling

The Model Context Protocol (MCP) provides:
- Standardized communication between AI agents and data sources
- Context-aware interactions
- Tool invocation capabilities
- Streaming support for real-time updates

## Architecture Overview

```
┌───────────────────────────────────────────────────────┐
│                    AI Agent Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Reasoning  │  │   Planning   │  │   Execution  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└───────────────────────────────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────┐
│              MCP (Model Context Protocol)             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Context    │  │    Tools     │  │   Streaming  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└───────────────────────────────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────┐
│              Oracle Database 26ai                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Vector Search│  │  JSON Duality│  │ Property Graph│ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└───────────────────────────────────────────────────────┘
```

## Prerequisites

- Oracle Database 26ai (or compatible version)
- Node.js 18+ (for TypeScript examples)
- Java 17+ (for Java examples)
- SQL*Plus or Oracle SQL Developer
- OpenAI API Key (for embeddings)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/hvrcharon1/oracle-26ai-mcp-agentic-workflows-typescript.git
cd oracle-26ai-mcp-agentic-workflows-typescript

# Install TypeScript dependencies
npm install

# Configure database connection
cp .env.example .env
# Edit .env with your credentials

# Run setup script
npm run setup

# Start example agent
npm start
```

## Documentation

### Setup Guides
1. [Database Setup](docs/01-database-setup.md) - Configure Oracle 26ai
2. [Vector Search Setup](docs/02-vector-search-setup.md) - Enable semantic search
3. [JSON Duality Views](docs/03-json-duality.md) - Flexible data modeling
4. [Property Graphs](docs/04-property-graphs.md) - Relationship modeling

### MCP Integration
5. [TypeScript MCP Client](docs/05-typescript-mcp-client.md) - Node.js implementation
6. [Java MCP Client](docs/06-java-mcp-client.md) - Java implementation
7. [PL/SQL Integration](docs/07-plsql-integration.md) - Database-side logic

### Agent Development
8. [Building AI Agents](docs/08-building-agents.md) - Agent architecture
9. [Context Management](docs/09-context-management.md) - Conversation handling
10. [Tool Development](docs/10-tool-development.md) - Custom tools

### Advanced Topics
11. [Multi-Agent Workflows](docs/11-multi-agent-workflows.md) - Agent orchestration
12. [Performance Optimization](docs/12-performance-optimization.md) - Tuning
13. [Security Best Practices](docs/13-security.md) - Secure deployments

## Examples

### TypeScript Agent Example
```typescript
import { AgenticOracle } from './lib/agentic-oracle';

const agent = new AgenticOracle({
  connectionString: 'localhost:1521/FREEPDB1',
  user: 'ai_agent',
  password: process.env.DB_PASSWORD
});

// Semantic search
const results = await agent.search(
  'Find documents about AI vector search',
  { limit: 5, threshold: 0.75 }
);

// Agent conversation
const response = await agent.chat({
  message: 'What are the benefits of Oracle 26ai?',
  conversationId: 'conv-123'
});
```

### Java Agent Example
```java
AgenticOracleService agent = new AgenticOracleService(
    connection, 
    openaiApiKey
);

List<SearchResult> results = agent.semanticSearch(
    "Find documents about AI vector search",
    5,
    0.75
);

String response = agent.processQuery(
    "What are the benefits of Oracle 26ai?",
    conversationId
);
```

### PL/SQL Agent Example
```sql
DECLARE
    v_conv_id RAW(16);
    v_response JSON;
BEGIN
    v_conv_id := agent_context_pkg.create_conversation(
        p_agent_id => 'assistant-001',
        p_user_id => 'user-123'
    );
    
    v_response := agent_executor_pkg.process_query(
        p_conversation_id => v_conv_id,
        p_query => 'What are the benefits of Oracle 26ai?'
    );
    
    DBMS_OUTPUT.PUT_LINE(v_response.to_string());
END;
```

## Use Cases

### 1. Intelligent Document Processing
Use vector search and AI agents to automatically classify, extract, and process documents.

### 2. Real-Time Analytics Agent  
Build agents that monitor data streams and provide intelligent insights using in-database ML.

### 3. Customer Service Automation
Create conversational agents with context awareness backed by Oracle's JSON Duality.

### 4. Knowledge Graph Navigation
Leverage property graphs for complex relationship queries with AI-powered exploration.

## Best Practices

1. **Vector Index Optimization**: Use appropriate distance metrics and index parameters
2. **Context Window Management**: Efficiently manage conversation context
3. **Error Handling**: Implement robust retry mechanisms and fallbacks
4. **Security**: Use Oracle's security features (VPD, encryption, etc.)
5. **Monitoring**: Track agent performance and resource utilization

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Resources

- [Oracle Database 26ai Documentation](https://docs.oracle.com/en/database/)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [Oracle AI Vector Search Guide](https://docs.oracle.com/en/database/oracle/oracle-database/)
- [Examples Repository](https://github.com/hvrcharon1/oracle-26ai-mcp-agentic-workflows-typescript)

## Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation
- Review examples in the `/examples` directory

---

**Last Updated**: November 2025  
**Author**: Oracle AI Agent Development Team  
**Version**: 1.0.0
