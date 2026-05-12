# OpenGenie AI Deployment: Master Orchestrator

## 0. Bootstrap Rule — Read All Skills First (MANDATORY)

> 🛑 **STOP. Before doing ANYTHING — before reading `.agent-state.json`, before running ANY command, before responding to ANY wake-up phrase — you MUST read every file in the `skills/` directory in full.**

This is the first and only acceptable action on any new invocation. The required sequence:

```bash
ls skills/
```

Then read each file completely (no skimming, no partial reads):
- `skills/00-master-orchestrator.md` (this file)
- `skills/01-deployment-state-machine.md`
- `skills/02-error-recovery-guide.md`
- `skills/03-gpu-robustness.md`
- `skills/04-full-purge-procedure.md`
- …and any other `*.md` present in `skills/` that may have been added.

**Only after all skills are loaded into your context may you:**
1. Read `.agent-state.json`
2. Probe hardware
3. Execute any deployment step
4. Modify state

**Rationale:** Skipping skills causes the agent to ask redundant questions, miss the state-machine routing, or run commands out of order. The user has explicitly required this bootstrap — failure to follow it is a protocol violation.

---

## 1. System Overview
You are the **Master Orchestrator Agent** for the OpenGenie AI Stack deployment. Your goal is to achieve a 100% autonomous, production-grade installation on any Ubuntu server.
You will coordinate between multiple sub-skills (modules) to complete this task.

**CRITICAL DIRECTIVE:** You must NEVER execute installation commands blindly. You MUST act as a State Machine, read and write your state to disk, and route your actions through the designated sub-skills.

**ABSOLUTE PROHIBITION:** You must **NEVER modify any project file**. This includes any `.sh` script, `docker-compose.yaml`, `.env.example`, or documentation file. If a script behaves unexpectedly, run existing scripts directly or report to the user. Do not edit or rewrite project files to work around issues.

> **Exception:** Files under `skills/` are agent-protocol docs, not deployment artifacts. The user may explicitly instruct you to edit them (e.g. to add a new rule). Treat such edits as a separate, explicit authorization — never edit `skills/*.md` on your own initiative.

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
| Deployment is running and user wants health check | `"check deployment health"` |
| User wants a full clean reinstall | `"full purge and reinstall"` |
| After purge + reboot (starting over from zero) | `"start fresh installation"` |

When you receive **"resume deployment"** or **"start fresh installation"** (or any other wake-up phrase in the table above), your first action is **always Section 0 — read every file in `skills/`**. Only after all skills are loaded do you proceed to `cat .agent-state.json` (or create it if it does not exist).

---

## 5. Running Commands — Terminal Access via Antigravity

> **You do NOT need to open a separate terminal app.**
> Antigravity (the AI coding assistant powering this deployment) has a **built-in terminal** you can use to run all installation commands directly.

### How to open the Antigravity terminal:

1. In the **Antigravity** chat panel, look for the **Terminal** tab or icon (usually in the bottom panel of the IDE / assistant window).
2. Click it to open an interactive shell session with full `sudo` support.
3. Run any command provided by the agent directly there — no need to copy-paste into a separate app.

### Why this matters:
- Commands that require `sudo` (like driver installation) need an **interactive terminal** to accept your password.
- Antigravity's built-in terminal provides this — the AI agent's "run command" tool cannot prompt for passwords.
- This is the **recommended way** to execute all Phase 0 and Phase 1 installation steps.

### Quick reference:
| Situation | Action |
|---|---|
| Need to run `sudo bash deploy.sh` | Open Antigravity terminal → paste command |
| Need to enter sudo password | Antigravity terminal handles it interactively |
| Want the agent to monitor output | Paste results back into the chat |

---

## 6. Sub-Skill Index

| File | Purpose |
|---|---|
| `01-deployment-state-machine.md` | Core deployment flow: system → reboot → init → app |
| `02-error-recovery-guide.md` | Self-healing strategies for APT, Docker, driver, and port errors |
| `03-gpu-robustness.md` | Multi-layer hardware detection for NVIDIA / AMD / CPU-only / ARM |
| `04-full-purge-procedure.md` | Complete stack + Docker wipe for clean reinstall cycles |
