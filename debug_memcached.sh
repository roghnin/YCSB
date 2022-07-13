#/bin/bash

RECORD_COUNT=10000
OP_COUNT=10000
HOST="node2x20a"

./bin/ycsb load memcached -s -P workloads/workloada -p "memcached.hosts=$HOST" -p recordcount=$RECORD_COUNT > output.txt
./bin/ycsb run memcached -s -P workloads/workloada -p "memcached.hosts=$HOST" -p operationcount=$OP_COUNT > output.txt 