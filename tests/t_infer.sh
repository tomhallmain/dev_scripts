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

# Test multi-character custom separators
cat > "$tmp1" << EOF
field1=><=field2=><=field3=><=field4
value1=><=value2=><=value3=><=value4
data1=><=data2=><=data3=><=data4
test1=><=test2=><=test3=><=test4
more1=><=more2=><=more3=><=more4
EOF
[ "$(ds:inferfs "$tmp1" f t f f)" = '\=\>\<\=' ] \
    || ds:fail 'inferfs failed multi-character separator case'

# Test quoted fields with embedded separators
cat > "$tmp1" << EOF
"field,1"|"field,2"|"field,3"|"field,4"
"value|1"|value2|"value,3"|value4
"data|1"|"data,2"|data3|"data,4"
test1|"test,2"|"test|3"|test4
"more,1"|more2|"more|3"|"more,4"
EOF
[ "$(ds:inferfs "$tmp1" f t f f)" = '\|' ] \
    || ds:fail 'inferfs failed quoted fields with embedded separators case'

# Test mixed separators (should choose most consistent)
cat > "$tmp1" << EOF
field1,field2;field3,field4
value1,value2,value3,value4
data1,data2,data3,data4
test1,test2,test3,test4
more1,more2,more3,more4
EOF
[ "$(ds:inferfs "$tmp1" f t f f)" = ',' ] \
    || ds:fail 'inferfs failed mixed separators case'

# Test high certainty mode
cat > "$tmp1" << EOF
field1##field2##field3##field4
value1##value2##value3##value4
data1##data2##data3##data4
test1##test2##test3##test4
more1##more2##more3##more4
EOF
[ "$(ds:inferfs "$tmp1" f t f t)" = '\#\#' ] \
    || ds:fail 'inferfs failed high certainty case'

# Test with CRLF in quoted fields
cat > "$tmp1" << EOF
"field
1"|"field
2"|field3|field4
"value
1"|value2|"value
3"|value4
data1|"data
2"|data3|"data
4"
test1|test2|"test
3"|test4
EOF
[ "$(ds:inferfs "$tmp1" f t f f)" = '\|' ] \
    || ds:fail 'inferfs failed CRLF in quoted fields case'

# Test with special characters
cat > "$tmp1" << EOF
field1⌘field2⌘field3⌘field4
value1⌘value2⌘value3⌘value4
data1⌘data2⌘data3⌘data4
test1⌘test2⌘test3⌘test4
EOF
[ "$(ds:inferfs "$tmp1" f t f f)" = '\⌘' ] \
    || ds:fail 'inferfs failed special characters case'

# Test with inconsistent field counts but clear separator
cat > "$tmp1" << EOF
field1@@field2@@field3@@field4
value1@@value2@@value3
data1@@data2@@data3@@data4@@data5
test1@@test2
more1@@more2@@more3@@more4
EOF
[ "$(ds:inferfs "$tmp1" f t f f)" = '\@\@' ] \
    || ds:fail 'inferfs failed inconsistent field counts case'

# Test with escaped quotes
cat > "$tmp1" << EOF
"field\"1"|"field\"2"|field3|"field\"4"
value1|"value\"2"|value3|value4
"data\"1"|data2|"data\"3"|data4
test1|"test\"2"|test3|"test\"4"
EOF
[ "$(ds:inferfs "$tmp1" f t f f)" = '\|' ] \
    || ds:fail 'inferfs failed escaped quotes case'

# Test with empty fields
cat > "$tmp1" << EOF
field1%%field2%%%%field4
value1%%%%value3%%value4
%%%%data3%%data4
test1%%test2%%test3%%
%%more2%%more3%%more4
EOF
[ "$(ds:inferfs "$tmp1" f t f f)" = '\%\%' ] \
    || ds:fail 'inferfs failed empty fields case'

# Test with whitespace variations
cat > "$tmp1" << EOF
field1   field2     field3   field4
value1  value2   value3      value4
data1    data2  data3   data4
test1     test2    test3  test4
EOF
[ "$(ds:inferfs "$tmp1" f t f f)" = '[[:space:]]+' ] \
    || ds:fail 'inferfs failed whitespace variations case'

# Test with file extension override
cat > "$tmp1.csv" << EOF
field1⌘field2⌘field3
value1⌘value2⌘value3
data1⌘data2⌘data3
EOF
[ "$(ds:inferfs "$tmp1.csv" f t t f)" = ',' ] \
    || ds:fail 'inferfs failed file extension override case'

