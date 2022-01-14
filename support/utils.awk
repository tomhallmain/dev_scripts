# Generic AWK utilities methods

function SeedRandom()
{
    "date +%s%3N" | getline date; srand(date)
}
function Max(a, b)
{
    if (a > b) return a
    else if (a < b) return b
    else return a
}
function Min(a, b)
{
    if (a > b) return b
    else if (a < b) return a
    else return a
}
function Trim(string)
{
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", string)
    return string
}
function SetOFS(leave_escapes)
{
    if (OFS ~ /\[\:.+\:\]\{/)
        OFS = "  "
    else if (OFS ~ /\[\:.+\:\]/)
        OFS = " "
    else if (!leave_escapes && OFS ~ "\\\\")
        OFS = Unescape(OFS)

    return OFS
}
function Escape(_string)
{
    gsub(/[\\.^$(){}\[\]|*+?]/, "\\\\&", _string)
    return _string
}
function Unescape(_string,   i)
{
    split(_string, StringTokens, "\\")
    _string = ""
  
    for (i = 1; i <= length(StringTokens); i++)
        _string = _string StringTokens[i]

    return _string
}
# Escape FS string only if not a regular expression or already well formed
function EscapePreserveRegex(_fs)
{
    fs_copy = _fs
    if (gsub(/[\\.^$(){}\[\]|*+?]/, "", fs_copy) == length(_fs)) {
        return Escape(_fs)
    }

    return _fs
}
function EvalExpr(expr,   res,nm,a,s,m,d,u,e)
{
    res = 0
    nm = gsub(/\*-/, "*", expr)
    nm += gsub(/\/-/, "/", expr)
    gsub(/--/, "+", expr)
    split(expr, a, "+")
  
    for(_a_i in a) {
        split(a[_a_i], s, "-")
        
        for(_s_i in s) {
            split(s[_s_i], m, "*")
            
            for(_m_i in m) {
                split(m[_m_i], d, "/")
                
                for(_d_i in d) {
                    split(d[_d_i], u, "%")
                    
                    for(_u_i in u) {
                        split(u[_u_i], e, "(\\^|\\*\\*)")
                        
                        for(_e_i in e) {
                            if (_e_i > 1) e[1] = e[1] ** e[_e_i]
                        }
                        
                        u[_u_i] = e[1]
                        delete e
                        if (_u_i > 1) u[1] = u[1] % u[_u_i]
                    }
                    
                    d[_d_i] = u[1]
                    delete u
                    if (_d_i > 1) d[1] /= d[_d_i]
                }
                
                m[_m_i] = d[1]
                delete d
                if (_m_i > 1) m[1] *= m[_m_i]
            }
            
            s[_s_i] = m[1]
            delete m
            if (_s_i > 1) s[1] -= s[_s_i]
        }
        
        a[_a_i] = s[1]
        delete s
    }

    for (_a_i in a) {
        res += a[_a_i]
    }
  
    return nm % 2 ? -res : res
}
function PrintMap(_Map, print_mode)
{
    _array_len = length(_Map)
    _print_counter = 0
    printf "%s", "[ "
    
    if (print_mode > 0) {
        for (_key in _Map) {
            printf "%s", "\""_key"\""
            if (++_print_counter < _array_len) {
                printf "%s", ","
            }
            printf "%s", " "
        }
    }
    else if (print_mode == 0) {
        for (_key in _Map) {
            printf "%s", "\""_key"\":\""_Map[_key]"\""
            if (++_print_counter < _array_len) {
                printf "%s", ","
            }
            printf "%s", " "
        }
    }
    else {
        for (_key in _Map) {
            printf "%s", "\""_Map[_key]"\""
            if (++_print_counter < _array_len) {
                printf "%s", ","
            }
            printf "%s", " "
        }
    }
    
    print "]"
}
function QSA(A,left,right,    i,last)
{
    if (left >= right) return

    S(A, left, left + int((right-left+1)*rand()))
    last = left

    for (i = left+1; i <= right; i++)
        if (A[i] < A[left])
            S(A, ++last, i)

    S(A, left, last)
    QSA(A, left, last-1)
    QSA(A, last+1, right)
}
function QSAN(A,left,right,    i,last)
{
    if (left >= right) return

    S(A, left, left + int((right-left+1)*rand()))
    last = left

    for (i = left+1; i <= right; i++) {
        if (GetN(A[i]) < GetN(A[left])) {
            S(A, ++last, i)
        }
        else if (GetN(A[i]) == GetN(A[left]) && NExt[A[i]] < NExt[A[left]]) {
            S(A, ++last, i)
        }
    }

    S(A, left, last)
    QSAN(A, left, last-1)
    QSAN(A, last+1, right)
}
function QSD(A,left,right,    i,last)
{
    if (left >= right) return

    S(A, left, left + int((right-left+1)*rand()))
    last = left

    for (i = left+1; i <= right; i++)
        if (A[i] > A[left])
            S(A, ++last, i)

    S(A, left, last)
    QSD(A, left, last-1)
    QSD(A, last+1, right)
}
function QSDN(A,left,right,    i,last)
{
    if (left >= right) return

    S(A, left, left + int((right-left+1)*rand()))
    last = left

    for (i = left+1; i <= right; i++) {
        if (GetN(A[i]) > GetN(A[left])) {
            S(A, ++last, i)
        }
        else if (GetN(A[i]) == GetN(A[left]) && NExt[A[i]] > NExt[A[left]]) {
            S(A, ++last, i)
        }
    }

    S(A, left, last)
    QSDN(A, left, last-1)
    QSDN(A, last+1, right)
}
function S(A,i,j,t) {
    t = A[i]; A[i] = A[j]; A[j] = t
    t = ___[i]; ___[i] = ___[j]; ___[j] = t
}


