#/bin/bash

# remote or local
# CONNECTION=remote
CONNECTION=local

# test dimentions:
MEMCACHED_OPTIONS=(
    "montage_kv_store"
    "montage_wt_cache"
    "montage_wb_cache"
    "montage_nvm_payloads"
    "montage_dram_payloads"
    "master"
)
# CLIENT_COUNTS=(8 16 24 32 40)
CLIENT_COUNTS=(4 8 12 16 20 24)
KV_OPTIONS=(
    "-p fieldcount=10 -p fieldlength=100"
    "-p fieldcount=1 -p fieldlength=32"
)
WORKER_THREAD_CNTS=(4 16)
RECORD_COUNT=10000000
OP_COUNT=20000000

# env options:
MONTAGE_DIR=`realpath ../Montage`
MEMCACHED_DIR=`realpath ../Montage/ext/memcached`
NVM_DIR="/mnt/pmem0"
MEMCACHED_HOST_local="memcached.hosts=127.0.0.1"

# remote env options:
REMOTE_SERVER="node2x20a"
REMOTE_MONTAGE_DIR="/u/hwen5/workspace/Montage"
REMOTE_MEMCACHED_DIR="$REMOTE_MONTAGE_DIR/ext/memcached"
REMOTE_NVM_DIR="/mnt/pmem0"
MEMCACHED_HOST_remote="memcached.hosts=node2x20a"

# common options:
MEMCACHED_MEMORY_LIMIT=81920 # MB
# MEMCACHED_EXEC="memcached-debug"
MEMCACHED_EXEC="memcached"

# generated envs:
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
    tmux send-keys -t memcached_session.0 "$MEMCACHED_DIR/memcached --memory-limit=$MEMCACHED_MEMORY_LIMIT -t $1 -v" Enter

    # for debugging:
    # tmux send-keys -t memcached_session.0 "q" Enter
    # tmux send-keys -t memcached_session.0 "q" Enter
    # tmux send-keys -t memcached_session.0 "gdb -x $YCSB_DIR/gdbinit --args $MEMCACHED_DIR/$MEMCACHED_EXEC --memory-limit=$MEMCACHED_MEMORY_LIMIT -t $1 -v" Enter
}

end_memcached_local() {
    echo "killing Memcached server"
    killall $MEMCACHED_EXEC
}

start_memcached_session_local() {
    tmux new -d -s memcached_session
}

end_memcached_session_local() {
    tmux kill-session -t memcached_session
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
        tmux send-keys -t memcached_session.0 \"$REMOTE_MEMCACHED_DIR/$MEMCACHED_EXEC --memory-limit=$MEMCACHED_MEMORY_LIMIT -t $1\" Enter;
    "
}

end_memcached_remote() {
    remote_execute "
        echo \"killing Memcached server\";
        killall $MEMCACHED_EXEC;
    "
}

start_memcached_session_remote() {
    remote_execute "
        tmux new -d -s memcached_session
    "
}

end_memcached_session_remote() {
    remote_execute "
        tmux kill-session -t memcached_session
    "
}

# traps to terminate background processes on sigint or error:
trap "exit" INT TERM ERR
trap "end_memcached_${CONNECTION}; killall memcached; kill 0" EXIT

# global prep:
prepare_montage_$CONNECTION
mkdir -p $OUTPUT_DIR
start_memcached_session_$CONNECTION

for MEMCACHED_OPTION in ${MEMCACHED_OPTIONS[@]}; do
    OUTPUT_FILE=$OUTPUT_DIR/$MEMCACHED_OPTION.txt
    prepare_memcached_$CONNECTION $MEMCACHED_OPTION
    cd $YCSB_DIR
    for WORKER_THREAD_CNT in ${WORKER_THREAD_CNTS[@]}; do
        echo "#### worker thread cnt: $WORKER_THREAD_CNT" | tee -a $OUTPUT_FILE
        for KV_OPTION in "${KV_OPTIONS[@]}"; do
            echo "### KV option: $KV_OPTION" | tee -a $OUTPUT_FILE
            for CLIENT_COUNT in ${CLIENT_COUNTS[@]}; do
                start_memcached_$CONNECTION $WORKER_THREAD_CNT
                sleep 5s

                echo "## client cnt: $CLIENT_COUNT" | tee -a $OUTPUT_FILE
                echo "# load data:" | tee -a $OUTPUT_FILE
                $YCSB_DIR/bin/ycsb load memcached -s -P $YCSB_DIR/workloads/workloada $KV_OPTION -p $MEMCACHED_HOST -p recordcount=$RECORD_COUNT -p threadcount=$CLIENT_COUNT 2>&1 | tee -a $OUTPUT_FILE
                echo "# YCSB-A:" | tee -a $OUTPUT_FILE
                $YCSB_DIR/bin/ycsb run memcached -s -P $YCSB_DIR/workloads/workloada $KV_OPTION -p $MEMCACHED_HOST -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT 2>&1 | tee -a $OUTPUT_FILE
                echo "# YCSB-B:" | tee -a $OUTPUT_FILE
                $YCSB_DIR/bin/ycsb run memcached -s -P $YCSB_DIR/workloads/workloadb $KV_OPTION -p $MEMCACHED_HOST -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT 2>&1 | tee -a $OUTPUT_FILE
                echo "# 100Write:" | tee -a $OUTPUT_FILE
                $YCSB_DIR/bin/ycsb run memcached -s -P $YCSB_DIR/workloads/workload_100write $KV_OPTION -p $MEMCACHED_HOST -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT 2>&1 | tee -a $OUTPUT_FILE
                echo "# 50insert,50delete:" | tee -a $OUTPUT_FILE
                $YCSB_DIR/bin/ycsb run memcached -s -P $YCSB_DIR/workloads/workload_50insert50delete $KV_OPTION -p $MEMCACHED_HOST -p operationcount=$OP_COUNT -p threadcount=$CLIENT_COUNT 2>&1 | tee -a $OUTPUT_FILE

                end_memcached_$CONNECTION
                sleep 5s
            done
        done
    done
done

end_memcached_session_$CONNECTION
