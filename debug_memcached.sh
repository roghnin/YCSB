#/bin/bash

RECORD_COUNT=100000
OP_COUNT=200000
HOST="127.0.0.1"
KV_OPTION="-p fieldcount=10 -p fieldlength=10000"
# KV_OPTION="-p fieldcount=10 -p fieldlength=100"
CLIENT_COUNT=16

rm output.txt
./bin/ycsb load memcached -s -P workloads/workloada $KV_OPTION -p "memcached.hosts=$HOST" -p recordcount=$RECORD_COUNT -p threadcount=$CLIENT_COUNT >> output.txt
# ./bin/ycsb run memcached -s -P workloads/workload_100write $KV_OPTION -p "memcached.hosts=$HOST" -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT >> output.txt 
# ./bin/ycsb run memcached -s -P workloads/workload_50insert50delete $KV_OPTION -p "memcached.hosts=$HOST" -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT >> output.txt 
./bin/ycsb run memcached -s -P workloads/workload_25insert25delete25read25update $KV_OPTION -p "memcached.hosts=$HOST" -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT >> output.txt 
