#!/bin/bash
#
# Power Analysis Script
# Provides detailed power draw analysis similar to manual diagnostics
#
# restore cpu performance echo 2200000 | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq > /dev/null
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Symbols
CHECK="✅"
WARN="⚠️"
CROSS="❌"
BOLT="⚡"
BATTERY="🔋"

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_section() {
    echo ""
    echo -e "${BOLD}${CYAN}─── $1 ───${NC}"
}

# Get battery info
get_battery_info() {
    print_header "${BATTERY} BATTERY STATUS"
    
    # Check if battery exists
    if [ ! -d /sys/class/power_supply/BAT0 ]; then
        echo -e "${RED}No battery found${NC}"
        return
    fi
    
    # Get upower info
    local state=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "state:" | awk '{print $2}')
    local percentage=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "percentage:" | awk '{print $2}')
    local energy_rate=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "energy-rate:" | awk '{print $2}')
    local energy=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "energy:" | head -1 | awk '{print $2}')
    local time_info=""
    
    if [ "$state" == "charging" ]; then
        time_info=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "time to full:" | cut -d: -f2-)
        state_color=$GREEN
        state_symbol=$CHECK
    elif [ "$state" == "discharging" ]; then
        time_info=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "time to empty:" | cut -d: -f2-)
        state_color=$YELLOW
        state_symbol=$WARN
    else
        state_color=$BLUE
        state_symbol=$CHECK
    fi
    
    # AC adapter status
    local ac_online=$(cat /sys/class/power_supply/ADP0/online 2>/dev/null)
    local ac_status="Disconnected"
    local ac_color=$RED
    if [ "$ac_online" == "1" ]; then
        ac_status="Connected"
        ac_color=$GREEN
    fi
    
    echo ""
    printf "  ${BOLD}%-20s${NC} ${state_color}%s %s${NC}\n" "State:" "$state_symbol" "$state"
    printf "  ${BOLD}%-20s${NC} %s\n" "Percentage:" "$percentage"
    printf "  ${BOLD}%-20s${NC} ${BOLD}%s W${NC}\n" "Power Rate:" "$energy_rate"
    printf "  ${BOLD}%-20s${NC} %s Wh\n" "Energy Remaining:" "$energy"
    if [ -n "$time_info" ]; then
        printf "  ${BOLD}%-20s${NC} %s\n" "Time Remaining:" "$time_info"
    fi
    printf "  ${BOLD}%-20s${NC} ${ac_color}%s${NC}\n" "AC Adapter:" "$ac_status"
    
    # Power assessment
    echo ""
    if [ -n "$energy_rate" ]; then
        local rate_int=${energy_rate%.*}
        if [ "$state" == "discharging" ]; then
            if [ "$rate_int" -lt 20 ]; then
                echo -e "  ${GREEN}${CHECK} Power draw is LOW (excellent for battery life)${NC}"
            elif [ "$rate_int" -lt 40 ]; then
                echo -e "  ${YELLOW}${WARN} Power draw is MODERATE${NC}"
            elif [ "$rate_int" -lt 60 ]; then
                echo -e "  ${YELLOW}${WARN} Power draw is HIGH${NC}"
            else
                echo -e "  ${RED}${CROSS} Power draw is VERY HIGH${NC}"
            fi
        fi
    fi
}

