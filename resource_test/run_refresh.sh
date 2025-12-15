#!/bin/bash
# Wrapper script to run Vivado file refresh with logs in logs directory

# Create logs directory if it doesn't exist
mkdir -p logs

# Get timestamp for log filenames
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Run Vivado from project root with logs redirected to logs directory
vivado -mode batch -source refresh_files.tcl -log logs/refresh_${TIMESTAMP}.log -journal logs/refresh_${TIMESTAMP}.jou

# Move any vivado_pid*.str files to logs directory
if ls vivado_pid*.str 1> /dev/null 2>&1; then
    mv vivado_pid*.str logs/
fi

echo "Refresh complete. Logs saved to logs/"
