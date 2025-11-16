# mongodbclustershivraj
MongoDB sharded cluster and replica set setup using Docker and manual server installation with full steps and config files.


# 🚀 Setting Up a MongoDB Sharded Cluster on AWS EC2

Welcome to this comprehensive guide on deploying a distributed MongoDB sharded cluster! This setup uses two AWS EC2 instances to create a scalable, high-performance database infrastructure. Let's get started! 🎯

## 📋 Prerequisites

Before diving in, here's what you'll need:

- **Two AWS EC2 instances** named `mongoinstance1` and `mongoinstance2` (I used `t3a.small` for both)
- **Public EIP** assigned to `mongoinstance1` for external access
- Basic understanding of AWS and Docker
- SSH access to both instances

## 🔧 Initial Setup on mongoinstance1

Let's begin by setting up your first instance. This will serve as the primary node for your configuration server and one of your shards.

### Step 1: Update System Packages

Start by updating your instance's package manager:

```bash
apt-get update
```

### Step 2: Install Docker

Docker will containerize our MongoDB components, making them easier to manage and isolate:

```bash
sudo apt-get install docker.io
```

### Step 3: Elevate to Root User

Switch to root mode for smoother command execution:

```bash
sudo su
```

### Step 4: Run the Startup Script

Execute the initialization script for your first instance:

```bash
bash ec2-1-startup.sh
```

## 🔧 Initial Setup on mongoinstance2

Now let's configure your second instance. Follow these steps in `mongoinstance2`:

### Step 1: Install Docker

Just like on the first instance:

```bash
sudo apt-get install docker.io
```

### Step 2: Switch to Root Mode

```bash
sudo su
```

### Step 3: Run the Instance 2 Startup Script

Execute the second startup script:

```bash
bash ec2-2-startup.sh
```

### ⚠️ Important: Handling the mongo-keyfile Issue

You may encounter an error like this:

```
chmod 400 ./mongo-setup/mongo-keyfile - File not found
```

This happens because the keyfile wasn't created yet. Here's how to fix it:

**On mongoinstance1**, locate the mongo-keyfile contents from your `./mongo-setup/` directory.

**On mongoinstance2**, copy the exact content of the mongo-keyfile to the same path and with the same name as mongoinstance1. Ensure the directory structure matches:

```
./mongo-setup/mongo-keyfile
```

Once copied, run the permission command again:

```bash
chmod 400 ./mongo-setup/mongo-keyfile
```

## ⚙️ Step 4: Start Config Server Container on mongoinstance1

Now we'll create the configuration server—the brain of our sharded cluster! 🧠

```bash
echo "🔧 Starting Config Server on port 27019..."

docker run -d \
  --name mongo-configsvr \
  --network mongo-cluster \
  -p 27019:27019 \
  -v $(pwd)/mongo-setup/mongod-configsvr.conf:/etc/mongod.conf \
  -v $(pwd)/mongo-setup/mongo-keyfile:/etc/mongo-keyfile \
  -v mongo-configdb:/data/configdb \
  -v mongo-configdb-log:/var/log/mongodb \
  mongo:7.0 \
  bash -c "chmod 600 /etc/mongo-keyfile && mongod --config /etc/mongod.conf"
```

> 📌 **Note:** This creates a container named `mongo-configsvr` running on port 27019.

## ✅ Step 5: Initialize Config Server Replica Set

Initialize the replica set for your configuration server:

```bash
echo "✅ Initializing Config Server Replica Set..."
docker exec mongo-configsvr mongosh --port 27019 <<'EOF'
rs.initiate({
  _id: "configRS",
  configsvr: true,
  members: [{ _id: 0, host: "10.0.1.10:27019" }]
})
EOF
```

🔴 **Important:** Replace `10.0.1.10` with your mongoinstance1's private IP address.

## 🔧 Step 6: Start Shard 1 Container (mongoinstance1)

Let's create the first shard—your data will be partitioned across shards for scalability! 📊

```bash
echo "🔧 Starting Shard 1 on port 27018..."
docker run -d \
  --name mongo-shard1 \
  --network mongo-cluster \
  -p 27018:27018 \
  -v $(pwd)/mongo-setup/mongod-shard1.conf:/etc/mongod.conf \
  -v $(pwd)/mongo-setup/mongo-keyfile:/etc/mongo-keyfile \
  -v mongo-shard1:/data/shard1 \
  -v mongo-shard1-log:/var/log/mongodb \
  mongo:7.0 \
  bash -c "chmod 600 /etc/mongo-keyfile && mongod --config /etc/mongod.conf"

sleep 5
echo "✅ Shard 1 started"
```

