## This file is just a test, it is incomplete because I don't know how to intitialize
## arrays using the field values yet. Luckily one of the test files only has a single
## field to be joined.

## Run as: awk -f fullouterjoin.awk test1.txt test2.txt test1.txt test2.txt | column -t

## Process first file of arguments the first time. This file has more args.
FILENAME=="test1.txt" && NR==FNR {   
    if ( FNR == 1 ) {
        header = $2
        next
    }
    hash1[ $1 ] = 1
    LR_F1=FNR
    next
}

## Process second file of arguments the first time. Save 'id' as key and 'No' a hash.
FILENAME=="test2.txt" && NR-LR_F1==FNR {
    hash2[ $1 ] = $2
    LR_F2=FNR
    next
}

## Process first file of arguments the second time. Print header in first line and for
## the rest check if first field is found in the hash.
FNR == (NR - LR_F1 - LR_F2) {
    if ( $1 in hash2 ) { 
        printf "%s %s %s %s %s\n", $1, hash2[ $1 ], $2, $3, $4
    } else {
        printf "%s %s %s %s %s\n", $1, "null", $2, $3, $4
    }
}

## Process second file of arguments the second time. Check if the first field is found 
## in the hash.
FNR < (NR - LR_F1 - LR_F2) {
    if ( $1 in hash1 || FNR == 1 ) {
        next
    } else {
        printf "%s %s %s %s\n", $0, "null", "null", "null"
    }
}
