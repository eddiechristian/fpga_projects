#!/bin/bash
# Wrapper script to run Vivado GUI with logs in logs directory

# Create logs directory if it doesn't exist
mkdir -p logs

# Get timestamp for log filenames
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Run Vivado GUI with logs redirected to logs directory
# The GUI will stay open, so we run it in the background and monitor for log files
cd logs
vivado -mode gui build/sss.xpr -log gui_${TIMESTAMP}.log -journal gui_${TIMESTAMP}.jou &
VIVADO_PID=$!
cd ..

echo "Vivado GUI started (PID: $VIVADO_PID)"
echo "Logs will be saved to logs/"

# Wait a moment for Vivado to start
sleep 2

# Monitor and move .str files while Vivado is running
while kill -0 $VIVADO_PID 2>/dev/null; do
    # Check every 5 seconds for new .str files and move them
    if ls vivado_pid*.str 1> /dev/null 2>&1; then
        mv vivado_pid*.str logs/ 2>/dev/null
    fi
    sleep 5
done

# Final cleanup after Vivado closes
if ls vivado_pid*.str 1> /dev/null 2>&1; then
    mv vivado_pid*.str logs/ 2>/dev/null
fi

echo "Vivado GUI closed. All logs saved to logs/"
