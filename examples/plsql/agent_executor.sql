-- PL/SQL Agent Executor Package
-- Demonstrates building agents using PL/SQL

CREATE OR REPLACE PACKAGE agent_executor_pkg AS
    -- Process query with RAG
    FUNCTION process_query(
        p_conversation_id IN RAW,
        p_query IN VARCHAR2,
        p_use_rag IN BOOLEAN DEFAULT TRUE
    ) RETURN JSON;
    
    -- Execute multi-step task
    FUNCTION execute_task(
        p_conversation_id IN RAW,
        p_task IN VARCHAR2
    ) RETURN JSON;
    
    -- Store document with embedding
    FUNCTION store_document(
        p_text IN CLOB,
        p_metadata IN JSON,
        p_source IN VARCHAR2
    ) RETURN RAW;
    
    -- Semantic search
    FUNCTION semantic_search(
        p_query_vector IN VECTOR,
        p_limit IN NUMBER DEFAULT 5,
        p_threshold IN NUMBER DEFAULT 0.7
    ) RETURN JSON;
END agent_executor_pkg;
/

CREATE OR REPLACE PACKAGE BODY agent_executor_pkg AS
    
    -- Helper function to generate mock embedding
    -- In production, call external API
    FUNCTION generate_mock_embedding(
        p_text IN VARCHAR2
    ) RETURN VECTOR IS
        v_vector_str VARCHAR2(32000);
        v_hash NUMBER;
    BEGIN
        -- Simple hash-based mock embedding
        v_hash := DBMS_UTILITY.GET_HASH_VALUE(
            p_text, 
            1, 
            power(2, 30)
        );
        
        -- Generate 1536-dimensional vector
        v_vector_str := '[';
        FOR i IN 1..1536 LOOP
            v_vector_str := v_vector_str || 
                TO_CHAR(DBMS_RANDOM.VALUE(-1, 1), 'FM9999.999999');
            IF i < 1536 THEN
                v_vector_str := v_vector_str || ',';
            END IF;
        END LOOP;
        v_vector_str := v_vector_str || ']';
        
        RETURN TO_VECTOR(v_vector_str, 1536, FLOAT32);
    END generate_mock_embedding;
    
    FUNCTION semantic_search(
        p_query_vector IN VECTOR,
        p_limit IN NUMBER DEFAULT 5,
        p_threshold IN NUMBER DEFAULT 0.7
    ) RETURN JSON IS
        v_results JSON;
    BEGIN
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'docId' VALUE RAWTOHEX(doc_id),
                'text' VALUE document_text,
                'similarity' VALUE (
                    1 - VECTOR_DISTANCE(
                        embedding, 
                        p_query_vector, 
                        COSINE
                    )
                ),
                'metadata' VALUE metadata
            ) ORDER BY VECTOR_DISTANCE(embedding, p_query_vector, COSINE)
        )
        INTO v_results
        FROM (
            SELECT 
                doc_id,
                document_text,
                embedding,
                metadata
            FROM document_embeddings
            WHERE VECTOR_DISTANCE(
                embedding, 
                p_query_vector, 
                COSINE
            ) < (1 - p_threshold)
            ORDER BY VECTOR_DISTANCE(embedding, p_query_vector, COSINE)
            FETCH FIRST p_limit ROWS ONLY
        );
        
        RETURN v_results;
    END semantic_search;
    
    FUNCTION store_document(
        p_text IN CLOB,
        p_metadata IN JSON,
        p_source IN VARCHAR2
    ) RETURN RAW IS
        v_doc_id RAW(16);
        v_embedding VECTOR;
    BEGIN
        -- Generate embedding
        v_embedding := generate_mock_embedding(p_text);
        
        -- Store document
        INSERT INTO document_embeddings (
            document_text,
            embedding,
            metadata,
            source
        ) VALUES (
            p_text,
            v_embedding,
            p_metadata,
            p_source
        ) RETURNING doc_id INTO v_doc_id;
        
        COMMIT;
        RETURN v_doc_id;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END store_document;
    
    FUNCTION process_query(
        p_conversation_id IN RAW,
        p_query IN VARCHAR2,
        p_use_rag IN BOOLEAN DEFAULT TRUE
    ) RETURN JSON IS
        v_query_vector VECTOR;
        v_context JSON;
        v_history JSON;
        v_response JSON;
        v_start_time TIMESTAMP := SYSTIMESTAMP;
        v_action_id RAW(16);
    BEGIN
        -- Generate query embedding
        v_query_vector := generate_mock_embedding(p_query);
        
        -- Get conversation history
        v_history := agent_context_pkg.get_history(
            p_conversation_id, 
            10
        );
        
        -- Perform RAG if enabled
        IF p_use_rag THEN
            v_context := semantic_search(
                v_query_vector,
                5,
                0.75
            );
        END IF;
        
        -- Build response
        v_response := JSON_OBJECT(
            'query' VALUE p_query,
            'context' VALUE v_context,
            'history' VALUE v_history,
            'timestamp' VALUE TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'executionTime' VALUE 
                EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)) * 1000
        );
        
        -- Store action
        INSERT INTO agent_actions (
            conversation_id,
            action_type,
            tool_name,
            input_params,
            output_result,
            execution_time_ms,
            status
        ) VALUES (
            p_conversation_id,
            'QUERY',
            'process_query',
            JSON_OBJECT('query' VALUE p_query),
            v_response,
            EXTRACT(SECOND FROM (SYSTIMESTAMP - v_start_time)) * 1000,
            'COMPLETED'
        ) RETURNING action_id INTO v_action_id;
        
        COMMIT;
        RETURN v_response;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RETURN JSON_OBJECT(
                'error' VALUE SQLERRM,
                'query' VALUE p_query
            );
    END process_query;
    
    FUNCTION execute_task(
        p_conversation_id IN RAW,
        p_task IN VARCHAR2
    ) RETURN JSON IS
        v_plan JSON;
        v_steps JSON_ARRAY_T;
        v_step JSON_OBJECT_T;
        v_results JSON_ARRAY_T := JSON_ARRAY_T();
        v_step_result JSON_OBJECT_T;
        v_success BOOLEAN := TRUE;
    BEGIN
        -- Create simple task plan
        v_plan := JSON_OBJECT(
            'task' VALUE p_task,
            'steps' VALUE JSON_ARRAY(
                JSON_OBJECT(
                    'id' VALUE 1,
                    'description' VALUE 'Analyze task requirements',
                    'tool' VALUE 'analyze'
                ),
                JSON_OBJECT(
                    'id' VALUE 2,
                    'description' VALUE 'Search for relevant information',
                    'tool' VALUE 'semantic_search'
                ),
                JSON_OBJECT(
                    'id' VALUE 3,
                    'description' VALUE 'Synthesize results',
                    'tool' VALUE 'synthesize'
                )
            )
        );
        
        -- Execute each step
        v_steps := JSON_ARRAY_T(JSON_QUERY(v_plan, '$.steps'));
        
        FOR i IN 0..v_steps.get_size() - 1 LOOP
            v_step := JSON_OBJECT_T(v_steps.get(i));
            
            -- Execute step (simplified)
            v_step_result := JSON_OBJECT_T();
            v_step_result.put('stepId', v_step.get_number('id'));
            v_step_result.put('description', v_step.get_string('description'));
            v_step_result.put('success', TRUE);
            v_step_result.put('output', 'Step completed successfully');
            
            v_results.append(v_step_result.to_json_value());
            
            -- Store step action
            INSERT INTO agent_actions (
                conversation_id,
                action_type,
                tool_name,
                input_params,
                output_result,
                status
            ) VALUES (
                p_conversation_id,
                'TASK_STEP',
                v_step.get_string('tool'),
                v_step.to_json_value(),
                v_step_result.to_json_value(),
                'COMPLETED'
            );
        END LOOP;
        
        COMMIT;
        
        RETURN JSON_OBJECT(
            'task' VALUE p_task,
            'plan' VALUE v_plan,
            'results' VALUE v_results,
            'success' VALUE v_success
        );
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RETURN JSON_OBJECT(
                'error' VALUE SQLERRM,
                'task' VALUE p_task
            );
    END execute_task;
    
