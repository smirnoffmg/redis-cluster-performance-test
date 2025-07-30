#!/bin/bash

# Redis HA Performance Testing with memtier_benchmark
set -e

# =============================================================================
# MEMTIER_BENCHMARK CONFIGURATION
# =============================================================================

# Connection Settings
MEMTIER_SERVER="redis-master"
MEMTIER_PORT="6379"
MEMTIER_PROTOCOL="redis"

# Performance Settings
MEMTIER_THREADS="4"
MEMTIER_CLIENTS="8"
MEMTIER_TEST_TIME="60"

# Data Settings
MEMTIER_KEY_PATTERN="R:R"
MEMTIER_DATA_SIZE="100"
MEMTIER_EXPIRY_RANGE="3600-3600"
MEMTIER_KEY_MIN="1"
MEMTIER_KEY_MAX="100000"

# Output Settings
MEMTIER_OUTPUT_DIR="/results"

# =============================================================================
# SCRIPT LOGIC
# =============================================================================

echo "🧪 Redis HA Performance Testing with memtier_benchmark"

# Check if Docker Compose services are running
if ! docker compose ps | grep -q "Up"; then
    echo "❌ Docker Compose services are not running. Please run 'docker compose up -d' first."
    exit 1
fi

# Get the project name for network reference
PROJECT_NAME=$(docker compose ls --format json | jq -r '.[0].Name' 2>/dev/null || echo "redis-cluster-performance-test")

# Function to run a test scenario
run_test() {
    local scenario=$1
    local description=$2
    local ratio=$3
    
    echo ""
    echo "🚀 Running $scenario test: $description"
    echo "📊 Read/Write ratio: $ratio"
    
    # Create results directory
    mkdir -p results
    
    # Run memtier_benchmark using Docker Compose exec
    docker compose exec -T memtier-benchmark memtier_benchmark \
        --server=$MEMTIER_SERVER \
        --port=$MEMTIER_PORT \
        --protocol=$MEMTIER_PROTOCOL \
        --threads=$MEMTIER_THREADS \
        --clients=$MEMTIER_CLIENTS \
        --test-time=$MEMTIER_TEST_TIME \
        --key-pattern=$MEMTIER_KEY_PATTERN \
        --data-size=$MEMTIER_DATA_SIZE \
        --expiry-range=$MEMTIER_EXPIRY_RANGE \
        --ratio=$ratio \
        --key-minimum=$MEMTIER_KEY_MIN \
        --key-maximum=$MEMTIER_KEY_MAX \
        --out-file=$MEMTIER_OUTPUT_DIR/${scenario}-test-$(date +%Y%m%d-%H%M%S).txt \
        --json-out-file=$MEMTIER_OUTPUT_DIR/${scenario}-test-$(date +%Y%m%d-%H%M%S).json
    
    echo "✅ $scenario test completed"
}

# Alternative function using docker run (fallback)
run_test_docker_run() {
    local scenario=$1
    local description=$2
    local ratio=$3
    
    echo ""
    echo "🚀 Running $scenario test: $description (using docker run)"
    echo "📊 Read/Write ratio: $ratio"
    
    # Create results directory
    mkdir -p results
    
    # Get the correct network name
    NETWORK_NAME="${PROJECT_NAME}_redis-network"
    
    # Run memtier_benchmark
    docker run --rm \
        --network $NETWORK_NAME \
        -v $(pwd)/results:/results \
        redislabs/memtier_benchmark:latest \
        --server=$MEMTIER_SERVER \
        --port=$MEMTIER_PORT \
        --protocol=$MEMTIER_PROTOCOL \
        --threads=$MEMTIER_THREADS \
        --clients=$MEMTIER_CLIENTS \
        --test-time=$MEMTIER_TEST_TIME \
        --key-pattern=$MEMTIER_KEY_PATTERN \
        --data-size=$MEMTIER_DATA_SIZE \
        --expiry-range=$MEMTIER_EXPIRY_RANGE \
        --ratio=$ratio \
        --key-minimum=$MEMTIER_KEY_MIN \
        --key-maximum=$MEMTIER_KEY_MAX \
        --out-file=$MEMTIER_OUTPUT_DIR/${scenario}-test-$(date +%Y%m%d-%H%M%S).txt \
        --json-out-file=$MEMTIER_OUTPUT_DIR/${scenario}-test-$(date +%Y%m%d-%H%M%S).json
    
    echo "✅ $scenario test completed"
}

# Show available scenarios
echo ""
echo "📋 Available Test Scenarios:"
echo "   1. baseline    - 50% reads, 50% writes"
echo "   2. read-heavy  - 80% reads, 20% writes"
echo "   3. write-heavy - 20% reads, 80% writes"
echo ""

# Check if scenario argument provided
if [ $# -eq 0 ]; then
    echo "💡 Usage: ./test-memtier.sh [scenario]"
    echo "   Example: ./test-memtier.sh baseline"
    echo ""
    echo "🎯 Quick test all scenarios: ./test-memtier.sh all"
    exit 0
fi

SCENARIO=$1

# Check if memtier-benchmark service is available in Docker Compose
if docker compose ps memtier-benchmark | grep -q "Up"; then
    echo "✅ Using Docker Compose memtier-benchmark service"
    RUN_FUNCTION="run_test"
else
    echo "⚠️  memtier-benchmark service not running, using docker run fallback"
    RUN_FUNCTION="run_test_docker_run"
fi

case $SCENARIO in
    "baseline")
        $RUN_FUNCTION "baseline" "Balanced workload" "1:1"
        ;;
    "read-heavy")
        $RUN_FUNCTION "read-heavy" "Read-intensive workload" "4:1"
        ;;
    "write-heavy")
        $RUN_FUNCTION "write-heavy" "Write-intensive workload" "1:4"
        ;;

    "all")
        echo "🎯 Running all test scenarios..."
        $RUN_FUNCTION "baseline" "Balanced workload" "1:1"
        $RUN_FUNCTION "read-heavy" "Read-intensive workload" "4:1"
        $RUN_FUNCTION "write-heavy" "Write-intensive workload" "1:4"
        echo ""
        echo "🎉 All tests completed!"
        ;;
    *)
        echo "❌ Unknown scenario: $SCENARIO"
        echo "Available scenarios: baseline, read-heavy, write-heavy, all"
        exit 1
        ;;
esac

echo ""
echo "📁 Results saved to ./results/"
echo "📊 View Grafana dashboard: http://localhost:3000 (admin/admin)" 