## ✅ Step 7: Initialize Shard 1 Replica Set

Set up the replica set for your first shard:

```bash
echo "✅ Initializing Shard 1 Replica Set..."
docker exec mongo-shard1 mongosh --port 27018 <<'EOF'
rs.initiate({
  _id: "shard1RS",
  members: [{ _id: 0, host: "10.0.1.10:27018" }]
})
EOF
```

🔴 **Important:** Replace `10.0.1.10` with your mongoinstance1's private IP address.

## 🔧 Step 8: Start Shard 2 Container on mongoinstance2

Time to create the second shard on your second instance! This distributes your data across two nodes. 🌐

```bash
echo "🔧 Starting Shard 2 on port 27020 (forwarded to 27018 in container)..."
docker run -d \
  --name mongo-shard2 \
  --network mongo-cluster \
  -p 27020:27018 \
  -v $(pwd)/mongo-setup/mongod-shard2.conf:/etc/mongod.conf \
  -v $(pwd)/mongo-setup/mongo-keyfile:/etc/mongo-keyfile \
  -v mongo-shard2:/data/shard2 \
  -v mongo-shard2-log:/var/log/mongodb \
  mongo:7.0 \
  bash -c "chmod 600 /etc/mongo-keyfile && mongod --config /etc/mongod.conf"
```

## ✅ Step 9: Initialize Shard 2 Replica Set

Initialize the replica set for your second shard:

```bash
echo "✅ Initializing Shard 2 Replica Set..."
docker exec mongo-shard2 mongosh --port 27018 <<'EOF'

rs.initiate({
  _id: "shard2RS",
  members: [{ _id: 0, host: "10.0.1.20:27018" }]
})
EOF
```

🔴 **Important:** Replace `10.0.1.20` with your mongoinstance2's private IP address.

## 🔀 Step 10: Start Mongos Router Container

The Mongos router is the gateway to your sharded cluster—it directs queries to the appropriate shards! 🎯

```bash
echo "🔧 Starting Mongos Router on port 27017..."
docker run -d \
  --name mongo-mongos \
  --network mongo-cluster \
  -p 27017:27017 \
  -v $(pwd)/mongo-setup/mongos.conf:/etc/mongos.conf \
  -v $(pwd)/mongo-setup/mongo-keyfile:/etc/mongo-keyfile \
  -v mongo-mongos-log:/var/log/mongodb \
  mongo:7.0 \
  bash -c "chmod 600 /etc/mongo-keyfile && mongos --config /etc/mongos.conf"

echo "✅ Mongos Router started"
```

## 📊 Step 11: Add Shards to Cluster

Now we'll register both shards with the cluster:

```bash
echo "📊 Adding Shards to Cluster..."
docker exec mongo-mongos mongosh --port 27017 

sh.addShard("shard1RS/10.0.1.10:27018")

sh.addShard("shard2RS/10.0.1.20:27018")
```

## 🔍 Step 12: Verify Cluster Status

Let's verify that everything is working correctly! ✨

```bash
echo "🔍 Verifying Cluster Status..."
docker exec mongo-mongos mongosh --port 27017 <<'EOF'
sh.status()
EOF
```

This command will display detailed information about your shards, replica sets, and overall cluster health.

## 🔐 Step 13: Create Root User and Enable Authentication

Secure your cluster by creating an admin user:

```bash
echo "🔐 Creating root user..."
docker exec mongo-mongos mongosh --port 27017 <<'EOF'
use admin
db.createUser({
  user: "admin",
  pwd: "StrongPass123",
  roles: [ { role: "root", db: "admin" } ]
})
EOF

sleep 2
```

⚠️ **Security Tip:** Change `StrongPass123` to a strong, unique password for production environments!

## 🔄 Step 14: Restart All Containers with Authentication Enforced

Finally, restart all containers to enforce authentication across your cluster:

**On mongoinstance1:**

```bash
echo "🔄 Restarting all containers with authentication..."
docker restart mongo-configsvr mongo-shard1 mongo-mongos
```

**On mongoinstance2:**

```bash
docker restart mongo-shard2
```

## 🎉 You're All Set!

Congratulations! Your MongoDB sharded cluster is now up and running! 🚀 You have successfully deployed a distributed database system with:

- ✅ Configuration server for cluster metadata
- ✅ Two data shards for horizontal scalability
- ✅ Mongos router for query distribution
- ✅ Authentication enabled for security