# Test with no separator (single field)
cat > "$tmp1" << EOF
field1
value1
data1
test1
more1
EOF
[ "$(ds:inferfs "$tmp1" f t f t)" = '[[:space:]]+' ] \
    || ds:fail 'inferfs failed no separator case'

# INFERH TESTS

# Basic header detection tests
ds:inferh 'tests/data/seps_test_base' 2>$q           && ds:fail 'inferh failed custom separator noheaders case'
ds:inferh 'tests/data/ls_sq' 2>$q                    && ds:fail 'inferh failed ls noheaders case'
ds:inferh 'tests/data/company_funding_data.csv' 2>$q || ds:fail 'inferh failed basic headers case'
ds:inferh 'tests/data/addresses_reordered' 2>$q      || ds:fail 'inferh failed complex headers case'

# Test CamelCase headers
cat > "$tmp1" << EOF
FirstName,LastName,PhoneNumber,Email,Department
John,Doe,123-456-7890,john.doe@email.com,Engineering
Jane,Smith,234-567-8901,jane.smith@email.com,Marketing
Bob,Johnson,345-678-9012,bob.johnson@email.com,Sales
Alice,Williams,456-789-0123,alice.williams@email.com,HR
Charlie,Brown,567-890-1234,charlie.brown@email.com,Finance
David,Miller,678-901-2345,david.miller@email.com,IT
EOF
ds:inferh "$tmp1" 2>$q || ds:fail 'inferh failed CamelCase headers case'

# Test snake_case headers
cat > "$tmp1" << EOF
first_name,last_name,phone_number,email_address,department_name
John,Doe,123-456-7890,john.doe@email.com,Engineering
Jane,Smith,234-567-8901,jane.smith@email.com,Marketing
Bob,Johnson,345-678-9012,bob.johnson@email.com,Sales
Alice,Williams,456-789-0123,alice.williams@email.com,HR
Charlie,Brown,567-890-1234,charlie.brown@email.com,Finance
EOF
ds:inferh "$tmp1" 2>$q || ds:fail 'inferh failed snake_case headers case'

# Test CONSTANT_CASE headers
cat > "$tmp1" << EOF
FIRST_NAME,LAST_NAME,PHONE_NUMBER,EMAIL_ADDRESS,DEPARTMENT
John,Doe,123-456-7890,john.doe@email.com,Engineering
Jane,Smith,234-567-8901,jane.smith@email.com,Marketing
Bob,Johnson,345-678-9012,bob.johnson@email.com,Sales
Alice,Williams,456-789-0123,alice.williams@email.com,HR
Charlie,Brown,567-890-1234,charlie.brown@email.com,Finance
EOF
ds:inferh "$tmp1" 2>$q || ds:fail 'inferh failed CONSTANT_CASE headers case'

# Test statistical term headers
cat > "$tmp1" << EOF
sum_sales,avg_price,count_items,total_cost,mean_value,median_score
15000.50,125.99,120,18750.25,156.25,145.00
22500.75,135.50,167,28875.50,172.90,168.50
18750.25,115.75,145,21562.80,148.75,142.25
25000.00,145.25,172,32250.75,187.50,182.75
19500.50,128.99,152,24375.50,160.35,157.50
EOF
ds:inferh "$tmp1" 2>$q || ds:fail 'inferh failed statistical headers case'

# Test time-related headers
cat > "$tmp1" << EOF
date_created,timestamp,modified_at,update_time,creation_date
2024-01-01,1704067200,2024-01-15T10:30:00Z,1704585600,2024-01-01
2024-01-02,1704153600,2024-01-16T14:20:00Z,1704672000,2024-01-02
2024-01-03,1704240000,2024-01-17T09:15:00Z,1704758400,2024-01-03
2024-01-04,1704326400,2024-01-18T16:45:00Z,1704844800,2024-01-04
2024-01-05,1704412800,2024-01-19T11:25:00Z,1704931200,2024-01-05
EOF
ds:inferh "$tmp1" 2>$q || ds:fail 'inferh failed time-related headers case'

# Test single column (should fail)
cat > "$tmp1" << EOF
header
value1
value2
value3
value4
value5
value6
EOF
ds:inferh "$tmp1" 2>$q && ds:fail 'inferh failed single column case'

# Test inconsistent field counts (should fail)
cat > "$tmp1" << EOF
col1,col2,col3,col4
val1,val2,val3
val4,val5,val6,val7
val8,val9
val10,val11,val12,val13
val14,val15,val16
EOF
ds:inferh "$tmp1" 2>$q && ds:fail 'inferh failed inconsistent fields case'

