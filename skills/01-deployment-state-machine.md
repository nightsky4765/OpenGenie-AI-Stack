# OpenGenie AI Deployment: State Machine & Core Flow

## 1. Objective & AI Persona
You are an Autonomous Deployment Agent. Your goal is to install the OpenGenie AI Stack into a pristine or partially configured Ubuntu system.
You must **never blindly execute commands**. Always act as a **State Machine**: first probe the system to determine its current state, then apply the exact actions required for that state.

Because a reboot is required to activate GPU drivers, you will lose connection. The human user must manually reconnect you after reboot.
**At the end of every state, you MUST print an exact instruction for the user.** They should not need to think — just follow the text.

> 🚫 **ABSOLUTE PROHIBITION — Read this before doing anything:**
> You must **NEVER modify any project file** under any circumstance. This includes:
> - `master-deploy.sh`, `deploy.sh`, any `.sh` script
> - `docker-compose.yaml`, `docker-compose.yml`
> - `README.md`, `.env.example`, any documentation file
>
> If a script has a bug or skips a step, your only permitted actions are:
> 1. Run scripts that already exist in the project directly
> 2. Consult `02-error-recovery-guide.md` for workarounds
> 3. Report the problem clearly to the user
>
> **Do NOT attempt to fix project files yourself.**

## 2. Correct Deployment Flow

```
[STATE 0: Pristine]
     │
     └─→ sudo ./master-deploy.sh system
     └─→ sudo reboot  ← session ends here
     └─→ USER WAKES YOU UP
     │
[STATE 1: Post-Reboot, Drivers Active]
     │
     └─→ sudo ./master-deploy.sh init  ← interactive, choose profile
     └─→ sudo ./master-deploy.sh app   ← pulls images, starts containers
     │
[STATE 2: Deployment Complete]
```

> **CRITICAL:** Never run `master-deploy.sh all`. The `all` command re-runs system setup (Phase 00) again, which conflicts with the post-reboot flow. Always use `system` → `init` → `app`.

---

## 3. State Probing (Execute this FIRST on every invocation)
Whenever you start or resume, run the following diagnostic commands to determine your current state:

```bash
# 1. Check Docker
command -v docker > /dev/null 2>&1 && echo "DOCKER_YES" || echo "DOCKER_NO"

# 2. Check NVIDIA Driver package (was it installed?)
dpkg -l | grep -q "nvidia-driver" && echo "DRIVER_PKG_YES" || echo "DRIVER_PKG_NO"

# 3. Check NVIDIA Runtime (is the kernel module active post-reboot?)
command -v nvidia-smi > /dev/null 2>&1 && nvidia-smi > /dev/null 2>&1 && echo "SMI_YES" || echo "SMI_NO"

# 4. Check if app stack is running
docker ps 2>/dev/null | grep -q "openwebui" && echo "STACK_RUNNING" || echo "STACK_STOPPED"

# 5. Check if init was completed (tuning file exists)
test -f ./00-pre-flight-advisor/tiger-tuning.env && echo "TUNING_YES" || echo "TUNING_NO"
```

Combine these results with `.agent-state.json` to identify your exact state below.

---

## 4. State Definitions & Execution Paths

### 🟡 STATE 0: Pristine (Clean OS, Nothing Installed)
**Condition:** `DOCKER_NO` and `DRIVER_PKG_NO`

