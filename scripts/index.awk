#!/usr/bin/awk
#
# Add index numbers to text data.

BEGIN {
    if (FS ~ /\[\[:space:\]\]\{2.\}/) {
        FS = "  "
        space_fs = 1
    }
    else if (FS ~ /\[.+\]/) {
        FS = " "
        space_fs = 1
    }
    else if (FS ~ /^\\ /) {
        FS = "  "
        space_fs = 1
    }
    else {
        FS = Escape(FS);
    }

    space = space_fs && !pipeout
    start_mod = header - 1
  
    if (ARGV[1]) { "wc -l < \""ARGV[1]"\"" | getline max_nr; max_nr+=0 }
}

{
    if (index_cols && NR < 2) {
        PrintFormattedIndex("", space, max_nr)
    
        for (f_i = 1; f_i <= NF; f_i++)
            printf "%s", FS f_i
    
        print ""
    }

    i = NR - start_mod
    PrintFormattedIndex(i, space, max_nr)
    print FS $0
}

END {
    if (!NR) exit 1
}

function PrintFormattedIndex(_index, space, max) {
    if (space) {
        len_max = max ? length(max) : 6
        format_str = "%"len_max"s"
        printf format_str, _index
    }
    else {
        printf _index
    }
}