# Get CPU info
get_cpu_info() {
    print_header "${BOLT} CPU STATUS"
    
    # CPU model
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    local cpu_cores=$(grep -c "processor" /proc/cpuinfo)
    
    # Frequency info
    local max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
    local min_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq 2>/dev/null)
    local base_max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
    local avg_freq=$(grep "cpu MHz" /proc/cpuinfo | awk '{sum+=$4; count++} END {printf "%.0f", sum/count}')
    
    # Governor
    local governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    
    # Turbo boost
    local turbo_status="Enabled"
    local turbo_color=$GREEN
    local no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null)
    if [ "$no_turbo" == "1" ]; then
        turbo_status="Disabled"
        turbo_color=$YELLOW
    fi
    
    # Convert frequencies to MHz
    max_freq_mhz=$((max_freq / 1000))
    min_freq_mhz=$((min_freq / 1000))
    base_max_mhz=$((base_max / 1000))
    
    echo ""
    printf "  ${BOLD}%-20s${NC} %s\n" "Model:" "$cpu_model"
    printf "  ${BOLD}%-20s${NC} %s\n" "Cores/Threads:" "$cpu_cores"
    printf "  ${BOLD}%-20s${NC} %s MHz\n" "Current Avg Freq:" "$avg_freq"
    printf "  ${BOLD}%-20s${NC} %s MHz\n" "Current Max Cap:" "$max_freq_mhz"
    printf "  ${BOLD}%-20s${NC} %s - %s MHz\n" "Available Range:" "$min_freq_mhz" "$base_max_mhz"
    printf "  ${BOLD}%-20s${NC} %s\n" "Governor:" "$governor"
    printf "  ${BOLD}%-20s${NC} ${turbo_color}%s${NC}\n" "Turbo Boost:" "$turbo_status"
    
    # CPU capped warning
    if [ "$max_freq" -lt "$base_max" ]; then
        echo ""
        echo -e "  ${YELLOW}${WARN} CPU is capped at ${max_freq_mhz} MHz (max: ${base_max_mhz} MHz)${NC}"
    fi
}

# Get GPU info
get_gpu_info() {
    print_header "🎮 GPU STATUS"
    
    # List GPUs
    echo ""
    echo -e "  ${BOLD}Detected GPUs:${NC}"
    lspci | grep -iE "vga|3d|display" | while read -r line; do
        echo "    • $line"
    done
    
    # NVIDIA GPU
    if command -v nvidia-smi &> /dev/null; then
        echo ""
        echo -e "  ${BOLD}NVIDIA GPU:${NC}"
        local nvidia_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null)
        local nvidia_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null)
        local nvidia_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null)
        local nvidia_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null)
        
        if [ -n "$nvidia_power" ]; then
            printf "    ${BOLD}%-16s${NC} %s\n" "Name:" "$nvidia_name"
            printf "    ${BOLD}%-16s${NC} %.2f W\n" "Power Draw:" "$nvidia_power"
            printf "    ${BOLD}%-16s${NC} %s°C\n" "Temperature:" "$nvidia_temp"
            printf "    ${BOLD}%-16s${NC} %s%%\n" "Utilization:" "$nvidia_util"
            
            # Runtime status
            local runtime=$(cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status 2>/dev/null)
            if [ -n "$runtime" ]; then
                printf "    ${BOLD}%-16s${NC} %s\n" "Runtime Status:" "$runtime"
            fi
        fi
    fi
}

# Get top processes by CPU usage with power estimates
get_top_processes() {
    print_header "📊 TOP POWER CONSUMERS (by CPU %)"
    
    # Get total system power for estimation
    local total_power=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "energy-rate:" | awk '{print $2}')
    total_power=${total_power:-50}  # Default to 50W if not available
    
    echo ""
    printf "  ${BOLD}%-8s %-6s %-8s %-8s %s${NC}\n" "PID" "CPU%" "EST.PWR" "MEM%" "PROCESS"
    echo "  ─────────────────────────────────────────────────────────────"
    
    # Get top 12 CPU processes (excluding this script)
    ps aux --sort=-%cpu | grep -v "ps aux" | grep -v "power-analysis" | head -13 | tail -12 | while read -r line; do
        local user=$(echo "$line" | awk '{print $1}')
        local pid=$(echo "$line" | awk '{print $2}')
        local cpu=$(echo "$line" | awk '{print $3}')
        local mem=$(echo "$line" | awk '{print $4}')
        local cmd=$(echo "$line" | awk '{print $11}' | xargs basename 2>/dev/null || echo "$line" | awk '{print $11}')
        
        # Truncate command name
        cmd=${cmd:0:30}
        
        # Estimate power (rough: CPU% * total_power / 100, with some base overhead)
        # This is a rough estimate - actual power varies by workload type
        local est_power=$(echo "$cpu $total_power" | awk '{printf "%.1f", ($1/100) * $2 * 0.7}')
        
        # Color based on CPU usage
        local color=$NC
        local cpu_int=${cpu%.*}
        if [ "$cpu_int" -gt 20 ]; then
            color=$RED
        elif [ "$cpu_int" -gt 10 ]; then
            color=$YELLOW
        elif [ "$cpu_int" -gt 5 ]; then
            color=$CYAN
        fi
        
        printf "  ${color}%-8s %-6s %-8s %-8s %s${NC}\n" "$pid" "${cpu}%" "${est_power}W" "${mem}%" "$cmd"
    done
    
    echo ""
    echo -e "  ${BOLD}Note:${NC} Power estimates are approximate (based on CPU% × system power)"
}

