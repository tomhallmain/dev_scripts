#!/usr/bin/awk
#
# Extract graph relationships from directed acyclic graph data of the form:
#
#     RECEIVE_NODE  FIELD_SEPARATOR  SEND_NODE
#
# Useful for class dependency analysis, for example, after eliminating 
# 'extends' the graph can be built using this input:
#
#     2 extends 1
#     3 extends 2
#     4 extends 1
#
# Resulting graph output:
#            1 2 3
#            1 4
#
# AWKARG OPTS
#       -v print_bases
#           With this option set, resulting graph output includes bases:
#             1
#             1 2
#             1 2 3
#             1 4
# 
#

BEGIN {
    OFS = SetOFS()
}

{
    Shoots[$1] = $2
    Bases[$2] = 1
}

END {
    if (print_bases) {
        for (base in Bases){
            if (!(base in Shoots))
                print base
        }
    }

    for (shoot in Shoots) {
        if (Shoots[shoot] && (print_bases || !Bases[shoot])) {
            if (shoot == Shoots[shoot]) {
                Cycles[shoot] = 1
                continue
            }

            print Backtrace(shoot, Shoots[shoot])
        }
    }

    if (length(Cycles)) {
        print "WARNING: "length(Cycles)" cycles found!"

        for (cycle in Cycles)
            print "CYCLENODE__" cycle

        exit 1
    }
}

function Backtrace(start, test_base) {
    return (test_base in Shoots) ? Extend(Backtrace(test_base, Shoots[test_base]), start) : Extend(test_base, start)
}
function Extend(branch, offshoot) {
    return branch OFS offshoot
}