# Test numeric data without headers (should fail)
cat > "$tmp1" << EOF
1,2,3,4,5
6,7,8,9,10
11,12,13,14,15
16,17,18,19,20
21,22,23,24,25
26,27,28,29,30
EOF
ds:inferh "$tmp1" 2>$q && ds:fail 'inferh failed numeric data case'

# Test with different separators
cat > "$tmp1" << EOF
First Name|Last Name|Phone|Email|Department
John|Doe|123-456-7890|john.doe@email.com|Engineering
Jane|Smith|234-567-8901|jane.smith@email.com|Marketing
Bob|Johnson|345-678-9012|bob.johnson@email.com|Sales
Alice|Williams|456-789-0123|alice.williams@email.com|HR
Charlie|Brown|567-890-1234|charlie.brown@email.com|Finance
EOF
ds:inferh "$tmp1" -v FS="|" 2>$q || ds:fail 'inferh failed pipe separator case'

# Test with empty file (should fail)
echo -n "" > "$tmp1"
ds:inferh "$tmp1" 2>$q && ds:fail 'inferh failed empty file case'

# Test with only one row (should fail)
echo -e "col1,col2,col3,col4" > "$tmp1"
ds:inferh "$tmp1" 2>$q && ds:fail 'inferh failed single row case'

# Test with JSON data in fields
cat > "$tmp1" << EOF
id,config,data,metadata,settings
1,{"type":"A","value":10},{"name":"test1"},{"status":"active"},{"enabled":true}
2,{"type":"B","value":20},{"name":"test2"},{"status":"inactive"},{"enabled":false}
3,{"type":"C","value":30},{"name":"test3"},{"status":"pending"},{"enabled":true}
4,{"type":"D","value":40},{"name":"test4"},{"status":"active"},{"enabled":true}
5,{"type":"E","value":50},{"name":"test5"},{"status":"inactive"},{"enabled":false}
EOF
ds:inferh "$tmp1" 2>$q || ds:fail 'inferh failed JSON fields case'

# Test with HTML/XML data in fields
cat > "$tmp1" << EOF
id,html_content,xml_data,description,status
1,<div class="test">content1</div>,<data><value>1</value></data>,Test Entry 1,active
2,<p style="color:red">content2</p>,<data><value>2</value></data>,Test Entry 2,inactive
3,<span id="item3">content3</span>,<data><value>3</value></data>,Test Entry 3,pending
4,<div class="test">content4</div>,<data><value>4</value></data>,Test Entry 4,active
5,<p style="color:blue">content5</p>,<data><value>5</value></data>,Test Entry 5,inactive
EOF
ds:inferh "$tmp1" 2>$q || ds:fail 'inferh failed HTML/XML fields case'

# Test with mixed case and special characters in headers
cat > "$tmp1" << EOF
User_ID,firstName,LAST-NAME,Email_Address,phoneNumber
1,John,Doe,john.doe@email.com,123-456-7890
2,Jane,Smith,jane.smith@email.com,234-567-8901
3,Bob,Johnson,bob.johnson@email.com,345-678-9012
4,Alice,Williams,alice.williams@email.com,456-789-0123
5,Charlie,Brown,charlie.brown@email.com,567-890-1234
EOF
ds:inferh "$tmp1" 2>$q || ds:fail 'inferh failed mixed case headers case'

# Test with quoted fields
cat > "$tmp1" << EOF
"Column 1","Column 2","Column 3","Column 4","Column 5"
"value 1.1","value 1.2","value 1.3","value 1.4","value 1.5"
"value 2.1","value 2.2","value 2.3","value 2.4","value 2.5"
"value 3.1","value 3.2","value 3.3","value 3.4","value 3.5"
"value 4.1","value 4.2","value 4.3","value 4.4","value 4.5"
"value 5.1","value 5.2","value 5.3","value 5.4","value 5.5"
EOF
ds:inferh "$tmp1" 2>$q || ds:fail 'inferh failed quoted fields case'

# Test with debug output
cat > "$tmp1" << EOF
col1,col2,col3,col4,col5
val1.1,val1.2,val1.3,val1.4,val1.5
val2.1,val2.2,val2.3,val2.4,val2.5
val3.1,val3.2,val3.3,val3.4,val3.5
val4.1,val4.2,val4.3,val4.4,val4.5
val5.1,val5.2,val5.3,val5.4,val5.5
EOF
ds:inferh "$tmp1" -v debug=true 2>$q || ds:fail 'inferh failed debug mode case'

echo -e "${GREEN}PASS${NC}"
