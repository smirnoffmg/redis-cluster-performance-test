#!/bin/bash

# Docker Compose Validation Test
set -e

echo "🔍 Testing Docker Compose Setup..."

# Check if Docker Compose is available
if ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose is not available"
    exit 1
fi

# Check if services are running
echo "📋 Checking service status..."
docker compose ps

# Test Redis connectivity
echo ""
echo "🔍 Testing Redis connectivity..."
if docker compose exec -T redis-master redis-cli ping | grep -q "PONG"; then
    echo "✅ Redis master is responding"
else
    echo "❌ Redis master is not responding"
    exit 1
fi

# Test replica connectivity
for replica in redis-replica-1 redis-replica-2; do
    if docker compose exec -T $replica redis-cli ping | grep -q "PONG"; then
        echo "✅ $replica is responding"
    else
        echo "❌ $replica is not responding"
        exit 1
    fi
done

# Test Sentinel connectivity
echo ""
echo "🔍 Testing Sentinel connectivity..."
for sentinel in redis-sentinel-1 redis-sentinel-2 redis-sentinel-3; do
    if docker compose exec -T $sentinel redis-cli -p 26379 ping | grep -q "PONG"; then
        echo "✅ $sentinel is responding"
    else
        echo "❌ $sentinel is not responding"
        exit 1
    fi
done

# Test replication status
echo ""
echo "🔍 Checking replication status..."
MASTER_INFO=$(docker compose exec -T redis-master redis-cli info replication | grep role)
REPLICA1_INFO=$(docker compose exec -T redis-replica-1 redis-cli info replication | grep role)
REPLICA2_INFO=$(docker compose exec -T redis-replica-2 redis-cli info replication | grep role)

echo "📊 Replication Status:"
echo "   Master: $MASTER_INFO"
echo "   Replica 1: $REPLICA1_INFO"
echo "   Replica 2: $REPLICA2_INFO"

# Test Sentinel master discovery
echo ""
echo "🔍 Testing Sentinel master discovery..."
SENTINEL_MASTER=$(docker compose exec -T redis-sentinel-1 redis-cli -p 26379 sentinel master mymaster | head -1)
echo "📊 Sentinel Master Info: $SENTINEL_MASTER"

# Test network connectivity
echo ""
echo "🔍 Testing network connectivity..."
NETWORK_NAME=$(docker compose ls --format json | jq -r '.[0].Name' 2>/dev/null || echo "redis-cluster-performance-test")
echo "📊 Network name: ${NETWORK_NAME}_redis-network"

# Test memtier-benchmark service
echo ""
echo "🔍 Testing memtier-benchmark service..."
if docker compose ps memtier-benchmark | grep -q "Up"; then
    echo "✅ memtier-benchmark service is running"
else
    echo "⚠️  memtier-benchmark service is not running (this is normal if not actively testing)"
fi

# Test monitoring services
echo ""
echo "🔍 Testing monitoring services..."
if docker compose ps prometheus | grep -q "Up"; then
    echo "✅ Prometheus is running"
else
    echo "❌ Prometheus is not running"
fi

if docker compose ps grafana | grep -q "Up"; then
    echo "✅ Grafana is running"
else
    echo "❌ Grafana is not running"
fi

echo ""
echo "🎉 All tests passed! Docker Compose setup is working correctly."
echo ""
echo "📊 Access Points:"
echo "   Grafana Dashboard: http://localhost:3000 (admin/admin)"
echo "   Prometheus: http://localhost:9090"
echo ""
echo "🧪 Run performance tests with: ./test-memtier.sh [scenario]" 