END agent_executor_pkg;
/

-- Example usage
DECLARE
    v_conv_id RAW(16);
    v_doc_id RAW(16);
    v_response JSON;
    v_task_result JSON;
BEGIN
    -- Create conversation
    v_conv_id := agent_context_pkg.create_conversation(
        p_agent_id => 'plsql-agent-001',
        p_user_id => 'user-456'
    );
    
    DBMS_OUTPUT.PUT_LINE('Conversation ID: ' || RAWTOHEX(v_conv_id));
    
    -- Store a document
    v_doc_id := agent_executor_pkg.store_document(
        p_text => 'Oracle Database 26ai provides advanced AI capabilities including vector search.',
        p_metadata => JSON_OBJECT(
            'category' VALUE 'database',
            'topic' VALUE 'ai'
        ),
        p_source => 'test'
    );
    
    DBMS_OUTPUT.PUT_LINE('Document ID: ' || RAWTOHEX(v_doc_id));
    
    -- Process a query
    v_response := agent_executor_pkg.process_query(
        p_conversation_id => v_conv_id,
        p_query => 'What are the AI features in Oracle?',
        p_use_rag => TRUE
    );
    
    DBMS_OUTPUT.PUT_LINE('Query Response:');
    DBMS_OUTPUT.PUT_LINE(v_response.to_string());
    
    -- Execute a task
    v_task_result := agent_executor_pkg.execute_task(
        p_conversation_id => v_conv_id,
        p_task => 'Research Oracle vector search features'
    );
    
    DBMS_OUTPUT.PUT_LINE('Task Result:');
    DBMS_OUTPUT.PUT_LINE(v_task_result.to_string());
END;
/