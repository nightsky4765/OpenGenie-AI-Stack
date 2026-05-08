# OpenGenie AI Deployment: Full Purge Procedure

## Purpose
This skill covers the complete teardown of the OpenGenie stack and all its dependencies (Docker, NVIDIA drivers, volumes, configs).
Use this during training loops or when a completely clean reinstall is required.

**Trigger phrase:** User says `"full purge and reinstall"` or deployment is broken beyond recovery.

---

## Phase 1: Stop All Running Containers
Navigate to the detected stack directory first, then stop all compose services:

```bash
cd deployments/<STACK_DIR>
sudo ./master-deploy.sh clean
```

If `master-deploy.sh clean` fails (Docker daemon is broken), force-remove containers manually:
```bash
docker ps -aq | xargs docker rm -f 2>/dev/null || true
```

---

## Phase 2: Remove Docker Volumes (Data Wipe)
This permanently deletes all database data, AI model caches, and configuration volumes.

```bash
docker volume ls -q | xargs docker volume rm 2>/dev/null || true
```

> ⚠️ This is irreversible. Only do this if a full fresh install is intended.

---

## Phase 3: Purge Docker Completely

```bash
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt-get autoremove -y
sudo rm -rf /var/lib/docker
sudo rm -rf /etc/docker
sudo rm -f /usr/local/bin/docker-compose
```

Verify Docker is gone:
```bash
command -v docker && echo "DOCKER_STILL_PRESENT" || echo "DOCKER_REMOVED_OK"
```

---

## Phase 4: Purge NVIDIA Drivers (if reinstalling GPU stack)

```bash
sudo apt-get purge -y '*nvidia*'
sudo apt-get purge -y '*cuda*'
sudo apt-get autoremove -y
sudo apt-get autoclean
```

Remove leftover NVIDIA container toolkit configs:
```bash
sudo rm -f /etc/docker/daemon.json
sudo rm -rf /etc/nvidia-container-runtime
```

Verify drivers are gone:
```bash
dpkg -l | grep -i nvidia && echo "NVIDIA_PKGS_STILL_PRESENT" || echo "NVIDIA_REMOVED_OK"
```

---

## Phase 5: Clean Project State Files

Reset the agent's memory so the next invocation starts from `PRISTINE`:

```bash
# From the project root directory
rm -f .agent-state.json
rm -f deployments/nvidia-compose-stack/00-pre-flight-advisor/tiger-tuning.env
rm -f deployments/amd-compose-stack/00-pre-flight-advisor/tiger-tuning.env
rm -f deployments/arm64-compose-stack/00-pre-flight-advisor/tiger-tuning.env
```

---

## Phase 6: Reboot to Clear Kernel Modules

```bash
sudo reboot
```

**STOP and print this exact message to the user:**

---
🧹 **Full purge complete. The system is clean.**

The machine is rebooting to clear all kernel modules.

After restart:
1. SSH back into the machine.
2. Start a new conversation and say: **"start fresh installation"**

I will start the fresh installation from the beginning.

---

---

## Post-Purge Verification (Run after reboot, before reinstalling)

```bash
# These should ALL return "not found" / errors — confirming a clean slate
command -v docker && echo "DOCKER_FOUND (unexpected)" || echo "Docker: clean ✅"
command -v nvidia-smi && echo "NVIDIA_SMI_FOUND (unexpected)" || echo "NVIDIA SMI: clean ✅"
ls /var/lib/docker 2>/dev/null && echo "Docker data still exists (unexpected)" || echo "Docker data: clean ✅"
```

Only proceed with reinstall if all three show clean.
