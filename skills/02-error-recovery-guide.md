# OpenGenie AI Deployment: Error Recovery Guide

During the deployment of the OpenGenie AI Stack, especially in dynamic or dirty environments, you may encounter system-level errors. 
As an Autonomous Agent, you must NOT stop and ask the user for help immediately. You must attempt these self-healing recovery strategies first.

## 1. APT Lock Deadlock (`/var/lib/dpkg/lock-frontend`)
**Symptom:** `E: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process XXXX`
**Recovery Strategy:**
Sometimes background update processes (`unattended-upgrades`) lock the package manager.
1. Check what is holding the lock: `lsof /var/lib/dpkg/lock-frontend`
2. Forcefully kill the apt processes:
   ```bash
   sudo killall apt apt-get dpkg unattended-upgrades || true
   ```
3. Remove the locks safely:
   ```bash
   sudo rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend /var/cache/apt/archives/lock
   ```
4. Reconfigure dpkg:
   ```bash
   sudo dpkg --configure -a
   ```
5. Retry your previous `apt` or `master-deploy.sh` command.

## 2. NVIDIA Driver Installation Conflicts
**Symptom:** `dpkg` errors during `nvidia-driver` installation, or `nvidia-smi` says "Failed to initialize NVML: Driver/library version mismatch".
**Recovery Strategy:**
This happens when old drivers conflict, or the `nouveau` open-source driver is aggressively holding the kernel.
1. Purge all existing NVIDIA packages:
   ```bash
   sudo apt-get purge -y '*nvidia*'
   sudo apt-get autoremove -y
   ```
2. Re-run Phase 00:
   ```bash
   sudo ./master-deploy.sh system
   ```
3. If `nouveau` is interfering, reboot the system to let the blacklist take effect, then resume.

## 3. Docker Daemon Fails to Start
**Symptom:** `Cannot connect to the Docker daemon at unix:///var/run/docker.sock.` or Phase 01 fails immediately.
**Recovery Strategy:**
1. Check the Docker service status and logs:
   ```bash
   sudo systemctl status docker
   sudo journalctl -u docker --no-pager | tail -n 20
   ```
2. Often, this is caused by a corrupted `/etc/docker/daemon.json` (e.g., misconfigured NVIDIA runtime).
3. Temporarily move the config and restart to isolate the issue:
   ```bash
   sudo mv /etc/docker/daemon.json /etc/docker/daemon.json.backup
   sudo systemctl restart docker
   ```
4. Re-run Phase 00 to let it cleanly regenerate the NVIDIA Container Toolkit config.

## 4. Port Conflicts during App Deployment
**Symptom:** `docker compose` fails with `Bind for 0.0.0.0:8080 failed: port is already allocated` or similar.
**Recovery Strategy:**
1. Identify the rogue process occupying the port (e.g., 8080 or 5432):
   ```bash
   sudo lsof -i :8080
   sudo netstat -tulpn | grep :8080
   ```
2. If the process is safe to terminate (like an old zombie node or python process), kill it:
   ```bash
   sudo kill -9 <PID>
   ```
3. Retry: `sudo ./master-deploy.sh app`

## 5. Network Timeouts (Docker Pull Fails)
**Symptom:** `error pulling image configuration: download failed after attempts=6`
**Recovery Strategy:**
1. Network hiccups happen. Simply execute the command again. Docker will resume the layer download from where it failed.
2. `sudo ./master-deploy.sh app` is idempotent. Running it multiple times is safe.
