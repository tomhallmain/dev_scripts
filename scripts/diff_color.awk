#!/usr/bin/awk
#
# Use-specific script to color output of Unix diff
# with side-by-side format
#
# > tty_size=$(tput cols)
# > let tty_half=$tty_size/2
# > diff -b -y -W $tty_size file1 file2 | expand \
#     | awk -f diff_color.awk -v tty_half=$tty_half

BEGIN {
    bdiff = " \\|( |$)"
    ldiff = " <$"
    rdiff = " > "

    red = "\033[1;31m"
    cyan = "\033[1;36m"
    mag = "\033[1;35m"
    coloroff = "\033[0m"
    
    left_n_chars = tty_half - 2
    diff_start = tty_half - 1
    right_start = tty_half + 2
    
    if (tty_half % 2 == 0) {
        left_n_chars -= 1
        diff_start -= 1
        right_start -= 1
    }
}

{
    coloron = 0
    left = substr($0, 0, left_n_chars)
    diff = substr($0, diff_start, 3)
    right = substr($0, right_start)

    # If only one side is diff, color all, else color diff chars

    if (diff ~ ldiff) {
        print cyan $0 coloroff
    }
    else if (diff ~ rdiff) {
        print red $0 coloroff
    }
    else if (diff ~ bdiff) {
        split(left, lchars, "")
        split(right, rchars, "")
        l_len = length(lchars)
        r_len = length(rchars)
        j = 1
        recap = 0
        recaps = 0
        
        for (i = 1; i <= l_len; i++) {
            if (lchars[i] == rchars[j]) {
                if (coloron) {
                    coloron = 0
                    printf coloroff
                }
                j++
            }
            else {
                if (recap) recap = 0
                tmp_j = j
                for (k = j; k <= l_len; k++) { #TODO: May want to refactor using substr
                    mtch = lchars[i] == rchars[k]
                    mtch1 = lchars[i+1] == rchars[k+1]
                    mtch2 = lchars[i+2] == rchars[k+2]
                    mtch3 = lchars[i+3] == rchars[k+3]
                    if (mtch && mtch1 && mtch2 && mtch3) {
                        recap = 1
                        recaps++
                        j = k + recaps
                        coloron = 0
                        printf coloroff
                        break
                    }
                    j = tmp_j
                }
                if (!recap && !coloron) {
                    printf cyan
                    coloron = 1
                }
            }
            printf "%s", lchars[i]
        }

        printf mag diff coloroff

        j = 1
        recap = 0
        recaps = 0
        for (i=1; i <= r_len; i++) {
            if (rchars[i] == lchars[j]) {
                if (coloron) {
                    coloron = 0
                    printf coloroff
                }
                j++
            }
            else {
                if (recap) recap = 0
                tmp_j = j
                for (k = j; k <= r_len; k++) {
                    mtch = rchars[i] == lchars[k]
                    mtch1 = rchars[i+1] == lchars[k+1]
                    mtch2 = rchars[i+2] == lchars[k+2]
                    mtch3 = rchars[i+3] == lchars[k+3]
                    if (mtch && mtch1 && mtch2 && mtch3) {
                        recap = 1
                        recaps++
                        j = k + recaps
                        coloron = 0
                        printf coloroff
                        break
                    }
                    j = tmp_j
                }

                if (!recap && !coloron) {
                    coloron = 1
                    printf red
                }
            }
            printf "%s", rchars[i]
        }

        print ""

    } else {
        print coloroff $0
    }
}

