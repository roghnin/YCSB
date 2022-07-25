set $_exitcode = -1
set confirm off
run
backtrace
# quit
if $_exitcode != -1 
    quit
end