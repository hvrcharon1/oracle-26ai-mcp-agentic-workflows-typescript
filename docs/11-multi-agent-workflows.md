# Multi-Agent Workflows

## Overview

Orchestrating multiple AI agents for complex tasks using Oracle 26ai.

## Agent Coordination Patterns

### 1. Sequential Workflow

```typescript
class SequentialWorkflow {
    private agents: Map<string, IntelligentAgent>;

    async execute(task: string): Promise<WorkflowResult> {
        const steps = [
            { agent: 'researcher', task: 'Research the topic' },
            { agent: 'analyzer', task: 'Analyze the findings' },
            { agent: 'writer', task: 'Write a summary' }
        ];

        const results: StepResult[] = [];
        let context = task;

        for (const step of steps) {
            const agent = this.agents.get(step.agent)!;
            const result = await agent.processQuery(
                `${step.task}\n\nContext: ${context}`,
                `workflow-${Date.now()}`
            );

            results.push({
                agent: step.agent,
                task: step.task,
                result: result.message
            });

            // Pass result as context to next agent
            context = result.message;
        }

        return {
            task,
            steps: results,
            finalResult: context
        };
    }
}
```

### 2. Parallel Workflow

```typescript
class ParallelWorkflow {
    async execute(task: string): Promise<WorkflowResult> {
        const agents = [
            { name: 'researcher1', specialty: 'academic' },
            { name: 'researcher2', specialty: 'industry' },
            { name: 'researcher3', specialty: 'news' }
        ];

        // Execute in parallel
        const promises = agents.map(async (agentConfig) => {
            const agent = this.getAgent(agentConfig.name);
            return agent.processQuery(
                `${task} (focus on ${agentConfig.specialty})`,
                `parallel-${agentConfig.name}-${Date.now()}`
            );
        });

        const results = await Promise.all(promises);

        // Synthesize results
        const synthesizer = this.getAgent('synthesizer');
        const finalResult = await synthesizer.processQuery(
            `Synthesize these findings:\n\n${results.map((r, i) => 
                `Source ${i + 1}: ${r.message}`
            ).join('\n\n')}`,
            `synthesis-${Date.now()}`
        );

        return {
            task,
            parallelResults: results,
            synthesizedResult: finalResult.message
        };
    }
}
```

### 3. Hierarchical Workflow

```typescript
class HierarchicalWorkflow {
    private supervisorAgent: IntelligentAgent;
    private workerAgents: Map<string, IntelligentAgent>;

    async execute(task: string): Promise<WorkflowResult> {
        // Supervisor creates plan
        const plan = await this.supervisorAgent.processQuery(
            `Create a detailed plan to: ${task}`,
            `supervisor-${Date.now()}`
        );

        const subtasks = this.parsePlan(plan.message);
        const results: any[] = [];

        // Assign subtasks to workers
        for (const subtask of subtasks) {
            const worker = this.selectWorker(subtask.type);
            const result = await worker.processQuery(
                subtask.description,
                `worker-${subtask.id}`
            );

            results.push({
                subtask: subtask.description,
                worker: worker.config.agentId,
                result: result.message
            });
        }

        // Supervisor reviews and finalizes
        const finalResult = await this.supervisorAgent.processQuery(
            `Review and finalize:\n${results.map(r => 
                `- ${r.subtask}: ${r.result}`
            ).join('\n')}`,
            `supervisor-final-${Date.now()}`
        );

        return {
            task,
            plan: subtasks,
            subtaskResults: results,
            finalResult: finalResult.message
        };
    }
}
```

## Database Schema for Multi-Agent

```sql
-- Agent registry
CREATE TABLE agent_registry (
    agent_id VARCHAR2(100) PRIMARY KEY,
    agent_name VARCHAR2(200) NOT NULL,
    agent_type VARCHAR2(50) NOT NULL,
    capabilities JSON,
    status VARCHAR2(20) DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Workflow definitions
CREATE TABLE workflow_definitions (
    workflow_id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    workflow_name VARCHAR2(200) NOT NULL,
    workflow_type VARCHAR2(50) NOT NULL,
    configuration JSON,
    created_at TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Workflow executions
CREATE TABLE workflow_executions (
    execution_id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    workflow_id RAW(16) NOT NULL,
    status VARCHAR2(20) DEFAULT 'RUNNING',
    start_time TIMESTAMP DEFAULT SYSTIMESTAMP,
    end_time TIMESTAMP,
    result JSON,
    CONSTRAINT fk_workflow 
        FOREIGN KEY (workflow_id) 
        REFERENCES workflow_definitions(workflow_id)
);

-- Agent assignments
CREATE TABLE agent_assignments (
    assignment_id RAW(16) DEFAULT SYS_GUID() PRIMARY KEY,
    execution_id RAW(16) NOT NULL,
    agent_id VARCHAR2(100) NOT NULL,
    task_description CLOB,
    status VARCHAR2(20) DEFAULT 'PENDING',
    result JSON,
    created_at TIMESTAMP DEFAULT SYSTIMESTAMP,
    completed_at TIMESTAMP,
    CONSTRAINT fk_execution 
        FOREIGN KEY (execution_id) 
        REFERENCES workflow_executions(execution_id),
    CONSTRAINT fk_agent 
        FOREIGN KEY (agent_id) 
        REFERENCES agent_registry(agent_id)
);
```

