#!/bin/bash

source commands.sh

# SHAPE TESTS

echo -n "Running shape tests..."

expected='       lines: 7585
       lines with "AUBURN": 75
       occurrence: 76
       average: 0.0100198
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
[ "$(ds:shape tests/data/testcrimedata.csv AUBURN 0 10 -v style="plus" | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'shape command failed'
[ "$(ds:shape tests/data/testcrimedata.csv AUBURN wfwe 10 -v style="plus" | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'shape command failed'

expected='       lines: 7585
       stats from field: $6
       lines with "AUTO": 237                                   lines with "INDECE": 2                                   lines with "PUBLI": 31                                   lines with "BURGL": 986
       occurrence: 237                                          occurrence: 2                                            occurrence: 31                                           occurrence: 986
       average: 0.0312459                                       average: 0.000263678                                     average: 0.00408701                                      average: 0.129993
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
actual="$(ds:shape tests/data/testcrimedata.csv 'AUTO,INDECE,PUBLI,BURGL' 6 30 -v tty_size=238 -v style="plus" | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command failed'

# Test case-insensitive matching
expected='lines: 3
lines with "Hello": 3
occurrence: 3
average: 1'
actual="$(echo -e "Hello\nhello\nHELLO" | awk -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/shape.awk" -v measures="Hello" -v simple=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command case-insensitive test failed'

# Test extended statistics
expected='lines: 6
lines with "length": 6 (100.00%)
occurrence: 6
average: 1 (100.00% probability)
approx var: 0
25th percentile: 1
median: 1
75th percentile: 1'
actual="$(echo -e "1\n2\n2\n3\n3\n3" | awk -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/shape.awk" -v measures="_length_" -v stats=1 -v simple=1 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command extended stats test failed'

# Test visualization styles
expected='       lines: 6
       lines with "a": 3
       occurrence: 3
       average: 0.5
lineno distribution of "a"
     3 ███
     6
     9'
actual="$(echo -e "a\na\na\nb\nb\nc" | awk -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/shape.awk" -v measures="a" -v style="blocks" -v span=3 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command blocks style test failed'

# Test normalized display
expected='       lines: 6
       lines with "a": 3                             lines with "b": 2
       occurrence: 3                                 occurrence: 2
       average: 0.5                                  average: 0.333333
lineno distribution of "a"                           distribution of "b"
     3 +++++++++++++++++++++++++++++++++++++++++++++
     6                                               +++++++++++++++++++++++++++++++++++++++++++++
     9'
actual="$(echo -e "a\na\na\nb\nb\nc" | awk -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/shape.awk" -v measures="a,b" -v style="plus" -v normalize=1 -v span=3 -v tty_size=100 | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command normalized display test failed'

# Test vertical histogram
expected='       lines: 6
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
actual="$(echo -e "a\na\na\nb\nb\nc" | awk -f "$DS_SUPPORT/utils.awk" -f "$DS_SCRIPT/shape.awk" -v measures="a" -v vertical=1 -v span=3 -v style="blocks" | sed -E 's/[[:space:]]+$//g')"
[ "$actual" = "$expected" ] || ds:fail 'shape command vertical histogram test failed'


# Test default style based on wcwidth availability
if ds:awksafe; then
    # When wcwidth is available, default should be "blocks" (█)
    expected='       lines: 6
       lines with "a": 3
       occurrence: 3
       average: 0.5
lineno distribution of "a"
     3 ███
     6
     9'
    actual="$(echo -e "a\na\na\nb\nb\nc" | ds:shape "a" 0 3 -v span=3 | sed -E 's/[[:space:]]+$//g')"
    [ "$actual" = "$expected" ] || ds:fail 'shape command failed default style test'
else
    # When wcwidth is not available, default should be "plus" (+)
    expected='       lines: 6
       lines with "a": 3
       occurrence: 3
       average: 0.5
lineno distribution of "a"
     3 +++
     6
     9'
    actual="$(echo -e "a\na\na\nb\nb\nc" | ds:shape "a" 0 3 -v span=3 | sed -E 's/[[:space:]]+$//g')"
    [ "$actual" = "$expected" ] || ds:fail 'shape command failed default style test'
fi

# HIST TESTS

expected='Hist: district (field 3), cardinality 6
                        1 ++++++++ (868)
                        2 +++++++++++++ (1462)
                        3 +++++++++++++++ (1575)
                        4 +++++++++++ (1161)
                        5 +++++++++++ (1159)
                        6 ++++++++++++ (1359)

Hist: grid (field 5), cardinality 539
                102 - 257 ++++ (383)
                258 - 413 +++ (303)
                414 - 569 +++++++++++++++ (1269)
                570 - 725 +++++++ (593)
                726 - 881 ++++++++++++++ (1187)
               882 - 1037 ++++++++++++ (1091)
              1038 - 1193 ++++++++ (692)
              1194 - 1349 +++++ (471)
              1350 - 1505 +++++++++ (833)
              1506 - 1661 +++++++++ (762)

Hist: ucr_ncic_code (field 7), cardinality 88
               909 - 1628 +++ (534)
              1629 - 2347 ++++++++ (1429)
              2348 - 3066 ++++++++++ (1787)
              3067 - 3786 ++ (368)
              3787 - 4505  (56)
              4506 - 5224 + (176)
              5225 - 5944 ++++ (731)
              5945 - 6663  (0)
              6664 - 7382 +++++++++++++++ (2471)
              7383 - 8102  (32)

Hist: latitude (field 8), cardinality 1906
            38.44 - 38.46 ++ (228)
            38.46 - 38.49 +++++++++ (779)
            38.49 - 38.51 +++++++ (676)
            38.51 - 38.54 +++++++++++ (1002)
            38.54 - 38.56 +++++++++++++ (1149)
            38.56 - 38.59 +++++++++++++++ (1291)
            38.59 - 38.61 ++++++ (555)
            38.61 - 38.63 +++++++++++++ (1176)
            38.63 - 38.66 ++++++ (577)
            38.66 - 38.68 + (151)

Hist: longitude (field 9), cardinality 187
        -121.56 - -121.54 + (121)
        -121.54 - -121.52 +++ (337)
        -121.52 - -121.50 +++++++ (769)
        -121.50 - -121.48 ++++++++++++++ (1414)
        -121.48 - -121.46 +++++++++++++++ (1480)
        -121.46 - -121.44 +++++++++++++ (1283)
        -121.44 - -121.42 +++++++++++++ (1330)
        -121.42 - -121.40 ++++++ (652)
        -121.40 - -121.38 + (117)
        -121.38 - -121.36  (81)'
[ "$(ds:hist tests/data/testcrimedata.csv | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'hist command failed'

# Create test data for hist features
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
expected='Hist: value (field 1), cardinality 10
                1.2 - 2.2 + (1)
                2.2 - 4.0 ++ (2)
                4.0 - 7.3  (0)
               7.3 - 13.4 + (1)
              13.4 - 24.5 + (1)
              24.5 - 44.8 + (1)
              44.8 - 81.9  (0)
             81.9 - 149.7 + (1)
            149.7 - 273.6 ++ (2)
            273.6 - 500.1 + (1)'
[ "$(ds:hist "${tmp}_hist_data" -v log_scale=1 -v header=1 -v fields=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram log scale test failed'

# Test different styles
expected='Hist: value (field 1), cardinality 10
              1.2 - 101.0 ███████ (7)
            101.0 - 200.8 █ (1)
            200.8 - 300.5 █ (1)
            300.5 - 400.3  (0)
            400.3 - 500.1 █ (1)'
[ "$(ds:hist "${tmp}_hist_data" -v style=blocks -v header=1 -v fields=1 -v n_bins=5 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram blocks style test failed'

expected='Hist: value (field 1), cardinality 10
              1.2 - 101.0 ███████ (7)
            101.0 - 200.8 ░ (1)
            200.8 - 300.5 ░ (1)
            300.5 - 400.3  (0)
            400.3 - 500.1 ░ (1)'
[ "$(ds:hist "${tmp}_hist_data" -v style=shade -v header=1 -v fields=1 -v n_bins=5 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram shade style test failed'

# Test statistics and percentiles
expected='Hist: value (field 1), cardinality 10
Mean: 101, Median: 20.4
StdDev: 149, Variance: 2.22e+04
Skewness: 1.813 (Right-skewed)
Quartiles: Q1=5.475, Q3=137.9 (IQR=132.5)
10th-90th percentile range: 2.37 - 230.7
               1.2 - 51.1 ++++++ (6)
             51.1 - 101.0 + (1)
            101.0 - 150.9 + (1)
            150.9 - 200.8  (0)
            200.8 - 250.7 + (1)
            250.7 - 300.5  (0)
            300.5 - 350.4  (0)
            350.4 - 400.3  (0)
            400.3 - 450.2  (0)
            450.2 - 500.1 + (1)'
[ "$(ds:hist "${tmp}_hist_data" -v stats=1 -v percentiles=1 -v header=1 -v fields=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram statistics test failed'

# Test cumulative distribution
expected='Hist: value (field 1), cardinality 10
               1.2 - 51.1 ++++++ (6)
             51.1 - 101.0 +++++++ (7)
            101.0 - 150.9 ++++++++ (8)
            150.9 - 200.8 ++++++++ (8)
            200.8 - 250.7 +++++++++ (9)
            250.7 - 300.5 +++++++++ (9)
            300.5 - 350.4 +++++++++ (9)
            350.4 - 400.3 +++++++++ (9)
            400.3 - 450.2 +++++++++ (9)
            450.2 - 500.1 ++++++++++ (10)'
[ "$(ds:hist "${tmp}_hist_data" -v cumulative=1 -v header=1 -v fields=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram cumulative test failed'

# Test multiple features combined
expected='Hist: value (field 1), cardinality 10
Mean: 101, Median: 20.4
StdDev: 149, Variance: 2.22e+04
Skewness: 1.813 (Right-skewed)
Quartiles: Q1=5.475, Q3=137.9 (IQR=132.5)
10th-90th percentile range: 2.37 - 230.7
                1.2 - 4.0 ⠟⠟⠟ (3)
               4.0 - 13.4 ⠃ (1)
              13.4 - 44.8 ⠏⠏ (2)
             44.8 - 149.7 ⠃ (1)
            149.7 - 500.1 ⠟⠟⠟ (3)'
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

expected='Hist: value (field 1), cardinality 1
                        1 +++++ (5)'
[ "$(ds:hist "${tmp}_hist_edge" -v header=1 -v fields=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'histogram edge case test failed'


# PLOT TESTS

# echo -n "Running plot tests..."

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
expected='
        ⋅




      ⋅



    ⋅


  ⋅
⋅

Statistics:
Points: 5
X range: [1, 5]
Y range: [2, 25]
X cardinality: 5
Y cardinality: 5'
[ "$(ds:plot "${tmp}_plot" -v width=10 -v height=15 -v header=1 -v labels=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'basic plot test failed'

# # Test line plot with title
# expected='Growth Curve
#      25 •
#        /
#        /
#      16/
#       /
#       /
#       9
#      /
#     /
#     4
#    /
#   /
#   2
  
# ────────────
# 1    3    5

# Statistics:
# Points: 5
# X range: [1, 5]
# Y range: [2, 25]
# X cardinality: 5
# Y cardinality: 5'
# [ "$(ds:plot "${tmp}_plot" -v type=line -v width=10 -v height=13 -v header=1 -v title="Growth_Curve" -v labels=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'line plot test failed'

# # Test plot with custom range and grid
# cat > "${tmp}_plot2" << EOL
# time,value
# 1,10
# 2,15
# 3,12
# 4,18
# 5,14
# EOL

# expected='     20 · · · · ·
#         •
#      18  •
#      16 · • · • ·
#         •
#      14  •
#      12 · · · · ·
        
#      10 •
        
# ────────────
# 1    3    5
# Time

# Statistics:
# Points: 5
# X range: [1, 5]
# Y range: [10, 18]
# X cardinality: 5
# Y cardinality: 5'
# [ "$(ds:plot "${tmp}_plot2" -v width=10 -v height=10 -v header=1 -v grid=1 -v range="1,5,10,20" -v labels=1 -v xlab="Time" | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'plot with custom range and grid test failed'

# Test plot with different style
expected='
        ░




      ░



    ░


  ░
░

Statistics:
Points: 5
X range: [1, 5]
Y range: [2, 25]
X cardinality: 5
Y cardinality: 5'
[ "$(ds:plot "${tmp}_plot" -v width=10 -v height=15 -v header=1 -v style=blocks -v labels=1 | sed -E 's/[[:space:]]+$//g')" = "$expected" ] || ds:fail 'plot with different style test failed'

echo -e "${GREEN}PASS${NC}"

