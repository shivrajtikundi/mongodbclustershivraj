mongo 7 is only installable in ubuntu 20 and 22
🧩 Setting Up a Secure MongoDB Sharded Cluster on Two EC2 Instances (with Authentication)

In this guide, we’ll walk through how to set up a MongoDB sharded cluster using two Ubuntu EC2 instances — complete with config servers, shards, and a query router — all secured with authentication and keyFile-based internal security.

⚙️ Architecture Overview
Component	Instance	Port	Role
Config Server	Instance 1	27019	Stores cluster metadata
Shard 1	Instance 1	27018	First data shard
Mongos Router	Instance 1	27017	Query router for clients
Shard 2	Instance 2	27018	Second data shard
Authentication Setup

Root username: admin

Password: Your choice (example: StrongPass123)

Internal authentication: Enabled via a keyFile for secure communication between cluster members.

🪜 Step 1: Install MongoDB on Both Instances

Run the following commands on both instances to install MongoDB 7.0:

curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt update
sudo apt install -y mongodb-org

🪜 Step 2: Create KeyFile (for Secure Internal Authentication)

On Instance 1, create the keyFile:

openssl rand -base64 756 > /etc/mongo-keyfile
chmod 400 /etc/mongo-keyfile
sudo chown mongodb:mongodb /etc/mongo-keyfile


Now copy this file securely to Instance 2:

scp -i your-key.pem /etc/mongo-keyfile ubuntu@<INSTANCE2_IP>:/tmp/


Then on Instance 2, move and secure it:

sudo mv /tmp/mongo-keyfile /etc/mongo-keyfile
sudo chown mongodb:mongodb /etc/mongo-keyfile
sudo chmod 400 /etc/mongo-keyfile

🪜 Step 3: Configure the Config Server (Instance 1)

Create the directory and configuration file:

sudo mkdir -p /data/configdb
sudo nano /etc/mongod-configsvr.conf


Paste the following:

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


Start the Config Server:

mongod --config /etc/mongod-configsvr.conf --fork


Initialize the replica set:

mongosh --port 27019
rs.initiate({
  _id: "configRS",
  configsvr: true,
  members: [{ _id: 0, host: "<INSTANCE1_PRIVATE_IP>:27019" }]
})

🪜 Step 4: Configure Shard 1 (Instance 1)
sudo mkdir -p /data/shard1
sudo nano /etc/mongod-shard1.conf


Add:

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


Start and initialize:

mongod --config /etc/mongod-shard1.conf --fork
mongosh --port 27018
rs.initiate({
  _id: "shard1RS",
  members: [{ _id: 0, host: "<INSTANCE1_PRIVATE_IP>:27018" }]
})

🪜 Step 5: Configure Shard 2 (Instance 2)
sudo mkdir -p /data/shard2
sudo nano /etc/mongod-shard2.conf


Add:

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


Start and initialize:

mongod --config /etc/mongod-shard2.conf --fork
mongosh --port 27018
rs.initiate({
  _id: "shard2RS",
  members: [{ _id: 0, host: "<INSTANCE2_PRIVATE_IP>:27018" }]
})

🪜 Step 6: Configure the Mongos Router (Instance 1)
sudo nano /etc/mongos.conf


Paste:

systemLog:
  destination: file
  path: "/var/log/mongodb/mongos.log"
  logAppend: true
net:
  bindIp: 0.0.0.0
  port: 27017
sharding:
  configDB: "configRS/<INSTANCE1_PRIVATE_IP>:27019"
security:
  keyFile: /etc/mongo-keyfile


Start the router:

mongos --config /etc/mongos.conf --fork

🪜 Step 7: Add Shards to the Cluster

Connect to the router:

mongosh --port 27017


Then add the shards:

sh.addShard("shard1RS/<INSTANCE1_PRIVATE_IP>:27018")
sh.addShard("shard2RS/<INSTANCE2_PRIVATE_IP>:27018")


Verify the cluster status:

sh.status()

🪜 Step 8: Enable Authentication

Create the root user for cluster access:

mongosh --port 27017
use admin
db.createUser({
  user: "admin",
  pwd: "StrongPass123",
  roles: [ { role: "root", db: "admin" } ]
})

🪜 Step 9: Restart All Services with Authentication Enabled

Restart each service to enforce authentication:

sudo pkill mongod
sudo pkill mongos
mongod --config /etc/mongod-configsvr.conf --fork
mongod --config /etc/mongod-shard1.conf --fork
mongod --config /etc/mongod-shard2.conf --fork
mongos --config /etc/mongos.conf --fork

🪜 Step 10: Connect Securely to the Cluster

From now on, always connect with authentication:

mongosh -u admin -p StrongPass123 --authenticationDatabase admin --port 27017

# increase limits
3️⃣ Increase MongoDB Connections to ~64,000

MongoDB uses file descriptors for connections.

1. System limits

Edit:

sudo nano /etc/security/limits.conf


Add:

mongodb soft nofile 100000
mongodb hard nofile 100000

2. Kernel network tuning
sudo nano /etc/sysctl.conf


Add:

net.core.somaxconn = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1


Apply:

sudo sysctl -p

3. MongoDB config tuning
sudo nano /etc/mongod.conf


Ensure:

net:
  port: 27017
  bindIp: 0.0.0.0
  maxIncomingConnections: 64000


Restart MongoDB:

sudo systemctl restart mongod


Check limits:

cat /proc/$(pidof mongod)/limits | grep "Max open files"

4️⃣ Secure MongoDB (Recommended)
Enable authentication
mongosh

use admin
db.createUser({
  user: "admin",
  pwd: "StrongPassword@123",
  roles: [{ role: "root", db: "admin" }]
})


Edit config:

sudo nano /etc/mongod.conf


Enable:

security:
  authorization: enabled


Restart:

sudo systemctl restart mongod



#  shows limits
cat /proc/$(pidof mongod)/limits
systemctl show mongod | grep -E "LimitNOFILE|LimitNPROC"