# Get process groups (aggregate by app)
get_process_groups() {
    print_section "Application Power Summary"
    
    local total_power=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "energy-rate:" | awk '{print $2}')
    total_power=${total_power:-50}
    
    echo ""
    printf "  ${BOLD}%-25s %-10s %-10s %-8s${NC}\n" "APPLICATION" "PROCESSES" "TOTAL CPU%" "EST.PWR"
    echo "  ─────────────────────────────────────────────────────────────"
    
    # Cursor/VS Code
    local cursor_cpu=$(ps aux | grep -i cursor | grep -v grep | awk '{sum += $3} END {print sum}')
    local cursor_count=$(ps aux | grep -i cursor | grep -v grep | wc -l)
    if [ -n "$cursor_cpu" ] && [ "$cursor_count" -gt 0 ]; then
        local cursor_power=$(echo "$cursor_cpu $total_power" | awk '{printf "%.1f", ($1/100) * $2 * 0.7}')
        printf "  ${YELLOW}%-25s %-10s %-10s %-8s${NC}\n" "Cursor IDE" "$cursor_count" "${cursor_cpu}%" "${cursor_power}W"
    fi
    
    # Firefox
    local firefox_cpu=$(ps aux | grep -i firefox | grep -v grep | awk '{sum += $3} END {print sum}')
    local firefox_count=$(ps aux | grep -i firefox | grep -v grep | wc -l)
    if [ -n "$firefox_cpu" ] && [ "$firefox_count" -gt 0 ]; then
        local firefox_power=$(echo "$firefox_cpu $total_power" | awk '{printf "%.1f", ($1/100) * $2 * 0.7}')
        printf "  ${YELLOW}%-25s %-10s %-10s %-8s${NC}\n" "Firefox" "$firefox_count" "${firefox_cpu}%" "${firefox_power}W"
    fi
    
    # Chrome/Chromium
    local chrome_cpu=$(ps aux | grep -iE "chrome|chromium" | grep -v grep | awk '{sum += $3} END {print sum}')
    local chrome_count=$(ps aux | grep -iE "chrome|chromium" | grep -v grep | wc -l)
    if [ -n "$chrome_cpu" ] && [ "$chrome_count" -gt 0 ]; then
        local chrome_power=$(echo "$chrome_cpu $total_power" | awk '{printf "%.1f", ($1/100) * $2 * 0.7}')
        printf "  ${YELLOW}%-25s %-10s %-10s %-8s${NC}\n" "Chrome/Chromium" "$chrome_count" "${chrome_cpu}%" "${chrome_power}W"
    fi
    
    # KDE Plasma
    local kde_cpu=$(ps aux | grep -iE "plasma|kwin|plasmashell" | grep -v grep | awk '{sum += $3} END {print sum}')
    local kde_count=$(ps aux | grep -iE "plasma|kwin|plasmashell" | grep -v grep | wc -l)
    if [ -n "$kde_cpu" ] && [ "$kde_count" -gt 0 ]; then
        local kde_power=$(echo "$kde_cpu $total_power" | awk '{printf "%.1f", ($1/100) * $2 * 0.7}')
        printf "  ${CYAN}%-25s %-10s %-10s %-8s${NC}\n" "KDE Plasma Desktop" "$kde_count" "${kde_cpu}%" "${kde_power}W"
    fi
    
    # Docker
    local docker_cpu=$(ps aux | grep -iE "docker|containerd" | grep -v grep | awk '{sum += $3} END {print sum}')
    local docker_count=$(ps aux | grep -iE "docker|containerd" | grep -v grep | wc -l)
    if [ -n "$docker_cpu" ] && [ "$docker_count" -gt 0 ]; then
        local docker_power=$(echo "$docker_cpu $total_power" | awk '{printf "%.1f", ($1/100) * $2 * 0.7}')
        printf "  %-25s %-10s %-10s %-8s\n" "Docker/Containers" "$docker_count" "${docker_cpu}%" "${docker_power}W"
    fi
}

