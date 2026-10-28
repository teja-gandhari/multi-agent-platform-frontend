# NexusAI Flutter Frontend

Modern Flutter frontend for the NexusAI Multi-Agent Collaboration Platform.

---

## 🚀 Connected Backend Endpoints

The frontend integrates directly with every endpoint provided by the FastAPI backend:

### 1. System & Health
- `GET /health` – Real-time backend status checking with UI indicator pill (green online / red offline).

### 2. Authentication
- `POST /auth/register` – New account creation (`email`, `username`, `password`).
- `POST /auth/login` – OAuth2 form-urlencoded authentication (`username` [email], `password`), stores JWT token.
- `GET /auth/me` – Profile verification with automatic session restoration and user badge.

### 3. Projects
- `GET /project?page={page}&limit={limit}` – Paginated project list with status filtering.
- `POST /project` – Create project (`title`, `description`).
- `GET /project/{id}` – Single project details.
- `PUT /project/{id}` – Edit project details (`name`, `description`).
- `PATCH /project/{id}/status` – Update project lifecycle state (`created`, `planning`, `running`, `completed`, `failed`).
- `DELETE /project/{id}` – Delete project with confirmation dialog.

### 4. Tasks
- `GET /projects/{project_id}/tasks` – List tasks for a project.
- `GET /projects/{project_id}/tasks/{task_id}` – Specific task details.
- `POST /projects/{project_id}/tasks` – Create new task (`title`, `description`, `priority`: `low`, `medium`, `high`, `critical`).
- `PATCH /projects/{project_id}/tasks/{task_id}` – Update task details.
- `PATCH /projects/{project_id}/tasks/{task_id}/status` – Quick status cycle (`pending`, `in_progress`, `completed`, `failed`).
- `DELETE /projects/{project_id}/tasks/{task_id}` – Delete task.

### 5. AI Agent Team & Workflow Orchestration
- `POST /agents/run` – Execute the multi-agent workflow team (Planner → Researcher → Developer → Coder → Tester → Reviewer).
- `GET /agents/runs/{project_id}` – History of workflow runs for the active project.
- `GET /agents/runs/{run_id}/plan` – Detailed planner markdown inspection.
- `POST /agents/runs/{run_id}/approve` – Human-in-the-loop plan approval to resume execution.
- `POST /agents/runs/{run_id}/request-changes` – Submit feedback to the Planner for revision.
- `GET /agents/runs/{run_id}/messages` – Historical chronological agent messages and telemetry logs.

### 6. Real-time WebSocket Telemetry
- `ws://<host>:<port>/ws/{project_id}?token={token}` – Live streaming of incoming `AgentEvent` logs with agent avatars, status indicators, and automatic state refresh.

---

## 🎨 Theme & UI Architecture

Built specifically adhering to the NexusAI space-navy project theme:
- **Background**: `#0B1020`
- **Surface**: `#11182A`
- **Card**: `#161F36`
- **Border**: `#22304C`
- **Accent**: `#8B9CFF` / `#6B7DFE`
- **Agent Roles**: Distinct badges and icons for Planner, Researcher, Developer, Coder, Tester, and Reviewer.
- **Responsive Layout**: Dual-panel desktop layout and adaptive mobile view.

---