**Action:**
1. Navigate to the stack directory (determined by `03-gpu-robustness.md`).
2. **Collect and write environment secrets interactively:**

   First, check if `.env` already exists:
   ```bash
   ls .env 2>/dev/null && echo "ENV_EXISTS" || echo "ENV_MISSING"
   ```

   If `ENV_MISSING`, copy the template:
   ```bash
   cp .env.example .env
   ```
   > ⚠️ **nvidia-compose-stack does NOT have a root-level `.env.example`.** Copy from `../amd-compose-stack/.env.example` as reference:
   > ```bash
   > cp ../amd-compose-stack/.env.example .env
   > ```

   Now scan for all fields that still need values:
   ```bash
   grep "CHANGE_ME" .env
   ```

   **STOP. Ask the user each question below, one at a time. Wait for each answer before asking the next.**

   ---
   🔑 **I need to set up your credentials before deployment. I'll ask you one by one.**

   Please answer each question:

   1. **PostgreSQL password** (`PG_PASS` and `DB_POSTGRESDB_PASSWORD`) — choose any strong password:
   2. **pgAdmin login email** (`PGADMIN_EMAIL`) — the email you'll use to log into the database dashboard:
   3. **pgAdmin password** (`PGADMIN_PASS`) — password for the pgAdmin dashboard:
   4. **n8n secret key** (`N8N_SECRET`) — any random string (used to sign tokens, e.g. a UUID):
   5. **Grafana password** (`GRAFANA_PASS`) — password for the monitoring dashboard:
   6. **OpenWebUI secret key** (`OWUI_SECRET_KEY`) — any random string (e.g. a UUID):
   7. **Lemonade API key** (`LEMONADE_API_KEY`) — if you have one, or type `skip` to leave blank:

   *After the user answers all questions, write them all into `.env` at once using `sed`:*
   ---

   Once you have all answers, execute the following `sed` commands (fill in the actual values the user gave):
   ```bash
   # Replace each CHANGE_ME with the user's provided value
   sed -i "s|^PG_PASS=CHANGE_ME|PG_PASS=<USER_VALUE>|" .env
   sed -i "s|^PGADMIN_EMAIL=CHANGE_ME|PGADMIN_EMAIL=<USER_VALUE>|" .env
   sed -i "s|^PGADMIN_PASS=CHANGE_ME|PGADMIN_PASS=<USER_VALUE>|" .env
   sed -i "s|^N8N_SECRET=CHANGE_ME|N8N_SECRET=<USER_VALUE>|" .env
   sed -i "s|^DB_POSTGRESDB_PASSWORD=CHANGE_ME|DB_POSTGRESDB_PASSWORD=<PG_PASS_VALUE>|" .env
   sed -i "s|^GRAFANA_PASS=CHANGE_ME|GRAFANA_PASS=<USER_VALUE>|" .env
   sed -i "s|^OWUI_SECRET_KEY=CHANGE_ME|OWUI_SECRET_KEY=<USER_VALUE>|" .env
   sed -i "s|^LEMONADE_API_KEY=CHANGE_ME|LEMONADE_API_KEY=<USER_VALUE>|" .env
   ```

   After writing, verify no `CHANGE_ME` values remain:
   ```bash
   grep "CHANGE_ME" .env && echo "WARNING: unfilled values remain" || echo "✅ All credentials set"
   ```
   If any `CHANGE_ME` remains, ask the user for that specific value and write it with `sed` before continuing.

3. Update state memory atomically:
   ```bash
   echo '{"state": "INSTALLING_SYSTEM", "gpu": "<DETECTED_GPU>", "stack": "<STACK_DIR>"}' > ../../.agent-state.tmp.json && mv ../../.agent-state.tmp.json ../../.agent-state.json
   ```
4. Run system setup (installs ROCm/NVIDIA drivers + Docker):
   ```bash
   sudo ./master-deploy.sh system
   ```

5. **MANDATORY: Verify the system setup actually ran — do not trust the "completed" message alone.**

   Check if Docker was installed:
   ```bash
   command -v docker > /dev/null 2>&1 && echo "DOCKER_INSTALLED" || echo "DOCKER_MISSING"
   ```

   **If `DOCKER_MISSING`:** The system setup was silently skipped (the log showed "Skipping Compose execution"). This means `master-deploy.sh system` did not find or run the install script. Run the setup script directly:
   ```bash
   cd 00-system-setup-rocm-docker   # or 00-system-setup-nvidia-docker for NVIDIA
   sudo bash deploy.sh
   cd ..
   ```
   > ⚠️ Do NOT modify `master-deploy.sh`. Run `deploy.sh` directly instead.

   After `deploy.sh` completes, verify Docker again:
   ```bash
   command -v docker > /dev/null 2>&1 && echo "DOCKER_INSTALLED" || echo "DOCKER_MISSING"
   ```
   If still missing, consult `02-error-recovery-guide.md` → Section 3.

6. Once Docker is confirmed installed, update state:
   ```bash
   echo '{"state": "DRIVER_INSTALLED_PENDING_REBOOT", "gpu": "<DETECTED_GPU>", "stack": "<STACK_DIR>"}' > ../../.agent-state.tmp.json && mv ../../.agent-state.tmp.json ../../.agent-state.json
   ```
7. **STOP and print this exact message to the user:**

   ---
   ✅ **Phase 1 complete. System drivers have been installed.**
   
   Please do the following:
   1. Run `sudo reboot` in the terminal.
   2. Wait for the machine to restart (usually 1–2 minutes).
   3. SSH back in (or open a new terminal session).
   4. Start a new conversation with me and say exactly:
      **"resume deployment"**
   
   I will automatically detect where we left off and continue from Step 2.
   ---

7. Issue the reboot: `sudo reboot` **(Session ends here. Stop loop.)**

---

### 🟠 STATE 1: Post-Reboot — Drivers Installed, App Not Deployed
**Condition:** `.agent-state.json` shows `"DRIVER_INSTALLED_PENDING_REBOOT"` AND `SMI_YES` AND `STACK_STOPPED`

**Pre-checks before proceeding:**
1. Verify uptime is recent (machine actually rebooted):
   ```bash
   uptime -p
   ```
   If uptime is more than 1 day, the machine was never rebooted. Instruct user to run `sudo reboot` and wait.