# Hardware status
get_hardware_status() {
    print_header "🔌 HARDWARE & RADIOS"
    
    echo ""
    
    # Bluetooth
    local bt_status="Unknown"
    local bt_color=$NC
    if command -v bluetoothctl &> /dev/null; then
        local bt_powered=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')
        if [ "$bt_powered" == "yes" ]; then
            bt_status="ON"
            bt_color=$YELLOW
        else
            bt_status="OFF"
            bt_color=$GREEN
        fi
    fi
    printf "  ${BOLD}%-20s${NC} ${bt_color}%s${NC}\n" "Bluetooth:" "$bt_status"
    
    # WiFi
    local wifi_status="Unknown"
    if [ -d /sys/class/net/wlan0 ] || [ -d /sys/class/net/wlp* ]; then
        wifi_status="Present"
    fi
    printf "  ${BOLD}%-20s${NC} %s\n" "WiFi:" "$wifi_status"
    
    # Display brightness
    local brightness=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1)
    local max_brightness=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1)
    if [ -n "$brightness" ] && [ -n "$max_brightness" ]; then
        local brightness_pct=$((brightness * 100 / max_brightness))
        local bright_color=$GREEN
        if [ "$brightness_pct" -gt 70 ]; then
            bright_color=$YELLOW
        fi
        printf "  ${BOLD}%-20s${NC} ${bright_color}%s%% (%s/%s)${NC}\n" "Display Brightness:" "$brightness_pct" "$brightness" "$max_brightness"
    fi
}

# Power saving tips based on current state
get_recommendations() {
    print_header "💡 RECOMMENDATIONS"
    
    echo ""
    
    local state=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "state:" | awk '{print $2}')
    local energy_rate=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "energy-rate:" | awk '{print $2}')
    local rate_int=${energy_rate%.*}
    
    if [ "$state" == "discharging" ]; then
        # Check CPU cap
        local max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
        local base_max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
        if [ "$max_freq" == "$base_max" ]; then
            echo -e "  • ${YELLOW}Cap CPU frequency:${NC} echo 1200000 | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq"
        fi
        
        # Check turbo
        local no_turbo=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null)
        if [ "$no_turbo" == "0" ]; then
            echo -e "  • ${YELLOW}Disable turbo boost:${NC} echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo"
        fi
        
        # Check Bluetooth
        local bt_powered=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')
        if [ "$bt_powered" == "yes" ]; then
            echo -e "  • ${YELLOW}Turn off Bluetooth:${NC} bluetoothctl power off"
        fi
        
        # Check for heavy apps
        local cursor_cpu=$(ps aux | grep -i cursor | grep -v grep | awk '{sum += $3} END {print sum}')
        if [ -n "$cursor_cpu" ] && [ "${cursor_cpu%.*}" -gt 50 ]; then
            echo -e "  • ${YELLOW}Cursor IDE is using significant CPU${NC} - consider closing if not needed"
        fi
        
        local firefox_cpu=$(ps aux | grep -i firefox | grep -v grep | awk '{sum += $3} END {print sum}')
        if [ -n "$firefox_cpu" ] && [ "${firefox_cpu%.*}" -gt 30 ]; then
            echo -e "  • ${YELLOW}Firefox is using significant CPU${NC} - close unused tabs"
        fi
        
        if [ "$rate_int" -lt 25 ]; then
            echo -e "  • ${GREEN}Power usage is already well optimized!${NC}"
        fi
    else
        echo -e "  • ${GREEN}Currently charging - no power saving needed${NC}"
    fi
}

