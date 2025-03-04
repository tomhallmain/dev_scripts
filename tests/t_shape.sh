#!/bin/bash

source commands.sh

# SHAPE TESTS

echo -n "Running shape tests..."

expected='       lines: 7585
       lines with "AUBURN": 75
       occurrence: 76
       average: 0.0100198
       approx var: 3.96002
lineno distribution of "AUBURN"
   758 +++++++++++
  1516 +++++++
  2274 ++++++
  3032 +++++++
  3790 ++++++
  4548 ++++++++
  5306 ++++++++
  6064 +++++++++
  6822 ++++++++
  7580 ++++++
  8338'
[ "$(ds:shape tests/data/testcrimedata.csv AUBURN 0 10 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'shape command failed'
[ "$(ds:shape tests/data/testcrimedata.csv AUBURN wfwe 10 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'shape command failed'

expected='       lines: 7585
       stats from field: $6
       lines with "AUTO": 237                                   lines with "INDECE": 2                                   lines with "PUBLI": 31                                   lines with "BURGL": 986
       occurrence: 237                                          occurrence: 2                                            occurrence: 31                                           occurrence: 986
       average: 0.0312459                                       average: 0.000263678                                     average: 0.00408701                                      average: 0.129993
       approx var: 0.938485                                     approx var: 0.999473                                     approx var: 0.991843                                     approx var: 0.756911
lineno distribution of "AUTO"                                   distribution of "INDECE"                                 distribution of "PUBLI"                                  distribution of "BURGL"
   252 +++                                                                                                               ++++                                                     +++++++++++++++++++++++++++++++++
   504 ++++++++++++++++                                         +                                                        ++                                                       +++++++++++++++++++++++++++++++++++++
   756 +++++++++++++                                                                                                     +                                                        +++++++++++++++++++++++++++++++++++++++++++++++
  1008 +++++                                                                                                                                                                      ++++++++++++++++++++
  1260 +++++                                                                                                             +                                                        ++++++++++++++++++++++++++++++++++++++++
  1512 ++++                                                                                                              ++++                                                     ++++++++++++++++++++++++++++++++++++
  1764 ++++++++                                                                                                                                                                   +++++++++++++++++++++++++++++++++++++++++++++++++
  2016 +++++                                                                                                                                                                      ++++++++++++++++++++++++++++++
  2268 ++++++++++                                                                                                                                                                 ++++++++++++++++++++++++++++++++++
  2520 ++++++                                                                                                                                                                     +++++++++++++++++++++++++++++++++++++
  2772 ++++++                                                                                                            +                                                        ++++++++++++++++++++++++++++++++++++
  3024 +++++++                                                                                                           +                                                        +++++++++++++++++++++++++++++++++++
  3276 ++                                                                                                                +                                                        ++++++++++++++++++++++++++++++++++++
  3528 ++++                                                                                                                                                                       ++++++++++++++++++++++++++++++
  3780 ++++++++                                                                                                                                                                   +++++++++++++++++++++++
  4032 +++++++++                                                                                                                                                                  ++++++++++++++++++++++++++++++
  4284 ++++++++++++++++                                                                                                                                                           ++++++++++++++++++++++++++++++++
  4536 ++++++                                                                                                            ++                                                       +++++++++++++++++++++++++++++
  4788 +++++++++                                                                                                                                                                  +++++++++++++++++++++++++++++++++++++++
  5040 +++++                                                                                                             +++                                                      +++++++++++++++++++++++++++++++++++++++++
  5292 +++++                                                                                                                                                                      ++++++++++++++++++++++++++++++
  5544 +++++++++++++++                                                                                                   +++                                                      ++++++++++++++++++++++++++++
  5796 ++++++++++                                                                                                                                                                 +++++++++++++++++++++++
  6048 +++++++++                                                                                                         +                                                        +++++++++++++++++++++++++++++++++
  6300 +++++++++                                                                                                                                                                  ++++++++++++++++++++++++++++++++++
  6552 +++++++++++                                                                                                       ++                                                       ++++++++++++++++++++++++++++++++
  6804 ++++++                                                                                                            +                                                        ++++++++++++++++++++++++++++++++
  7056 +                                                        +                                                                                                                 ++++++++++++++++++++++++++++++++
  7308 ++++++++++++++                                                                                                    +++                                                      +++++++++++++++++
  7560 ++++++++++                                                                                                        +                                                        ++++++++++++++++++++++++++++
  7812'
actual="$(ds:shape tests/data/testcrimedata.csv 'AUTO,INDECE,PUBLI,BURGL' 6 30 -v tty_size=238 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command failed'

# Test case-insensitive matching
expected='lines: 3
lines with "Hello": 3
occurrence: 3
average: 1
approx var: 0'
actual="$(echo -e "Hello\nhello\nHELLO" | awk -f ../support/utils.awk -f ../scripts/shape.awk -v measures="Hello" -v case_sensitive=0 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command case-insensitive test failed'

# Test extended statistics
expected='lines: 6
lines with "length": 6
occurrence: 6
average: 1
median: 1
25th percentile: 1
75th percentile: 1'
actual="$(echo -e "1\n2\n2\n3\n3\n3" | awk -f ../support/utils.awk -f ../scripts/shape.awk -v measures="_length_" -v extended_stats=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command extended stats test failed'

# Test visualization styles
expected='lines: 6
lines with "a": 3
occurrence: 3
average: 0.5
lineno distribution of "a"
    3 ███
    6 '
actual="$(echo -e "a\na\na\nb\nb\nc" | awk -f ../support/utils.awk -f ../scripts/shape.awk -v measures="a" -v style="blocks" -v span=3 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command blocks style test failed'

# Test normalized display
expected='lines: 6
lines with "a": 3                                              lines with "b": 2
occurrence: 3                                                  occurrence: 2
average: 0.5                                                   average: 0.333333
lineno distribution of "a"                                     distribution of "b"
    3 ++++++++++++++++++++++                                  ++++++++++++++++
    6 '
actual="$(echo -e "a\na\na\nb\nb\nc" | awk -f ../support/utils.awk -f ../scripts/shape.awk -v measures="a,b" -v normalize=1 -v span=3 -v tty_size=100 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command normalized display test failed'

# Test vertical histogram
expected='lines: 6
lines with "a": 3
occurrence: 3
average: 0.5
lineno distribution of "a"
100% |█  
 90% |█  
 80% |█  
 70% |█  
 60% |█  
 50% |█  
 40% |█  
 30% |█  
 20% |█  
 10% |█  
     +---'
actual="$(echo -e "a\na\na\nb\nb\nc" | awk -f ../support/utils.awk -f ../scripts/shape.awk -v measures="a" -v vertical=1 -v span=3 -v style="blocks" | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command vertical histogram test failed'

# Test progress indicator (only testing stderr output)
expected='Processing: 1000/1000 (100%)'
actual="$(seq 1000 | awk -f ../support/utils.awk -f ../scripts/shape.awk -v measures="_length_" -v progress=1 2>&1 1>/dev/null | sed -E 's/\r//g' | tail -n1)"
[ "$actual" = "$expected" ] || ds:fail 'shape command progress indicator test failed'


# HIST TESTS

expected='Hist: field 3 (district), cardinality 6
               1 - 1.5 +
               1.5 - 2 +
               2 - 2.5
               2.5 - 3 +
               3 - 3.5
               3.5 - 4 +
               4 - 4.5
               4.5 - 5 +
               5 - 5.5
               5.5 - 6 +

Hist: field 5 (grid), cardinality 539
           102 - 257.9 ++++++++
         257.9 - 413.8 ++++++
         413.8 - 569.7 ++++++++++++++
         569.7 - 725.6 +++++++
         725.6 - 881.5 +++++++++++++++
        881.5 - 1037.4 ++++++++++++++
       1037.4 - 1193.3 +++++++++
       1193.3 - 1349.2 +++++++++++++
       1349.2 - 1505.1 ++++++++++
         1505.1 - 1661 ++++++

Hist: field 7 (ucr_ncic_code), cardinality 88
          909 - 1628.3 +++++++++++
       1628.3 - 2347.6 ++++++++++++++
       2347.6 - 3066.9 ++++++++++++++
       3066.9 - 3786.2 ++++++++++++++
       3786.2 - 4505.5 +++++
       4505.5 - 5224.8 ++++++++++++++
       5224.8 - 5944.1 +++++++++++
       5944.1 - 6663.4
       6663.4 - 7382.7 ++
         7382.7 - 8102 +++

Hist: field 8 (latitude), cardinality 1905
      38.438 - 38.4626 +++++++
     38.4626 - 38.4872 +++++++++++++
     38.4872 - 38.5117 +++++++++++++
     38.5117 - 38.5363 ++++++++++++++
     38.5363 - 38.5609 ++++++++++++++
     38.5609 - 38.5855 ++++++++++++++
     38.5855 - 38.6101 +++++++++
     38.6101 - 38.6346 ++++++++++++++
     38.6346 - 38.6592 +++++++++++
     38.6592 - 38.6838 ++++++

Hist: field 9 (longitude), cardinality 187
   -121.556 - -121.537 +++++++++++++++
   -121.537 - -121.518 ++++++++++++++
   -121.518 - -121.499 ++++++++++++++
    -121.499 - -121.48 ++++++++++++++
    -121.48 - -121.461 ++++++++++++++
   -121.461 - -121.441 +++++++++++++++
   -121.441 - -121.422 ++++++++++++++
   -121.422 - -121.403 ++++++++++++++
   -121.403 - -121.384 ++++++++++++++
   -121.384 - -121.365 ++++++++++'
[ "$(ds:hist tests/data/testcrimedata.csv | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'hist command failed'

# Create test data for new hist features
cat > "${tmp}_hist_data" << EOL
value,category
1.2,A
2.5,A
3.8,A
10.5,B
15.2,B
25.6,B
100.2,C
150.5,C
200.8,C
500.1,C
EOL

# Test logarithmic binning
echo "Testing logarithmic histogram..."
expected='EXPECTED_LOG_OUTPUT'
[ "$(ds:hist "${tmp}_hist_data" -v log_scale=1 -v header=1 -v fields=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram log scale test failed'

# Test different styles
echo "Testing histogram styles..."
expected='EXPECTED_STYLE_OUTPUT'
[ "$(ds:hist "${tmp}_hist_data" -v style=blocks -v header=1 -v fields=1 -v n_bins=5 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram blocks style test failed'

expected='EXPECTED_SHADE_OUTPUT'
[ "$(ds:hist "${tmp}_hist_data" -v style=shade -v header=1 -v fields=1 -v n_bins=5 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram shade style test failed'

# Test statistics and percentiles
echo "Testing histogram statistics..."
expected='EXPECTED_STATS_OUTPUT'
[ "$(ds:hist "${tmp}_hist_data" -v stats=1 -v percentiles=1 -v header=1 -v fields=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram statistics test failed'

# Test cumulative distribution
echo "Testing cumulative histogram..."
expected='EXPECTED_CUMULATIVE_OUTPUT'
[ "$(ds:hist "${tmp}_hist_data" -v cumulative=1 -v header=1 -v fields=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram cumulative test failed'

# Test multiple features combined
echo "Testing combined histogram features..."
expected='EXPECTED_COMBINED_OUTPUT'
[ "$(ds:hist "${tmp}_hist_data" -v log_scale=1 -v style=braille -v stats=1 -v percentiles=1 -v header=1 -v fields=1 -v n_bins=5 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram combined features test failed'

# Test edge cases
cat > "${tmp}_hist_edge" << EOL
value
1
1
1
1
1
EOL

echo "Testing histogram edge cases..."
expected='EXPECTED_EDGE_OUTPUT'
[ "$(ds:hist "${tmp}_hist_edge" -v header=1 -v fields=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram edge case test failed'


# PLOT TESTS

echo -n "Running plot tests..."

# Create test data
cat > "${tmp}_plot" << EOL
x,y
1,2
2,4
3,9
4,16
5,25
EOL

# Test basic scatter plot
expected='     25 •
        
        
     16  •
        
        
      9   •
        
        
      4    •
        
        
      2     •
        
────────────
1    3    5

Statistics:
Points: 5
X range: [1, 5]
Y range: [2, 25]
X cardinality: 5
Y cardinality: 5'
[ "$(ds:plot "${tmp}_plot" -v width=10 -v height=15 -v header=1 -v labels=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'basic plot test failed'

# Test line plot with title
expected='Growth Curve
     25 •
       /
       /
     16/
      /
      /
      9
     /
    /
    4
   /
  /
  2
  
────────────
1    3    5

Statistics:
Points: 5
X range: [1, 5]
Y range: [2, 25]
X cardinality: 5
Y cardinality: 5'
[ "$(ds:plot "${tmp}_plot" -v type=line -v width=10 -v height=13 -v header=1 -v title="Growth Curve" -v labels=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'line plot test failed'

# Test plot with custom range and grid
cat > "${tmp}_plot2" << EOL
time,value
1,10
2,15
3,12
4,18
5,14
EOL

expected='     20 · · · · ·
        •
     18  •
     16 · • · • ·
        •
     14  •
     12 · · · · ·
        
     10 •
        
────────────
1    3    5
Time

Statistics:
Points: 5
X range: [1, 5]
Y range: [10, 18]
X cardinality: 5
Y cardinality: 5'
[ "$(ds:plot "${tmp}_plot2" -v width=10 -v height=10 -v header=1 -v grid=1 -v range="1,5,10,20" -v labels=1 -v xlab="Time" | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'plot with custom range and grid test failed'

# Test plot with different style
expected='     25 █
        
        
     16  █
        
        
      9   █
        
        
      4    █
        
        
      2     █
        
────────────
1    3    5

Statistics:
Points: 5
X range: [1, 5]
Y range: [2, 25]
X cardinality: 5
Y cardinality: 5'
[ "$(ds:plot "${tmp}_plot" -v width=10 -v height=15 -v header=1 -v style=blocks -v labels=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'plot with different style test failed'

echo -e "${GREEN}PASS${NC}"

