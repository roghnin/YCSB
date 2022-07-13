#/bin/bash

# remote or local
CONNECTION=remote

# env options:
MONTAGE_DIR=`realpath ../Montage`
MEMCACHED_DIR=`realpath ../Montage/ext/memcached`
MEMCACHED_OPTIONS=(
    "montage_dram_payloads"
    "montage_kv_store"
    "montage_nvm_payloads"
    "montage_wt_cache"
    "montage_wb_cache"
    "master"
)
NVM_DIR="/mnt/pmem0"
MEMCACHED_HOST_local="memcached.hosts=127.0.0.1"
CLIENT_COUNTS=(8 16 24 32 40)
RECORD_COUNT=10000000
OP_COUNT=20000000

# remote env options:
REMOTE_SERVER="node2x20a"
REMOTE_MONTAGE_DIR="/u/hwen5/workspace/Montage"
REMOTE_MEMCACHED_DIR="$REMOTE_MONTAGE_DIR/ext/memcached"
REMOTE_NVM_DIR="/mnt/pmem0"
MEMCACHED_HOST_remote="memcached.hosts=node2x20a"

# other envs:
YCSB_DIR=`pwd`
DATETIME=`date +"%m-%d-%y_%H-%M-%S"`
OUTPUT_DIR="$YCSB_DIR/results/$DATETIME"

HOST_VAR_NAME=MEMCACHED_HOST_${CONNECTION}
MEMCACHED_HOST=${!HOST_VAR_NAME}

# functions that runs and terminates memcached server
prepare_montage_local() {
    echo "compiling Montage"
    cd $MONTAGE_DIR
    make clean > /dev/null
    make > /dev/null
}

prepare_memcached_local () {
    cd $MEMCACHED_DIR
    git checkout $1
    echo "compiling Memcached"
    ./compile_montage.sh > /dev/null
}

start_memcached_local() {
    rm -rf $NVM_DIR/${USER}*
    echo "starting Memcached server"
    $MEMCACHED_DIR/memcached --memory-limit=4194304
}

end_memcached_local() {
    echo "killing Memcached server"
    killall memcached
    sleep 3s
}

# functions for remote memcached server

remote_execute() {
    ssh $REMOTE_SERVER $1
}

prepare_montage_remote() {
    remote_execute "
        echo \"compiling Montage\";
        cd $REMOTE_MONTAGE_DIR;
        make clean;
        make;
    "
}

prepare_memcached_remote() {
    remote_execute "
        cd $REMOTE_MEMCACHED_DIR;
        git checkout $1;
        echo \"compiling Memcached\";
        ./compile_montage.sh;
    "
}

start_memcached_remote() {
    remote_execute "
        rm -rf $REMOTE_NVM_DIR/${USER}*;
        echo \"starting Memcached server\";
        $REMOTE_MEMCACHED_DIR/memcached --memory-limit=4194304;
    "
}

end_memcached_remote() {
    remote_execute "
        echo \"killing Memcached server\";
        killall memcached;
        sleep 3s;
    "
}

# traps to terminate background processes on sigint or error:
trap end_memcached_${CONNECTION} INT TERM ERR
trap end_memcached_${CONNECTION} EXIT

# global prep:
prepare_montage_$CONNECTION
mkdir -p $OUTPUT_DIR

for MEMCACHED_OPTION in ${MEMCACHED_OPTIONS[@]}; do
    OUTPUT_FILE=$OUTPUT_DIR/$MEMCACHED_OPTION.txt
    prepare_memcached_$CONNECTION $MEMCACHED_OPTION
    cd $YCSB_DIR
    for CLIENT_COUNT in ${CLIENT_COUNTS[@]}; do
        start_memcached_$CONNECTION &

        echo "## client cnt: $CLIENT_COUNT" | tee -a $OUTPUT_FILE
        echo "# load data:" | tee -a $OUTPUT_FILE
        $YCSB_DIR/bin/ycsb load memcached -s -P $YCSB_DIR/workloads/workloada -p $MEMCACHED_HOST -p recordcount=$RECORD_COUNT -p threadcount=$CLIENT_COUNT 2>&1 | tee -a $OUTPUT_FILE
        echo "# YCSB-A:" | tee -a $OUTPUT_FILE
        $YCSB_DIR/bin/ycsb run memcached -s -P $YCSB_DIR/workloads/workloada -p $MEMCACHED_HOST -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT 2>&1 | tee -a $OUTPUT_FILE
        echo "# YCSB-B:" | tee -a $OUTPUT_FILE
        $YCSB_DIR/bin/ycsb run memcached -s -P $YCSB_DIR/workloads/workloadb -p $MEMCACHED_HOST -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT 2>&1 | tee -a $OUTPUT_FILE

        end_memcached_$CONNECTION
        
    done
done