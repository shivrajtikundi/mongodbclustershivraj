#!/bin/bash

# MongoDB Sharded Cluster Setup with Docker (No Docker Compose)
# This setup mirrors the blog exactly with 2 instances using Docker containers
# FIXED: Uses proper keyFile permissions and bash -c for config execution

set -e

echo "🚀 Starting MongoDB Sharded Cluster Setup with Docker"

# ==========================================
# Step 1: Create Docker Network
# ==========================================
echo "📡 Creating Docker network..."
docker network create mongo-cluster || echo "Network already exists"

# ==========================================
# Step 2: Create KeyFile for Internal Authentication
# ==========================================
echo "🔐 Creating KeyFile..."
mkdir -p ./mongo-setup/{configdb,shard1,shard2}
openssl rand -base64 756 > ./mongo-setup/mongo-keyfile
chmod 400 ./mongo-setup/mongo-keyfile

echo "✅ KeyFile created at ./mongo-setup/mongo-keyfile"

# ==========================================
# Step 3: Create Config Files
# ==========================================
echo "⚙️  Creating configuration files..."

# Config Server Configuration
cat > ./mongo-setup/mongod-configsvr.conf <<'EOF'
systemLog:
  destination: file
  path: "/var/log/mongodb/configsvr.log"
  logAppend: true
storage:
  dbPath: "/data/configdb"
net:
  bindIp: 0.0.0.0
  port: 27019
replication:
  replSetName: "configRS"
sharding:
  clusterRole: "configsvr"
security:
  keyFile: /etc/mongo-keyfile
EOF

# Shard 1 Configuration
cat > ./mongo-setup/mongod-shard1.conf <<'EOF'
systemLog:
  destination: file
  path: "/var/log/mongodb/shard1.log"
  logAppend: true
storage:
  dbPath: "/data/shard1"
net:
  bindIp: 0.0.0.0
  port: 27018
replication:
  replSetName: "shard1RS"
sharding:
  clusterRole: "shardsvr"
security:
  keyFile: /etc/mongo-keyfile
EOF

cat > ./mongo-setup/mongos.conf <<'EOF'
systemLog:
  destination: file
  path: "/var/log/mongodb/mongos.log"
  logAppend: true
net:
  bindIp: 0.0.0.0
  port: 27017
sharding:
  configDB: "configRS/mongo-configsvr:27019"
security:
  keyFile: /etc/mongo-keyfile
EOF

echo "✅ All config files created"
