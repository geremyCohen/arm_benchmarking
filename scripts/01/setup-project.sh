#!/bin/bash
# setup-project.sh - Create project directory structure

set -e

echo "Creating Neoverse Tutorial Project Structure..."

# Create main project directory
mkdir -p neoverse-tutorial
cd neoverse-tutorial

# Create source directories
mkdir -p src/{core,matrix,optimizations,benchmarks}
mkdir -p include/{core,matrix,optimizations}
mkdir -p data/{input,results}
mkdir -p scripts
mkdir -p docs

echo "Project structure created successfully!"
echo "Current directory: $(pwd)"
echo ""
echo "Directory structure:"
find . -type d | sort
echo ""
echo "Step 2 Complete: Project structure ready!"
echo "Proceed to Step 3: Hardware Detection"
