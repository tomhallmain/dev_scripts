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



echo -e "${GREEN}PASS${NC}"
