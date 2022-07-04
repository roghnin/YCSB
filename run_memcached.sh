#/bin/bash

# env options:
MONTAGE_DIR="../Montage"
MEMCACHED_DIR="../Montage/ext/memcached"
MEMCACHED_OPTIONS=(
    "montage_dram_payloads"
    "montage_kv_store"
    "montage_nvm_payloads"
    "montage_wt_cache"
    "montage_wb_cache"
    "master"
)
NVM_DIR="/mnt/pmem0"
CLIENT_COUNTS=(8 16 24 32 40)
RECORD_COUNT=10000000
OP_COUNT=10000000

# other envs:
YCSB_DIR=`pwd`
DATETIME=`date +"%m-%d-%y_%H-%M-%S"`
OUTPUT_DIR="$YCSB_DIR/results/$DATETIME"

MEMCACHED_DIR=`realpath $MEMCACHED_DIR`
MEMCACHED_HOST="memcached.hosts=127.0.0.1"

# traps to terminate background processes on sigint or error:
trap "exit" INT TERM ERR
trap "kill 0" EXIT

# global prep:
echo "compiling Montage"
mkdir -p $OUTPUT_DIR
cd $MONTAGE_DIR
make clean > /dev/null
make > /dev/null

for MEMCACHED_OPTION in ${MEMCACHED_OPTIONS[@]}; do
    OUTPUT_FILE=$OUTPUT_DIR/$MEMCACHED_OPTION.txt
    cd $MEMCACHED_DIR
    git checkout $MEMCACHED_OPTION
    echo "compiling Memcached"
    ./compile_montage.sh > /dev/null
    cd $YCSB_DIR
    for CLIENT_COUNT in ${CLIENT_COUNTS[@]}; do
        rm -rf $NVM_DIR/${USER}*
        echo "starting Memcached server"
        $MEMCACHED_DIR/memcached --memory-limit=4194304 &
        MEMCACHED_PID=$!

        echo "## client cnt: $CLIENT_COUNT" | tee -a $OUTPUT_FILE
        echo "# load data:" | tee -a $OUTPUT_FILE
        $YCSB_DIR/bin/ycsb load memcached -s -P $YCSB_DIR/workloads/workloada -p $MEMCACHED_HOST -p recordcount=$RECORD_COUNT -p threadcount=$CLIENT_COUNT 2>&1 | tee -a $OUTPUT_FILE
        echo "# YCSB-A:" | tee -a $OUTPUT_FILE
        $YCSB_DIR/bin/ycsb run memcached -s -P $YCSB_DIR/workloads/workloada -p $MEMCACHED_HOST -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT 2>&1 | tee -a $OUTPUT_FILE
        echo "# YCSB-B:" | tee -a $OUTPUT_FILE
        $YCSB_DIR/bin/ycsb run memcached -s -P $YCSB_DIR/workloads/workloadb -p $MEMCACHED_HOST -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT 2>&1 | tee -a $OUTPUT_FILE

        echo "killing Memcached server"
        kill -9 $MEMCACHED_PID
        sleep 3s
    done
done