#!/bin/bash
# Wrapper script to run Vivado build with logs in logs directory

# Create logs directory if it doesn't exist
mkdir -p logs

# Get timestamp for log filenames
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Run Vivado with logs redirected to logs directory
cd logs
vivado -mode batch -source ../build.tcl -log build_${TIMESTAMP}.log -journal build_${TIMESTAMP}.jou
cd ..

# Move any vivado_pid*.str files to logs directory
if ls vivado_pid*.str 1> /dev/null 2>&1; then
    mv vivado_pid*.str logs/
fi

echo "Build complete. Logs saved to logs/"
