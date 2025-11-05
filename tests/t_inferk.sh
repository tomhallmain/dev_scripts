#!/bin/bash

source commands.sh

echo -n "Running inferk tests..."
tmp1=/tmp/ds_inferk_test1
tmp2=/tmp/ds_inferk_test2

# Test data setup
cat > "$tmp1" << EOF
ID,Name,Age,Score,Type
1,John,25,95.5,A
2,Jane,30,88.2,B
3,Bob,28,92.1,A
4,Alice,22,97.8,A
5,Charlie,35,85.4,B
EOF

cat > "$tmp2" << EOF
UserID,FullName,Years,Grade,Category
1,John,25,95.5,A
2,Jane,30,88.2,B
3,Bob,28,92.1,A
4,Alice,22,97.8,A
5,Charlie,35,85.4,B
EOF

# Test exact header match
result="$(ds:inferk "$tmp1" "$tmp2")"
[ "$result" = "1" ] || ds:fail 'inferk failed exact ID match case'

# Test exact Name header match (non-ID field)

cat > "$tmp2" << EOF
Name,Grade,UserID,Category,Years
John,95.5,1,A,25
Jane,88.2,2,B,30
Bob,92.1,3,A,28
Alice,97.8,4,A,22
Charlie,85.4,5,B,35
EOF

result="$(ds:inferk "$tmp1" "$tmp2")"
[ "$result" = "2 1" ] || ds:fail 'inferk failed exact Name header match case'

# Test ID pattern match with different column positions
cat > "$tmp2" << EOF
FullName,Grade,UserID,Category,Years
John,95.5,1,A,25
Jane,88.2,2,B,30
Bob,92.1,3,A,28
Alice,97.8,4,A,22
Charlie,85.4,5,B,35
EOF

result="$(ds:inferk "$tmp1" "$tmp2")"
[ "$result" = "1 3" ] || ds:fail 'inferk failed ID pattern match case'

# Test numeric distribution match
cat > "$tmp1" << EOF
Name,Value1,Value2
A,100.5,1000
B,101.2,2000
C,99.8,3000
D,100.9,4000
E,100.2,5000
EOF

cat > "$tmp2" << EOF
ID,Score,Amount
1,100.5,1000
2,101.2,2000
3,99.8,3000
4,100.9,4000
5,100.2,5000
EOF

result="$(ds:inferk "$tmp1" "$tmp2")"
[ "$result" = "3" ] || ds:fail 'inferk failed numeric distribution match case'

# Test cardinality match (unique value ratio)
cat > "$tmp1" << EOF
ID,Group,Code
1,A,ABC123
2,A,DEF456
3,B,GHI789
4,B,JKL012
5,A,MNO345
EOF

cat > "$tmp2" << EOF
Name,Type,Serial
John,A,ABC123
Jane,A,DEF456
Bob,B,GHI789
Alice,B,JKL012
Charlie,A,MNO345
EOF

result="$(ds:inferk "$tmp1" "$tmp2")"
[ "$result" = "3" ] || ds:fail 'inferk failed cardinality match case'

# Test entropy match (field complexity)
cat > "$tmp1" << EOF
ID,Simple,Complex
1,A,Mix3d_C4se!
2,B,An0ther-0ne
3,A,Th1rd_3ntry
4,B,L4st_0ne!23
5,A,F1nal-3ntry
EOF

cat > "$tmp2" << EOF
Name,Category,Pattern
John,X,Mix3d_C4se!
Jane,Y,An0ther-0ne
Bob,X,Th1rd_3ntry
Alice,Y,L4st_0ne!23
Charlie,X,F1nal-3ntry
EOF

result="$(ds:inferk "$tmp1" "$tmp2")"
[ "$result" = "3" ] || ds:fail 'inferk failed entropy match case'

# Test different separators
cat > "$tmp1" << EOF
ID;Name;Value
1;John;100
2;Jane;200
3;Bob;300
EOF

cat > "$tmp2" << EOF
UserID|FullName|Amount
1|John|100
2|Jane|200
3|Bob|300
EOF

result="$(ds:inferk "$tmp1" "$tmp2" -v fs1=";" -v fs2="|")"
[ "$result" = "1" ] || ds:fail 'inferk failed different separators case'

# Test special types (dates, JSON)
cat > "$tmp1" << EOF
ID,Date,Data
1,2024-03-15,{"type":"A"}
2,2024-03-16,{"type":"B"}
3,2024-03-17,{"type":"C"}
EOF

cat > "$tmp2" << EOF
UserID,Timestamp,Metadata
1,03/15/2024,{"type":"A"}
2,03/16/2024,{"type":"B"}
3,03/17/2024,{"type":"C"}
EOF

result="$(ds:inferk "$tmp1" "$tmp2")"
[ "$result" = "1" ] || ds:fail 'inferk failed special types case'

# Test with missing values
cat > "$tmp1" << EOF
ID,Name,Value
1,John,100
2,,200
3,Bob,
4,Alice,400
EOF

cat > "$tmp2" << EOF
UserID,FullName,Amount
1,John,100
2,,200
3,Bob,
4,Alice,400
EOF

result="$(ds:inferk "$tmp1" "$tmp2")"
[ "$result" = "1" ] || ds:fail 'inferk failed missing values case'

# Test with varying number of columns
cat > "$tmp1" << EOF
ID,Name,Value,Extra1,Extra2
1,John,100,A,X
2,Jane,200,B,Y
3,Bob,300,C,Z
EOF

cat > "$tmp2" << EOF
UserID,FullName,Amount
1,John,100
2,Jane,200
3,Bob,300
EOF

result="$(ds:inferk "$tmp1" "$tmp2")"
[ "$result" = "1" ] || ds:fail 'inferk failed varying columns case'

rm $tmp1 $tmp2
echo -e "${GREEN}PASS${NC}" 