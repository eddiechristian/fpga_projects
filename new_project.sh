#!/bin/sh
#
#
mkdir -p $1/src/hdl
mkdir -p $1/src/sim
mkdir -p $1/src/constraints
cp ./nexys_video.xdc $1/src/constraints/
cp ./default_create_project.tcl $1/create_project.tcl
cp ./default_top_module.vhd $1/src/hdl/top_module.vhd