# Total power summary at end
get_total_power_summary() {
    print_header "⚡ TOTAL POWER DRAW SUMMARY"
    
    # Get battery power rate
    local energy_rate=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "energy-rate:" | awk '{print $2}')
    energy_rate=${energy_rate:-0}
    
    # Get NVIDIA GPU power
    local gpu_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null)
    gpu_power=${gpu_power:-0}
    
    # Get state
    local state=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "state:" | awk '{print $2}')
    
    # Calculate estimated component breakdown
    local cursor_cpu=$(ps aux | grep -i cursor | grep -v grep | awk '{sum += $3} END {print sum+0}')
    local firefox_cpu=$(ps aux | grep -i firefox | grep -v grep | awk '{sum += $3} END {print sum+0}')
    local kde_cpu=$(ps aux | grep -iE "plasma|kwin|plasmashell|Xwayland" | grep -v grep | awk '{sum += $3} END {print sum+0}')
    local other_cpu=$(ps aux --sort=-%cpu | head -20 | grep -viE "cursor|firefox|plasma|kwin|plasmashell|Xwayland|ps aux" | awk '{sum += $3} END {print sum+0}')
    
    # Estimate power per component (rough calculation)
    local base_power=8  # Base system power (memory, storage, display, etc.)
    local cpu_power_factor=0.25  # Watts per CPU% (conservative estimate)
    
    local cursor_power=$(echo "$cursor_cpu $cpu_power_factor" | awk '{printf "%.1f", $1 * $2}')
    local firefox_power=$(echo "$firefox_cpu $cpu_power_factor" | awk '{printf "%.1f", $1 * $2}')
    local kde_power=$(echo "$kde_cpu $cpu_power_factor" | awk '{printf "%.1f", $1 * $2}')
    local other_power=$(echo "$other_cpu $cpu_power_factor" | awk '{printf "%.1f", $1 * $2}')
    
    echo ""
    echo -e "  ${BOLD}Component Breakdown (Estimated):${NC}"
    echo "  ─────────────────────────────────────────────────────────────"
    printf "  ${BOLD}%-30s${NC} %s\n" "Base System (display, RAM, SSD):" "~${base_power}W"
    printf "  ${BOLD}%-30s${NC} %s\n" "NVIDIA GPU:" "${gpu_power}W"
    
    if [ "${cursor_cpu%.*}" -gt 0 ]; then
        printf "  ${YELLOW}%-30s${NC} ${YELLOW}~%sW${NC} (${cursor_cpu}%% CPU)\n" "Cursor IDE:" "$cursor_power"
    fi
    if [ "${firefox_cpu%.*}" -gt 0 ]; then
        printf "  ${YELLOW}%-30s${NC} ${YELLOW}~%sW${NC} (${firefox_cpu}%% CPU)\n" "Firefox:" "$firefox_power"
    fi
    if [ "${kde_cpu%.*}" -gt 0 ]; then
        printf "  ${CYAN}%-30s${NC} ${CYAN}~%sW${NC} (${kde_cpu}%% CPU)\n" "KDE Desktop:" "$kde_power"
    fi
    if [ "${other_cpu%.*}" -gt 5 ]; then
        printf "  %-30s ~%sW (%s%% CPU)\n" "Other Processes:" "$other_power" "$other_cpu"
    fi
    
    echo "  ─────────────────────────────────────────────────────────────"
    
    # Calculate estimated system power draw from components
    local est_system_power=$(echo "$cursor_power $firefox_power $kde_power $other_power $base_power $gpu_power" | awk '{printf "%.1f", $1 + $2 + $3 + $4 + $5 + $6}')
    
    # Big total power display
    echo ""
    if [ "$state" == "charging" ]; then
        echo -e "  ${BOLD}${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
        printf "  ${BOLD}${GREEN}║  ⚡ CHARGING RATE:        %-10s                 ║${NC}\n" "${energy_rate} W"
        printf "  ${BOLD}${GREEN}║  💻 SYSTEM POWER DRAW:    ~%-10s (estimated)   ║${NC}\n" "${est_system_power} W"
        echo -e "  ${BOLD}${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    elif [ "$state" == "discharging" ]; then
        local rate_int=${energy_rate%.*}
        local color=$GREEN
        if [ "$rate_int" -gt 50 ]; then
            color=$RED
        elif [ "$rate_int" -gt 30 ]; then
            color=$YELLOW
        fi
        echo -e "  ${BOLD}${color}╔═══════════════════════════════════════════════════════╗${NC}"
        printf "  ${BOLD}${color}║  🔋 TOTAL POWER DRAW:     %-10s                 ║${NC}\n" "${energy_rate} W"
        echo -e "  ${BOLD}${color}╚═══════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "  ${BOLD}${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
        printf "  ${BOLD}${BLUE}║  🔌 POWER RATE:           %-10s                 ║${NC}\n" "${energy_rate} W"
        printf "  ${BOLD}${BLUE}║  💻 SYSTEM POWER DRAW:    ~%-10s (estimated)   ║${NC}\n" "${est_system_power} W"
        echo -e "  ${BOLD}${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
    fi
}

