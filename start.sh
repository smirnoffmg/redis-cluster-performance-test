#!/bin/bash

# Redis HA Performance Testing - Start Script
set -e

echo "🚀 Starting Redis HA Performance Testing Infrastructure..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Create results directory if it doesn't exist
mkdir -p results

# Start all services
echo "📦 Starting Docker Compose services..."
docker compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check Redis master
echo "🔍 Checking Redis master..."
if docker exec redis-master redis-cli ping >/dev/null 2>&1; then
    echo "✅ Redis master is ready"
else
    echo "❌ Redis master is not responding"
    exit 1
fi

# Check Redis replicas
echo "🔍 Checking Redis replicas..."
for replica in redis-replica-1 redis-replica-2; do
    if docker exec $replica redis-cli ping >/dev/null 2>&1; then
        echo "✅ $replica is ready"
    else
        echo "❌ $replica is not responding"
        exit 1
    fi
done

# Check Sentinels
echo "🔍 Checking Redis Sentinels..."
for sentinel in redis-sentinel-1 redis-sentinel-2 redis-sentinel-3; do
    if docker exec $sentinel redis-cli -p 26379 ping >/dev/null 2>&1; then
        echo "✅ $sentinel is ready"
    else
        echo "❌ $sentinel is not responding"
        exit 1
    fi
done

# Check replication status
echo "🔍 Checking replication status..."
MASTER_INFO=$(docker exec redis-master redis-cli info replication | grep role)
REPLICA1_INFO=$(docker exec redis-replica-1 redis-cli info replication | grep role)
REPLICA2_INFO=$(docker exec redis-replica-2 redis-cli info replication | grep role)

echo "📊 Replication Status:"
echo "   Master: $MASTER_INFO"
echo "   Replica 1: $REPLICA1_INFO"
echo "   Replica 2: $REPLICA2_INFO"

# Check Sentinel master info
echo "🔍 Checking Sentinel master discovery..."
SENTINEL_MASTER=$(docker exec redis-sentinel-1 redis-cli -p 26379 sentinel master mymaster | head -1)
echo "📊 Sentinel Master Info: $SENTINEL_MASTER"

echo ""
echo "🎉 Infrastructure is ready!"
echo ""
echo "📊 Access Points:"
echo "   Grafana Dashboard: http://localhost:3000 (admin/admin)"
echo "   Prometheus: http://localhost:9090"
echo ""
echo "🧪 Run tests with: ./test.sh"
echo "🛑 Stop with: docker compose down" 