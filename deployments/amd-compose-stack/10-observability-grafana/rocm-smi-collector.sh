#!/usr/bin/env bash
# =====================================================================
# ROCm SMI Textfile Collector for Node Exporter
# Runs on HOST via cron/systemd timer, writes Prometheus metrics
# to a textfile directory that node-exporter picks up.
# =====================================================================

OUTPUT_DIR="/var/lib/node_exporter/textfile_collector"
OUTPUT_FILE="${OUTPUT_DIR}/rocm_gpu.prom"
TMP_FILE="${OUTPUT_FILE}.tmp"

mkdir -p "$OUTPUT_DIR"

# Parse rocm-smi output
parse_gpu_metrics() {
    local gpu_id=0

    # Temperature
    local temp
    temp=$(rocm-smi --showtemp 2>/dev/null | grep -oP 'Temperature \(Sensor edge\) \(C\): \K[\d.]+' | head -1)

    # GPU utilization
    local util
    util=$(rocm-smi --showuse 2>/dev/null | grep -oP 'GPU use \(%\): \K[\d.]+' | head -1)

    # Power
    local power
    power=$(rocm-smi --showpower 2>/dev/null | grep -oP 'Current Socket Graphics Package Power \(W\): \K[\d.]+' | head -1)

    # VRAM
    local vram_used vram_total
    vram_info=$(rocm-smi --showmeminfo vram 2>/dev/null)
    vram_total=$(echo "$vram_info" | grep -oP 'VRAM Total Memory \(B\): \K\d+' | head -1)
    vram_used=$(echo "$vram_info" | grep -oP 'VRAM Total Used Memory \(B\): \K\d+' | head -1)

    # Convert VRAM from bytes to MB
    [ -n "$vram_total" ] && vram_total=$((vram_total / 1024 / 1024)) || vram_total=0
    [ -n "$vram_used" ] && vram_used=$((vram_used / 1024 / 1024)) || vram_used=0

    # Write Prometheus format
    cat > "$TMP_FILE" <<EOF
# HELP rocm_gpu_temperature_celsius GPU edge temperature in Celsius
# TYPE rocm_gpu_temperature_celsius gauge
rocm_gpu_temperature_celsius{gpu_id="${gpu_id}"} ${temp:-0}
# HELP rocm_gpu_utilization_percent GPU utilization percentage
# TYPE rocm_gpu_utilization_percent gauge
rocm_gpu_utilization_percent{gpu_id="${gpu_id}"} ${util:-0}
# HELP rocm_gpu_power_watts GPU power consumption in Watts
# TYPE rocm_gpu_power_watts gauge
rocm_gpu_power_watts{gpu_id="${gpu_id}"} ${power:-0}
# HELP rocm_gpu_vram_used_mb GPU VRAM used in MB
# TYPE rocm_gpu_vram_used_mb gauge
rocm_gpu_vram_used_mb{gpu_id="${gpu_id}"} ${vram_used}
# HELP rocm_gpu_vram_total_mb GPU VRAM total in MB
# TYPE rocm_gpu_vram_total_mb gauge
rocm_gpu_vram_total_mb{gpu_id="${gpu_id}"} ${vram_total}
EOF

    # Atomic move
    mv "$TMP_FILE" "$OUTPUT_FILE"
}

parse_gpu_metrics
