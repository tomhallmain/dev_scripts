#!/bin/bash
# Test suite for verifying deterministic ordering in join operations

. ./scripts/test_utils.sh

# Setup test data with various key patterns
cat > order_test1.csv << 'EOD'
id,value
1,a
2,b
2,c
1,d
EOD

cat > order_test2.csv << 'EOD'
id,data
1,x
2,y
2,z
1,w
EOD

# Test 1: Basic join with duplicate keys
test_name="Join with duplicate keys produces consistent ordering"
expected="id,value,data
1,a,x
1,d,w
2,b,y
2,c,z"

actual=$(ds:join order_test1.csv order_test2.csv outer 1 -v fs1=',' -v fs2=',')
assert_equal "$test_name" "$expected" "$actual"

# Test 2: Merge operation with bias
cat > merge_test1.csv << 'EOD'
id,val1,val2
1,a,b
2,c,d
3,e,f
EOD

cat > merge_test2.csv << 'EOD'
id,val1,val2
2,x,y
3,m,n
4,p,q
EOD

test_name="Merge with bias produces consistent ordering"
expected="id,val1,val2
1,a,b
2,x,y
3,m,n
4,p,q"

actual=$(ds:join merge_test1.csv merge_test2.csv outer merge -v fs1=',' -v fs2=',' -v bias_merge_keys=2,3)
assert_equal "$test_name" "$expected" "$actual"

# Test 3: Multi-key join with mixed data types
cat > multi_key1.csv << 'EOD'
region,year,value
East,2020,100
West,2020,200
East,2021,300
West,2021,400
EOD

cat > multi_key2.csv << 'EOD'
region,year,target
East,2020,110
West,2020,220
East,2021,330
West,2021,440
EOD

test_name="Multi-key join produces consistent ordering"
expected="region,year,value,target
East,2020,100,110
East,2021,300,330
West,2020,200,220
West,2021,400,440"

actual=$(ds:join multi_key1.csv multi_key2.csv outer 1,2 -v fs1=',' -v fs2=',')
assert_equal "$test_name" "$expected" "$actual"

# Test 4: Join with empty fields and nulls
cat > null_test1.csv << 'EOD'
id,value
1,
2,b
,c
3,d
EOD

cat > null_test2.csv << 'EOD'
id,data
1,x
,y
3,z
4,w
EOD

test_name="Join with nulls and empty fields produces consistent ordering"
expected="id,value,data
,c,y
1,,x
2,b,<NULL>
3,d,z
4,<NULL>,w"

actual=$(ds:join null_test1.csv null_test2.csv outer 1 -v fs1=',' -v fs2=',')
assert_equal "$test_name" "$expected" "$actual"

# Cleanup
rm -f order_test1.csv order_test2.csv merge_test1.csv merge_test2.csv multi_key1.csv multi_key2.csv null_test1.csv null_test2.csv

echo "All ordering tests completed" 