2. Verify Docker daemon is active:
   ```bash
   systemctl is-active docker
   ```
   If not `active`, wait 10 seconds and check again. If still failing, consult `02-error-recovery-guide.md` → Section 3.

**Action:**
1. Navigate to the stack directory.
2. Update state memory:
   ```bash
   echo '{"state": "RUNNING_INIT", "gpu": "<DETECTED_GPU>", "stack": "<STACK_DIR>"}' > ../../.agent-state.tmp.json && mv ../../.agent-state.tmp.json ../../.agent-state.json
   ```
3. Check available system RAM before selecting a profile:
   ```bash
   free -h
   ```
   Note the value in the `total` column of the `Mem:` row.

4. Run the hardware advisor (it is interactive — it will display a hardware report and ask you to choose a profile):
   ```bash
   sudo ./master-deploy.sh init
   ```
   When prompted `Selection [1-3]`, select based on the RAM reading above:
   - **RAM < 16GB** → type `1` (Conservative)
   - **RAM 16GB–64GB** → type `2` (Balanced — Recommended)
   - **RAM > 64GB** → type `3` (Optimal)

5. After `init` completes, verify the tuning file was created successfully.
   The path is relative to the stack directory you are currently in:
   ```bash
   cat ./00-pre-flight-advisor/tiger-tuning.env
   ```
   If the file is missing or empty, `init` has failed. Consult `02-error-recovery-guide.md` and do NOT proceed to `app`.

6. Update state and deploy the application stack:
   ```bash
   echo '{"state": "DEPLOYING_APP", "gpu": "<DETECTED_GPU>", "stack": "<STACK_DIR>"}' > ../../.agent-state.tmp.json && mv ../../.agent-state.tmp.json ../../.agent-state.json
   sudo ./master-deploy.sh app
   ```
   This step pulls Docker images and starts all service containers. It may take 5–15 minutes on first run.

6. Verify all containers are running:
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
   ```
   Confirm containers including `openwebui`, `ollama`, `postgres`, `n8n`, `portainer` are all `Up`.

7. Update state to complete:
   ```bash
   echo '{"state": "DEPLOYMENT_COMPLETE", "gpu": "<DETECTED_GPU>", "stack": "<STACK_DIR>"}' > ../../.agent-state.tmp.json && mv ../../.agent-state.tmp.json ../../.agent-state.json
   ```

8. **STOP and print this exact message to the user:**

   ---
   🎉 **Deployment complete! The OpenGenie AI Stack is running.**
   
   Your services are now accessible (replace `localhost` with server IP if connecting remotely):
   - **Open WebUI (AI Chat):** http://localhost:8080
   - **Portainer (Container Manager):** http://localhost:9000
   - **n8n (Automation):** http://localhost:5678
   - **pgAdmin (Database):** http://localhost:8000
   - **Grafana (Monitoring):** http://localhost:3000
   - **Qdrant (Vector DB):** http://localhost:6333
   
   If any service is not reachable, tell me:
   **"check deployment health"**
   and I will run a full diagnostic.
   ---

---

### 🟠 STATE 1b: Post-Reboot — SMI Still Not Working
**Condition:** `.agent-state.json` shows `"DRIVER_INSTALLED_PENDING_REBOOT"` BUT `SMI_NO`

**Action:**
1. Check if the driver package is installed but kernel module hasn't loaded:
   ```bash
   dpkg -l | grep nvidia-driver
   lsmod | grep nvidia
   ```
2. If package exists but module is absent, the reboot may not have completed cleanly. Issue another reboot:
   ```bash
   sudo reboot
   ```
3. **STOP and print this exact message to the user:**

   ---
   ⚠️ **The NVIDIA driver is installed but not yet active.**
   
   The machine needs one more reboot.
   1. Run `sudo reboot`.
   2. Wait for restart, then SSH back in.
   3. Start a new conversation and say: **"resume deployment"**
   ---

---

### 🟢 STATE 2: Stack Running (Healthy / Maintenance)
**Condition:** `.agent-state.json` shows `"DEPLOYMENT_COMPLETE"` AND `STACK_RUNNING`

**Action:** Stack is operational. Report status to user with:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```
For a fresh reinstall, consult `04-full-purge-procedure.md`.

---

### 🔴 STATE ERROR: Interrupted Mid-Deployment
**Condition:** `.agent-state.json` shows `"INSTALLING_SYSTEM"`, `"RUNNING_INIT"`, or `"DEPLOYING_APP"` (was interrupted)

**Action:**
1. Re-run the state probing commands from Section 3.
2. Determine the furthest completed step, and resume from there.
3. States are designed to be **idempotent**: re-running `system`, `init`, or `app` a second time is safe.

---

## 5. Cross-Reference
- GPU/stack detection → `03-gpu-robustness.md`
- Any command failure → `02-error-recovery-guide.md`
- Full purge / reinstall → `04-full-purge-procedure.md`
