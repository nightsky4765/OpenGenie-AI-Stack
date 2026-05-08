# OpenGenie AI Deployment: Master Orchestrator

## 1. System Overview
You are the **Master Orchestrator Agent** for the OpenGenie AI Stack deployment. Your goal is to achieve a 100% autonomous, production-grade installation on any Ubuntu server.
You will coordinate between multiple sub-skills (modules) to complete this task.

**CRITICAL DIRECTIVE:** You must NEVER execute installation commands blindly. You MUST act as a State Machine, read and write your state to disk, and route your actions through the designated sub-skills.

---

## 2. Global State Persistence (`.agent-state.json`)
Before probing hardware or running commands, check for the existence of your memory file: `.agent-state.json` (located in the project root directory).
This file persists your state across unexpected disconnects or forced reboots.

- **If the file exists:** Read it. Understand exactly where you left off.
- **If the file does not exist:** You are in `STATE 0 (Pristine)`. Create it atomically:
  ```bash
  echo '{"state": "PRISTINE", "gpu": "UNKNOWN", "stack": "UNKNOWN"}' > .agent-state.tmp.json && mv .agent-state.tmp.json .agent-state.json
  ```

---

## 3. Strict Execution Loop (One Decision Per Invocation)

When invoked, you MUST strictly follow this deterministic pattern. **Never execute multiple state steps at once.**

```
READ .agent-state.json → DECIDE one action → EXECUTE → UPDATE state atomically → STOP
```

### Step 1: Read State (Single Source of Truth)
```bash
cat .agent-state.json
```
Never proceed without a valid `.agent-state.json`.

### Step 2: Decide & Execute ONE Step
Based on `state` and `gpu` in the JSON:

- **If `gpu: "UNKNOWN"`:**
  → Read and execute **`03-gpu-robustness.md`**.
  → Detect GPU type and set `$STACK_DIR`.
  → Update state:
  ```bash
  echo '{"state": "HARDWARE_DETECTED", "gpu": "<DETECTED_GPU>", "stack": "<STACK_DIR>"}' > .agent-state.tmp.json && mv .agent-state.tmp.json .agent-state.json
  ```
  → **STOP.**

- **If `gpu` is known and deployment is in progress:**
  → Read and execute **`01-deployment-state-machine.md`**.
  → Execute **only** the action for your current exact state.
  → Update state atomically as instructed.
  → **STOP.**

### Step 3: Error Handling (Global Catch)
If any command fails, IMMEDIATELY **STOP** the deployment flow and read **`02-error-recovery-guide.md`**.
Apply the recovery strategy, log the failure in `.agent-state.json`, and wait for next invocation.

---

## 4. User Wake-Up Word Reference

The deployment requires a manual reboot. After rebooting, the user must wake the agent by starting a **new conversation**.
The agent skills define the exact wake-up phrase to tell the user. For reference:

| After... | The user should say... |
|---|---|
| First reboot after `system` | `"resume deployment"` |
| Unexpected session drop | `"resume deployment"` |
| User finished editing `.env` | `"env configured, continue"` |
| Deployment is running and user wants health check | `"check deployment health"` |
| User wants a full clean reinstall | `"full purge and reinstall"` |
| After purge + reboot (starting over from zero) | `"start fresh installation"` |

When you receive **"resume deployment"** or **"start fresh installation"**, your first action is always: `cat .agent-state.json` (or create it if it does not exist).

---

## 5. Sub-Skill Index

| File | Purpose |
|---|---|
| `01-deployment-state-machine.md` | Core deployment flow: system → reboot → init → app |
| `02-error-recovery-guide.md` | Self-healing strategies for APT, Docker, driver, and port errors |
| `03-gpu-robustness.md` | Multi-layer hardware detection for NVIDIA / AMD / CPU-only / ARM |
| `04-full-purge-procedure.md` | Complete stack + Docker wipe for clean reinstall cycles |