# Battery status (moved to end)
get_battery_status_end() {
    print_header "${BATTERY} BATTERY STATUS"
    
    # Check if battery exists
    if [ ! -d /sys/class/power_supply/BAT0 ]; then
        echo -e "${RED}No battery found${NC}"
        return
    fi
    
    # Get upower info
    local state=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "state:" | awk '{print $2}')
    local percentage=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "percentage:" | awk '{print $2}')
    local energy_rate=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "energy-rate:" | awk '{print $2}')
    local energy=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "energy:" | head -1 | awk '{print $2}')
    local energy_full=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "energy-full:" | awk '{print $2}')
    local time_info=""
    
    if [ "$state" == "charging" ]; then
        time_info=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "time to full:" | cut -d: -f2-)
        state_color=$GREEN
        state_symbol=$CHECK
    elif [ "$state" == "discharging" ]; then
        time_info=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "time to empty:" | cut -d: -f2-)
        state_color=$YELLOW
        state_symbol=$WARN
    else
        state_color=$BLUE
        state_symbol=$CHECK
    fi
    
    # AC adapter status
    local ac_online=$(cat /sys/class/power_supply/ADP0/online 2>/dev/null)
    local ac_status="Disconnected"
    local ac_color=$RED
    if [ "$ac_online" == "1" ]; then
        ac_status="Connected"
        ac_color=$GREEN
    fi
    
    echo ""
    printf "  ${BOLD}%-20s${NC} ${state_color}%s %s${NC}\n" "State:" "$state_symbol" "$state"
    printf "  ${BOLD}%-20s${NC} ${BOLD}%s${NC}\n" "Percentage:" "$percentage"
    printf "  ${BOLD}%-20s${NC} %s / %s Wh\n" "Energy:" "$energy" "$energy_full"
    printf "  ${BOLD}%-20s${NC} ${BOLD}%s W${NC}\n" "Power Rate:" "$energy_rate"
    if [ -n "$time_info" ]; then
        if [ "$state" == "charging" ]; then
            printf "  ${BOLD}%-20s${NC} ${GREEN}%s${NC}\n" "Time to Full:" "$time_info"
        else
            printf "  ${BOLD}%-20s${NC} ${YELLOW}%s${NC}\n" "Time to Empty:" "$time_info"
        fi
    fi
    printf "  ${BOLD}%-20s${NC} ${ac_color}%s${NC}\n" "AC Adapter:" "$ac_status"
    
    # Visual battery bar
    local pct_num=${percentage%\%}
    local bar_length=30
    local filled=$((pct_num * bar_length / 100))
    local empty=$((bar_length - filled))
    local bar_color=$GREEN
    if [ "$pct_num" -lt 20 ]; then
        bar_color=$RED
    elif [ "$pct_num" -lt 50 ]; then
        bar_color=$YELLOW
    fi
    
    echo ""
    printf "  ${BOLD}Battery:${NC} ${bar_color}["
    for ((i=0; i<filled; i++)); do printf "#"; done
    for ((i=0; i<empty; i++)); do printf "-"; done
    printf "]${NC} %s\n" "$percentage"
}

# Main execution
main() {
    clear
    echo -e "${BOLD}${GREEN}"
    echo "  ╔═══════════════════════════════════════════════════════════════╗"
    echo "  ║              LINUX LAPTOP POWER ANALYSIS                      ║"
    echo "  ║                    $(date '+%Y-%m-%d %H:%M:%S')                       ║"
    echo "  ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    get_cpu_info
    get_gpu_info
    get_top_processes
    get_process_groups
    get_hardware_status
    get_recommendations
    get_total_power_summary
    get_battery_status_end
    
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  Run again: ${CYAN}~/Documents/public_github/closed_source-linux_fixes/bash/power-analysis.sh${NC}"
    echo -e "  Watch mode: ${CYAN}watch -n 5 ~/Documents/public_github/closed_source-linux_fixes/bash/power-analysis.sh${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

main "$@"

