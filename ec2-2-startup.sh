
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
#cat mongo-keyfile from instance 1 and copy content to instance 2  and name as same ./mongo-setup/mongo-keyfile
chmod 400 ./mongo-setup/mongo-keyfile

# Shard 2 Configuration
cat > ./mongo-setup/mongod-shard2.conf <<'EOF'
systemLog:
  destination: file
  path: "/var/log/mongodb/shard2.log"
  logAppend: true
storage:
  dbPath: "/data/shard2"
net:
  bindIp: 0.0.0.0
  port: 27018
replication:
  replSetName: "shard2RS"
sharding:
  clusterRole: "shardsvr"
security:
  keyFile: /etc/mongo-keyfile
EOF
