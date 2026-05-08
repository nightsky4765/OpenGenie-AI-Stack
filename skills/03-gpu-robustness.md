# OpenGenie AI Deployment: GPU & Hardware Robustness

A common failure point for Autonomous Agents is incorrectly identifying the hardware environment. The system might be a Virtual Machine with vGPU, a cloud instance with PCI passthrough, or a CPU-only edge device. 
You must robustly identify the correct `$STACK_DIR` before taking any deployment actions.

## 1. Multi-Layer Hardware Detection
Do not rely on a single command to detect the GPU. Use a fallback chain.

### Step A: Native Utilities (Fastest, if installed)
Run these first:
```bash
command -v nvidia-smi >/dev/null && echo "NVIDIA"
command -v rocm-smi >/dev/null && echo "AMD"
```
If either command succeeds and outputs the respective brand, you can confidently select the stack:
- **NVIDIA:** `deployments/nvidia-compose-stack`
- **AMD:** `deployments/amd-compose-stack`

### Step B: PCI Bus Probing (For Pristine Systems)
If Native Utilities fail (e.g., drivers are not installed yet), probe the PCI bus:
```bash
lspci | grep -iE 'vga|3d|2d'
```
Analyze the output:
- Keywords `NVIDIA`, `GeForce`, `Tesla`, `Grid`: Select `deployments/nvidia-compose-stack`
- Keywords `AMD`, `Radeon`, `Advanced Micro Devices`: Select `deployments/amd-compose-stack`
- Keywords `VMware SVGA`, `Virtio`, or no output: Proceed to CPU/ARM fallback.

### Step C: CPU / ARM Fallback (The Safety Net)
If no dedicated GPU is detected, or the environment is heavily virtualized without passthrough, you MUST fallback to the CPU-only or ARM64 stack.
Run architecture check:
```bash
uname -m
```
- If `aarch64` or `arm64` (like AWS Graviton, Mac M-Series): Select `deployments/arm64-compose-stack`
- If `x86_64` but NO GPU was found: You can still use `deployments/arm64-compose-stack` as it contains CPU-only configurations compatible with generic architectures.

## 2. Setting the Working Directory
Once you have determined the `$STACK_DIR`, navigate to it RELATIVE to the project root.
**Never hardcode absolute paths like `/home/user/OpenGenie`**, as your Git clone location may change.

```bash
cd deployments/nvidia-compose-stack  # Or your detected stack
```

## 3. Handling Edge Cases
- **Stuck GPU (PCIe reset bug):** If `nvidia-smi` hangs indefinitely, the GPU has crashed. Recovery: Reboot the machine immediately.
- **Multiple GPUs of Mixed Brands:** If a system has both AMD and NVIDIA GPUs, prioritize **NVIDIA** for this stack.
