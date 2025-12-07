# MongoDB 7 Replica Set Setup with Docker: A Complete Guide

Setting up a MongoDB replica set can seem daunting, but with Docker and proper configuration, you can have a highly available database cluster running in minutes. This guide walks you through deploying a three-node MongoDB 7 replica set using Docker containers on Ubuntu servers.

## Why MongoDB Replica Sets?

Replica sets provide automatic failover and data redundancy. If your primary node goes down, one of the secondary nodes automatically becomes the new primary, ensuring zero downtime. This is essential for production environments where data availability is critical.

## Prerequisites

You'll need three Ubuntu servers with Docker installed. In our example, we're using:
- Primary: 10.15.140.62
- Secondary 1: 10.15.136.84
- Secondary 2: 10.15.137.94

## Step 1: Generate and Distribute the Keyfile

The keyfile is essential for securing communication between replica set members. Start by creating the setup directory on each server:

```bash
sudo mkdir -p /home/ubuntu/mongo-setup
cd /home/ubuntu/mongo-setup
```

Generate a secure keyfile:

```bash
openssl rand -base64 756 > mongo-keyfile
chmod 600 mongo-keyfile
```

Copy this keyfile to all three servers. The keyfile acts as a shared secret that allows nodes to authenticate with each other. Without it, your replica set won't be able to communicate securely.

## Step 2: Create MongoDB Configuration Files

Create individual configuration files for each node. The configuration is nearly identical across all nodes—only the filenames differ for organizational purposes.

### Primary Node Configuration

Save this as `mongod-primary.conf`:

```yaml
systemLog:
  destination: file
  path: "/var/log/mongodb/mongod.log"
  logAppend: true

storage:
  dbPath: "/data/db"

net:
  bindIp: 0.0.0.0
  port: 27017
  maxIncomingConnections: 64000

replication:
  replSetName: "rs0"

security:
  keyFile: /etc/mongo-keyfile

processManagement:
  fork: false

```

### Secondary Node Configurations

Save as `mongod-secondary1.conf` and `mongod-secondary2.conf` with the same content (you can copy and rename the primary config).

## Step 3: Create Docker Volumes

Before launching the containers, create the necessary Docker volumes that will persist your MongoDB data and logs across container restarts.

On the Primary server (10.15.140.62):

```bash
docker volume create mongo-primary-data
docker volume create mongo-primary-log
```

On Secondary 1 server (10.15.136.84):

```bash
docker volume create mongo-secondary-data
docker volume create mongo-secondary-log
```

On Secondary 2 server (10.15.137.94):

```bash
docker volume create mongo-secondary-data
docker volume create mongo-secondary-log
```

These volumes ensure that your database files and logs persist even if the containers are stopped or removed, which is critical for maintaining data integrity in a replica set.

## Step 4: Launch MongoDB Containers

### Start the Primary Node

```bash
docker run -d \
  --name mongo-primary \
  --ulimit nofile=64000:64000 \
  -p 27017:27017 \
  -v /home/ubuntu/mongo-setup/mongod-primary.conf:/etc/mongod.conf:ro \
  -v /home/ubuntu/mongo-setup/mongo-keyfile:/etc/mongo-keyfile:ro \
  -v mongo-primary-data:/data/db \
  -v mongo-primary-log:/var/log/mongodb \
  mongo:7.0 \
  bash -c "cp /etc/mongo-keyfile /tmp/key && chmod 600 /tmp/key && mongod --config /etc/mongod.conf --keyFile /tmp/key"
```

### Start the Secondary Nodes

On Secondary 1 (10.15.136.84):

```bash
docker run -d \
  --name mongo-secondary1 \
  --ulimit nofile=64000:64000 \
  -p 27017:27017 \
  -v /home/ubuntu/mongo-setup/mongod-secondary1.conf:/etc/mongod.conf:ro \
  -v /home/ubuntu/mongo-setup/mongo-keyfile:/etc/mongo-keyfile:ro \
  -v mongo-secondary-data:/data/db \
  -v mongo-secondary-log:/var/log/mongodb \
  mongo:7.0 \
  bash -c "cp /etc/mongo-keyfile /tmp/key && chmod 600 /tmp/key && mongod --config /etc/mongod.conf --keyFile /tmp/key"
```

On Secondary 2 (10.15.137.94):

```bash
docker run -d \
  --name mongo-tertiary \
  --ulimit nofile=64000:64000 \
  -p 27017:27017 \
  -v /home/ubuntu/mongo-setup/mongod-secondary2.conf:/etc/mongod.conf:ro \
  -v /home/ubuntu/mongo-setup/mongo-keyfile:/etc/mongo-keyfile:ro \
  -v mongo-secondary-data:/data/db \
  -v mongo-secondary-log:/var/log/mongodb \
  mongo:7.0 \
  bash -c "cp /etc/mongo-keyfile /tmp/key && chmod 600 /tmp/key && mongod --config /etc/mongod.conf --keyFile /tmp/key"
```

## Step 5: Initialize the Replica Set
restart all container

Connect to the primary node's MongoDB instance:

```bash
docker exec -it mongo-primary mongosh
```

Once inside the MongoDB shell, initialize the replica set with your node IPs and priorities:

```javascript
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "10.15.140.62:27017", priority: 2 },
    { _id: 1, host: "10.15.136.84:27017", priority: 1 }, 
    { _id: 2, host: "10.15.137.94:27017", priority: 0 }  
  ]
});
```

The priority values are important:
- Primary (priority: 2): Highest priority, will always be preferred as primary
- Secondary 1 (priority: 1): Medium priority, can become primary if needed
- Secondary 2 (priority: 0): Lowest priority, least likely to become primary

## Step 6: Create an Admin User

Still in the MongoDB shell, switch to the admin database and create a root user:

```javascript
use admin

db.createUser({
  user: "admin",
  pwd: "bIho",
  roles: [
    { role: "root", db: "admin" }
  ]
});
```

Replace "bIho" with a strong password of your choice. This user has root-level access to all databases.

## Verification

Check your replica set status:

```javascript
rs.status()
```
docker exec -it mongo-primary bash -c "ulimit -n"   
#check the new connection

You should see all three nodes listed with the primary showing `"stateStr": "PRIMARY"` and the secondaries showing `"stateStr": "SECONDARY"`.

## Key Takeaways

This setup provides a production-ready MongoDB replica set with automatic failover. The Docker containers handle all the complexity of running MongoDB, while the configuration files and keyfile ensure security and proper clustering behavior.

The beauty of this approach is reproducibility—you can now deploy this exact same setup across different environments with confidence. Docker volumes ensure data persistence, and the three-node configuration gives you both redundancy and fault tolerance.

Your MongoDB replica set is now ready for application connections!
