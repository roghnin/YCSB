#/bin/bash

# RECORD_COUNT=10000000
# OP_COUNT=20000000
# HOST="127.0.0.1"
# KV_OPTION="-p fieldcount=10 -p fieldlength=10"
# # KV_OPTION="-p fieldcount=10 -p fieldlength=100"
# CLIENT_COUNT=16

options="-p fieldcount=10 -p fieldlength=1000 -p recordcount=1000000 -p operationcount=2000000 -p threadcount=16 -p memcached.hosts=127.0.0.1"

rm output.txt
./bin/ycsb load memcached -s -P workloads/workloada $options >> output.txt
# ./bin/ycsb run memcached -s -P workloads/workload_100write $KV_OPTION -p "memcached.hosts=$HOST" -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT >> output.txt 
# ./bin/ycsb run memcached -s -P workloads/workload_50insert50delete $KV_OPTION -p "memcached.hosts=$HOST" -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT >> output.txt 
./bin/ycsb run memcached -s -P workloads/workload_25insert25delete25read25update $options >> output.txt 
