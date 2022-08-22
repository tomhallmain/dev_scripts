#!/bin/bash

source commands.sh

# IFS TESTS

echo -n "Running inferfs and inferh tests..."

[ "$(ds:inferfs tests/data/infer_join_fields_test1.csv)" = ',' ] \
    || ds:fail 'inferfs failed extension case'

[ "$(ds:inferfs tests/data/seps_test_base)" = '\&\%\#' ] \
    || ds:fail 'inferfs failed custom separator case 1'

[ "$(ds:inferfs tests/data/infer_join_fields_test3.scsv)" = '\;\;' ] \
    || ds:fail 'inferfs failed custom separator case 2'

echo -e "wefkwefwl=21\nkwejf ekej=qwkdj\nTEST 349=|" > $tmp
[ "$(ds:inferfs $tmp)" = '\=' ] \
    || ds:fail 'inferfs failed custom separator case 3'

[ "$(ds:inferfs tests/data/ls_sq)" = '[[:space:]]+' ] \
    || ds:fail 'inferfs failed quoted fields case'

[ "$(ds:inferfs tests/data/addresses_reordered f t f f)" = ',' ] \
    || ds:fail 'inferfs failed complex quoted fields case'

[ "$(ds:inferfs tests/data/inferfs_chunks_test)" = ',' ] \
    || ds:fail 'inferfs failed simple chunks case'

[ "$(ds:inferfs tests/data/cities.csv f t f f)" = ',' ] \
    || ds:fail 'inferfs failed comma blank lines case'

# INFERH TESTS

ds:inferh 'tests/data/seps_test_base' 2>$q           && ds:fail 'inferh failed custom separator noheaders case'
ds:inferh 'tests/data/ls_sq' 2>$q                    && ds:fail 'inferh failed ls noheaders case'
ds:inferh 'tests/data/company_funding_data.csv' 2>$q || ds:fail 'inferh failed basic headers case'
ds:inferh 'tests/data/addresses_reordered' 2>$q      || ds:fail 'inferh failed complex headers case'

echo -e "${GREEN}PASS${NC}"
