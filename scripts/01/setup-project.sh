#!/bin/bash
# setup-project.sh - Create project directory structure

set -e

echo "Creating Neoverse Tutorial Project Structure..."

# Check if neoverse-tutorial directory exists and remove it
if [ -d "neoverse-tutorial" ]; then
    echo "Existing neoverse-tutorial directory found. Removing..."
    rm -rf neoverse-tutorial
fi

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
