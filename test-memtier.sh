#!/bin/bash

# Redis HA Performance Testing with memtier_benchmark
set -e

echo "🧪 Redis HA Performance Testing with memtier_benchmark"

# Check if infrastructure is running
if ! docker ps | grep -q redis-master; then
    echo "❌ Infrastructure is not running. Please run ./start.sh first."
    exit 1
fi

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
    
    # Run memtier_benchmark
    docker run --rm \
        --network redis-cluster-performance-test_redis-network \
        -v $(pwd)/results:/results \
        redislabs/memtier_benchmark:latest \
        --server=redis-master \
        --port=6379 \
        --protocol=redis \
        --threads=4 \
        --clients=8 \
        --requests=10000 \
        --key-pattern=R:R \
        --data-size=100 \
        --expiry-range=3600-3600 \
        --ratio=$ratio \
        --key-minimum=1 \
        --key-maximum=100000 \
        --out-file=/results/${scenario}-test-$(date +%Y%m%d-%H%M%S).txt \
        --json-out-file=/results/${scenario}-test-$(date +%Y%m%d-%H%M%S).json
    
    echo "✅ $scenario test completed"
}

# Show available scenarios
echo ""
echo "📋 Available Test Scenarios:"
echo "   1. baseline    - 50% reads, 50% writes"
echo "   2. read-heavy  - 80% reads, 20% writes"
echo "   3. write-heavy - 20% reads, 80% writes"
echo "   4. mixed       - 50% reads, 50% writes"
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

case $SCENARIO in
    "baseline")
        run_test "baseline" "Balanced workload" "1:1"
        ;;
    "read-heavy")
        run_test "read-heavy" "Read-intensive workload" "4:1"
        ;;
    "write-heavy")
        run_test "write-heavy" "Write-intensive workload" "1:4"
        ;;
    "mixed")
        run_test "mixed" "Mixed workload" "1:1"
        ;;
    "all")
        echo "🎯 Running all test scenarios..."
        run_test "baseline" "Balanced workload" "1:1"
        run_test "read-heavy" "Read-intensive workload" "4:1"
        run_test "write-heavy" "Write-intensive workload" "1:4"
        run_test "mixed" "Mixed workload" "1:1"
        echo ""
        echo "🎉 All tests completed!"
        ;;
    *)
        echo "❌ Unknown scenario: $SCENARIO"
        echo "Available scenarios: baseline, read-heavy, write-heavy, mixed, all"
        exit 1
        ;;
esac

echo ""
echo "📁 Results saved to ./results/"
echo "📊 View Grafana dashboard: http://localhost:3000 (admin/admin)" 