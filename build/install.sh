#!/bin/bash
# 
# Run this to install an application.
# This script should be run first, before
# all other...
#
hash julia 2>/dev/null || { printf >&2 "I require julia but it's not installed.  Aborting.\nYou should do the following:\n1. Download it here: http://julialang.org/downloads/\n2. Install it\n3. Add julia binnary to PATH variable, and store it into .bash_profile:\nPATH=\"/Applications/Julia-0.4.0.app/Contents/Resources/julia/bin/:\${PATH}\"\nexport PATH \n\nNote that path on your system could be different\n"; exit 1; }

julia --color=yes Dependencies.jl