#!/bin/bash

# VPR Installation Script for Debian-Based Systems
# Handles missing dependencies and submodules for successful VPR build.

set -e  # Exit on error

# Function to handle errors
error_exit() {
    echo "Error: $1"
    exit 1
}

# Variables
INSTALL_DIR="$HOME/vtr-verilog-to-routing"
BUILD_DIR="$INSTALL_DIR/build"
TEST_DIR="$HOME/vpr_test"
ARCH_FILE="k6_N10_40nm.xml"
CIRCUIT_FILE="alu4.blif"

# Ensure the script is not run as root
if [ "$EUID" -eq 0 ]; then
    echo "Please do not run this script as root. Use sudo only where necessary."
    exit 1
fi

# Step 1: Update and Install Dependencies
echo "Updating system and installing dependencies..."
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y \
    build-essential \
    cmake \
    libtbb-dev \
    libx11-dev \
    python3-dev \
    python3-pip \
    bison \
    flex \
    zlib1g-dev \
    libssl-dev \
    libsdl2-dev \
    libeigen3-dev \
    git || error_exit "Failed to install dependencies."

# Install Catch2 and sockpp manually if not found
if [ ! -d "$INSTALL_DIR/libs/EXTERNAL/libcatch2" ]; then
    echo "Cloning Catch2..."
    git clone https://github.com/catchorg/Catch2.git "$INSTALL_DIR/libs/EXTERNAL/libcatch2" || error_exit "Failed to clone Catch2."
fi

if [ ! -d "$INSTALL_DIR/libs/EXTERNAL/sockpp" ]; then
    echo "Cloning sockpp..."
    git clone https://github.com/fpagliughi/sockpp.git "$INSTALL_DIR/libs/EXTERNAL/sockpp" || error_exit "Failed to clone sockpp."
fi

# Step 2: Clone VTR Repository
echo "Cloning VTR repository..."
if [ ! -d "$INSTALL_DIR" ]; then
    git clone https://github.com/verilog-to-routing/vtr-verilog-to-routing.git "$INSTALL_DIR" || error_exit "Failed to clone VTR repository."
else
    echo "VTR repository already exists at $INSTALL_DIR. Skipping clone."
fi

# Step 3: Initialize and Update Submodules
echo "Initializing and updating submodules..."
cd "$INSTALL_DIR"
git submodule update --init --recursive || error_exit "Failed to update submodules."

# Step 4: Build VPR
echo "Building VPR..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
rm -rf *  # Clear any previous build artifacts
cmake .. -DCMAKE_BUILD_TYPE=Release || error_exit "CMake configuration failed."
make -j$(nproc) || error_exit "VPR build failed."

# Step 5: Add VPR to PATH
echo "Adding VPR to PATH..."
if ! grep -q "$INSTALL_DIR/build" ~/.bashrc; then
    echo "export PATH=$INSTALL_DIR/build:\$PATH" >> ~/.bashrc
    source ~/.bashrc
fi

# Step 6: Verify Installation
echo "Verifying VPR installation..."
source ~/.bashrc
vpr --version || error_exit "VPR installation verification failed."

# Step 7: Set Up Test Directory
echo "Setting up test directory..."
mkdir -p "$TEST_DIR"
cp "$INSTALL_DIR/vtr_flow/arch/timing/$ARCH_FILE" "$TEST_DIR" || error_exit "Failed to copy architecture file."
cp "$INSTALL_DIR/vtr_flow/benchmarks/blif/6/$CIRCUIT_FILE" "$TEST_DIR" || error_exit "Failed to copy benchmark file."

# Verify that the files were copied successfully
if [ ! -f "$TEST_DIR/$ARCH_FILE" ]; then
    error_exit "Architecture file $ARCH_FILE not found in $TEST_DIR."
fi

if [ ! -f "$TEST_DIR/$CIRCUIT_FILE" ]; then
    error_exit "Circuit file $CIRCUIT_FILE not found in $TEST_DIR."
fi

# Step 8: Run Basic Test Workflow
echo "Running VPR test workflow..."
cd "$TEST_DIR"
vpr "$TEST_DIR/$ARCH_FILE" "$TEST_DIR/$CIRCUIT_FILE" || error_exit "VPR test workflow failed."

# Completion Message
echo "VPR installation and setup completed successfully!"
echo "Test files are located in $TEST_DIR."
echo "You can run VPR using the command: vpr $TEST_DIR/$ARCH_FILE $TEST_DIR/$CIRCUIT_FILE"

