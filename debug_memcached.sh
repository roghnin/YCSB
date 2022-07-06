#/bin/bash

./bin/ycsb load memcached -s -P workloads/workloada -p "memcached.hosts=127.0.0.1" > output.txt
./bin/ycsb run memcached -s -P workloads/workloada -p "memcached.hosts=127.0.0.1" > output.txt 