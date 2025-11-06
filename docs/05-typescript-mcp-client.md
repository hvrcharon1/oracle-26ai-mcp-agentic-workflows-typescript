# TypeScript MCP Client Implementation

## Overview

This guide demonstrates building a Model Context Protocol (MCP) client in TypeScript for Oracle 26ai agentic workflows.

## Setup

```bash
npm install oracledb @modelcontextprotocol/sdk openai dotenv
npm install --save-dev @types/node @types/oracledb typescript
```

## MCP Client Architecture

```typescript
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import oracledb from 'oracledb';
import { Configuration, OpenAIApi } from 'openai';

interface MCPClientConfig {
    oracleConfig: {
        user: string;
        password: string;
        connectionString: string;
    };
    openaiApiKey: string;
    mcpServerPath?: string;
}

class OracleMCPClient {
    private client: Client;
    private connection!: oracledb.Connection;
    private openai: OpenAIApi;
    private tools: Map<string, (...args: any[]) => Promise<any>>;

    constructor(private config: MCPClientConfig) {
        const configuration = new Configuration({
            apiKey: config.openaiApiKey
        });
        this.openai = new OpenAIApi(configuration);
        this.client = new Client({
            name: 'oracle-ai-agent',
            version: '1.0.0'
        }, {
            capabilities: {
                roots: { listChanged: true },
                sampling: {}
            }
        });
        this.tools = new Map();
    }

    async connect(): Promise<void> {
        // Connect to Oracle Database
        this.connection = await oracledb.getConnection(this.config.oracleConfig);
        console.log('Connected to Oracle Database 26ai');

        // Initialize MCP server connection
        const transport = new StdioClientTransport({
            command: this.config.mcpServerPath || 'mcp-server',
            args: []
        });

        await this.client.connect(transport);
        console.log('Connected to MCP server');

        // Register tools
        await this.registerTools();
    }

    private async registerTools(): Promise<void> {
        // Register Oracle-specific tools
        this.tools.set('semantic_search', this.semanticSearch.bind(this));
        this.tools.set('execute_sql', this.executeSql.bind(this));
        this.tools.set('get_context', this.getConversationContext.bind(this));
        this.tools.set('store_document', this.storeDocument.bind(this));
    }

    /**
     * Tool: Semantic search in vector database
     */
    private async semanticSearch(args: {
        query: string;
        limit?: number;
        threshold?: number;
    }): Promise<any> {
        const { query, limit = 10, threshold = 0.7 } = args;

        // Generate embedding
        const response = await this.openai.createEmbedding({
            model: 'text-embedding-ada-002',
            input: query
        });
        const embedding = response.data.data[0].embedding;
        const vectorStr = `[${embedding.join(',')}]`;

        // Query Oracle
        const sql = `
            SELECT 
                RAWTOHEX(doc_id) as doc_id,
                document_text,
                VECTOR_DISTANCE(
                    embedding,
                    TO_VECTOR(:embedding, 1536, FLOAT32),
                    COSINE
                ) as distance,
                metadata
            FROM document_embeddings
            WHERE VECTOR_DISTANCE(
                embedding,
                TO_VECTOR(:embedding, 1536, FLOAT32),
                COSINE
            ) < :threshold
            ORDER BY distance
            FETCH FIRST :limit ROWS ONLY
        `;

        const result = await this.connection.execute(sql, {
            embedding: vectorStr,
            threshold: 1 - threshold,
            limit
        });

        return {
            results: result.rows?.map((row: any) => ({
                docId: row[0],
                text: row[1],
                similarity: 1 - row[2],
                metadata: JSON.parse(row[3] || '{}')
            }))
        };
    }

    /**
     * Tool: Execute SQL queries safely
     */
    private async executeSql(args: {
        query: string;
        params?: Record<string, any>;
    }): Promise<any> {
        const { query, params = {} } = args;

        // Security: Only allow SELECT queries
        const trimmedQuery = query.trim().toUpperCase();
        if (!trimmedQuery.startsWith('SELECT')) {
            throw new Error('Only SELECT queries are allowed');
        }

        try {
            const result = await this.connection.execute(query, params);
            return {
                rows: result.rows,
                rowsAffected: result.rowsAffected,
                metaData: result.metaData
            };
        } catch (error: any) {
            return {
                error: error.message
            };
        }
    }

    /**
     * Tool: Get conversation context
     */
    private async getConversationContext(args: {
        conversationId: string;
        limit?: number;
    }): Promise<any> {
        const { conversationId, limit = 10 } = args;

        const sql = `
            SELECT agent_context_pkg.get_history(
                HEXTORAW(:convId),
                :limit
            ) FROM DUAL
        `;

        const result = await this.connection.execute(sql, {
            convId: conversationId,
            limit
        });

        return {
            history: result.rows?.[0]?.[0] || []
        };
    }

    /**
     * Tool: Store document with embedding
     */
    private async storeDocument(args: {
        text: string;
        metadata?: Record<string, any>;
        source?: string;
    }): Promise<any> {
        const { text, metadata = {}, source = 'user' } = args;

        // Generate embedding
        const response = await this.openai.createEmbedding({
            model: 'text-embedding-ada-002',
            input: text
        });
        const embedding = response.data.data[0].embedding;
        const vectorStr = `[${embedding.join(',')}]`;

        // Store in database
        const sql = `
            INSERT INTO document_embeddings (
                document_text,
                embedding,
                metadata,
                source
            ) VALUES (
                :text,
                TO_VECTOR(:embedding, 1536, FLOAT32),
                JSON(:metadata),
                :source
            ) RETURNING doc_id INTO :docId
        `;

        const result = await this.connection.execute(sql, {
            text,
            embedding: vectorStr,
            metadata: JSON.stringify(metadata),
            source,
            docId: { dir: oracledb.BIND_OUT, type: oracledb.DB_TYPE_RAW }
        }, { autoCommit: true });

        const docId = result.outBinds?.docId;
        return {
            docId: docId ? docId.toString('hex') : null
        };
    }

    /**
     * Process agent request using MCP protocol
     */
    async processRequest(request: {
        messages: Array<{ role: string; content: string }>;
        conversationId?: string;
    }): Promise<any> {
        const { messages, conversationId } = request;

        // Get available tools
        const availableTools = Array.from(this.tools.keys()).map(name => ({
            name,
            description: this.getToolDescription(name),
            inputSchema: this.getToolSchema(name)
        }));

        // Call LLM with tools
        const completion = await this.openai.createChatCompletion({
            model: 'gpt-4',
            messages: messages as any,
            tools: availableTools.map(tool => ({
                type: 'function',
                function: {
                    name: tool.name,
                    description: tool.description,
                    parameters: tool.inputSchema
                }
            })),
            tool_choice: 'auto'
        });

        const message = completion.data.choices[0].message;

        // Handle tool calls
        if (message.tool_calls) {
            const toolResults = [];

            for (const toolCall of message.tool_calls) {
                const toolName = toolCall.function.name;
                const toolArgs = JSON.parse(toolCall.function.arguments);
                const toolFn = this.tools.get(toolName);

                if (toolFn) {
                    try {
                        const result = await toolFn(toolArgs);
                        toolResults.push({
                            toolCallId: toolCall.id,
                            result
                        });
                    } catch (error: any) {
                        toolResults.push({
                            toolCallId: toolCall.id,
                            error: error.message
                        });
                    }
                }
            }

            // Store action in database
            if (conversationId) {
                for (const tr of toolResults) {
                    await this.storeAction({
                        conversationId,
                        toolName: tr.toolCallId,
                        input: {}, // tool args
                        output: tr.result || { error: tr.error }
                    });
                }
            }

            return {
                message,
                toolResults
            };
        }

        return {
            message
        };
    }

    private async storeAction(action: {
        conversationId: string;
        toolName: string;
        input: any;
        output: any;
    }): Promise<void> {
        const sql = `
            INSERT INTO agent_actions (
                conversation_id,
                action_type,
                tool_name,
                input_params,
                output_result,
                status
            ) VALUES (
                HEXTORAW(:convId),
                'TOOL_CALL',
                :toolName,
                JSON(:input),
                JSON(:output),
                'COMPLETED'
            )
        `;

        await this.connection.execute(sql, {
            convId: action.conversationId,
            toolName: action.toolName,
            input: JSON.stringify(action.input),
            output: JSON.stringify(action.output)
        }, { autoCommit: true });
    }

    private getToolDescription(name: string): string {
        const descriptions: Record<string, string> = {
            semantic_search: 'Search for documents using semantic similarity',
            execute_sql: 'Execute SELECT queries on the database',
            get_context: 'Retrieve conversation history and context',
            store_document: 'Store a new document with vector embedding'
        };
        return descriptions[name] || '';
    }

    private getToolSchema(name: string): any {
        const schemas: Record<string, any> = {
            semantic_search: {
                type: 'object',
                properties: {
                    query: { type: 'string', description: 'Search query' },
                    limit: { type: 'number', description: 'Max results' },
                    threshold: { type: 'number', description: 'Similarity threshold' }
                },
                required: ['query']
            },
            execute_sql: {
                type: 'object',
                properties: {
                    query: { type: 'string', description: 'SQL SELECT query' },
                    params: { type: 'object', description: 'Query parameters' }
                },
                required: ['query']
            },
            get_context: {
                type: 'object',
                properties: {
                    conversationId: { type: 'string', description: 'Conversation ID' },
                    limit: { type: 'number', description: 'Number of messages' }
                },
                required: ['conversationId']
            },
            store_document: {
                type: 'object',
                properties: {
                    text: { type: 'string', description: 'Document text' },
                    metadata: { type: 'object', description: 'Document metadata' },
                    source: { type: 'string', description: 'Document source' }
                },
                required: ['text']
            }
        };
        return schemas[name] || {};
    }

    async disconnect(): Promise<void> {
        if (this.connection) {
            await this.connection.close();
        }
        await this.client.close();
    }
}

export { OracleMCPClient, MCPClientConfig };
```

## Usage Example

```typescript
import { OracleMCPClient } from './oracle-mcp-client';
import dotenv from 'dotenv';

dotenv.config();

async function main() {
    const client = new OracleMCPClient({
        oracleConfig: {
            user: 'ai_agent',
            password: process.env.DB_PASSWORD!,
            connectionString: 'localhost:1521/FREEPDB1'
        },
        openaiApiKey: process.env.OPENAI_API_KEY!
    });

    await client.connect();

    // Example conversation
    const response = await client.processRequest({
        messages: [
            {
                role: 'user',
                content: 'Find documents about Oracle AI features and summarize them'
            }
        ],
        conversationId: '123e4567-e89b-12d3-a456-426614174000'
    });

    console.log('Agent response:', response);

    await client.disconnect();
}

main().catch(console.error);
```

---

**Next**: [Java MCP Client →](06-java-mcp-client.md)