## PL/SQL Workflow Manager

```sql
CREATE OR REPLACE PACKAGE workflow_manager_pkg AS
    -- Register agent
    PROCEDURE register_agent(
        p_agent_id IN VARCHAR2,
        p_agent_name IN VARCHAR2,
        p_agent_type IN VARCHAR2,
        p_capabilities IN JSON
    );
    
    -- Create workflow
    FUNCTION create_workflow(
        p_workflow_name IN VARCHAR2,
        p_workflow_type IN VARCHAR2,
        p_configuration IN JSON
    ) RETURN RAW;
    
    -- Execute workflow
    FUNCTION execute_workflow(
        p_workflow_id IN RAW,
        p_input_data IN JSON
    ) RETURN RAW;
    
    -- Assign task to agent
    PROCEDURE assign_task(
        p_execution_id IN RAW,
        p_agent_id IN VARCHAR2,
        p_task_description IN CLOB
    );
    
    -- Update task result
    PROCEDURE update_task_result(
        p_assignment_id IN RAW,
        p_result IN JSON,
        p_status IN VARCHAR2
    );
END workflow_manager_pkg;
/

CREATE OR REPLACE PACKAGE BODY workflow_manager_pkg AS
    
    PROCEDURE register_agent(
        p_agent_id IN VARCHAR2,
        p_agent_name IN VARCHAR2,
        p_agent_type IN VARCHAR2,
        p_capabilities IN JSON
    ) IS
    BEGIN
        INSERT INTO agent_registry (
            agent_id, agent_name, agent_type, capabilities
        ) VALUES (
            p_agent_id, p_agent_name, p_agent_type, p_capabilities
        );
        COMMIT;
    END register_agent;
    
    FUNCTION create_workflow(
        p_workflow_name IN VARCHAR2,
        p_workflow_type IN VARCHAR2,
        p_configuration IN JSON
    ) RETURN RAW IS
        v_workflow_id RAW(16);
    BEGIN
        INSERT INTO workflow_definitions (
            workflow_name, workflow_type, configuration
        ) VALUES (
            p_workflow_name, p_workflow_type, p_configuration
        ) RETURNING workflow_id INTO v_workflow_id;
        
        COMMIT;
        RETURN v_workflow_id;
    END create_workflow;
    
    FUNCTION execute_workflow(
        p_workflow_id IN RAW,
        p_input_data IN JSON
    ) RETURN RAW IS
        v_execution_id RAW(16);
        v_workflow_type VARCHAR2(50);
        v_configuration JSON;
    BEGIN
        -- Get workflow configuration
        SELECT workflow_type, configuration
        INTO v_workflow_type, v_configuration
        FROM workflow_definitions
        WHERE workflow_id = p_workflow_id;
        
        -- Create execution record
        INSERT INTO workflow_executions (
            workflow_id, status
        ) VALUES (
            p_workflow_id, 'RUNNING'
        ) RETURNING execution_id INTO v_execution_id;
        
        COMMIT;
        RETURN v_execution_id;
    END execute_workflow;
    
    PROCEDURE assign_task(
        p_execution_id IN RAW,
        p_agent_id IN VARCHAR2,
        p_task_description IN CLOB
    ) IS
    BEGIN
        INSERT INTO agent_assignments (
            execution_id,
            agent_id,
            task_description,
            status
        ) VALUES (
            p_execution_id,
            p_agent_id,
            p_task_description,
            'ASSIGNED'
        );
        COMMIT;
    END assign_task;
    
    PROCEDURE update_task_result(
        p_assignment_id IN RAW,
        p_result IN JSON,
        p_status IN VARCHAR2
    ) IS
    BEGIN
        UPDATE agent_assignments
        SET result = p_result,
            status = p_status,
            completed_at = SYSTIMESTAMP
        WHERE assignment_id = p_assignment_id;
        
        COMMIT;
    END update_task_result;
    
END workflow_manager_pkg;
/
```

## Usage Example

```typescript
import { IntelligentAgent } from './intelligent-agent';

class MultiAgentOrchestrator {
    private agents: Map<string, IntelligentAgent> = new Map();

    registerAgent(id: string, agent: IntelligentAgent): void {
        this.agents.set(id, agent);
    }

    async executeWorkflow(
        workflowType: 'sequential' | 'parallel' | 'hierarchical',
        task: string
    ): Promise<any> {
        switch (workflowType) {
            case 'sequential':
                return new SequentialWorkflow(this.agents).execute(task);
            case 'parallel':
                return new ParallelWorkflow(this.agents).execute(task);
            case 'hierarchical':
                return new HierarchicalWorkflow(this.agents).execute(task);
        }
    }
}

// Usage
const orchestrator = new MultiAgentOrchestrator();

orchestrator.registerAgent('researcher', researchAgent);
orchestrator.registerAgent('analyzer', analyzerAgent);
orchestrator.registerAgent('writer', writerAgent);

const result = await orchestrator.executeWorkflow(
    'sequential',
    'Create a comprehensive report on Oracle 26ai'
);

console.log(result);
```

---

**Next**: [Performance Optimization →](12-performance-optimization.md)