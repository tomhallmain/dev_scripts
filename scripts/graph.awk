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
# 1
# 1 2
# 1 2 3
# 1 4
#

{
  Shoots[$1] = $2
  Bases[$2] = 1
}

END{
  for (base in Bases){
    if (!(base in Shoots))
      print base }

  for (shoot in Shoots)
    if (Shoots[shoot])
      print Backtrace(shoot, Shoots[shoot])
}

function Backtrace(start, test_base) {
  return (test_base in Shoots) ? Extend(Backtrace(test_base, Shoots[test_base]), start) : Extend(test_base, start)
}
function Extend(branch, offshoot) {
  return branch OFS offshoot
}


