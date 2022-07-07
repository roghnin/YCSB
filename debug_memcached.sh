#/bin/bash

RECORD_COUNT=10000
OP_COUNT=10000

./bin/ycsb load memcached -s -P workloads/workloada -p "memcached.hosts=127.0.0.1" -p recordcount=$RECORD_COUNT > output.txt
./bin/ycsb run memcached -s -P workloads/workloada -p "memcached.hosts=127.0.0.1" -p operationcount=$OP_COUNT > output.txt 