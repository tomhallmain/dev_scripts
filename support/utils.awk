# Generic AWK utilities methods

function Max(a, b) {
    if (a > b) return a
    else if (a < b) return b
    else return a
}
function Min(a, b) {
    if (a > b) return b
    else if (a < b) return a
    else return a
}
function Trim(string) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", string)
    return string
}
function SetOFS(leave_escapes) {
    if (OFS ~ /\[\:.+\:\]\{/)
        OFS = "  "
    else if (OFS ~ /\[\:.+\:\]/)
        OFS = " "
    else if (!leave_escapes && OFS ~ "\\\\")
        OFS = Unescape(OFS)

    return OFS
}
function Escape(_string) {
    gsub(/[\\.^$(){}\[\]|*+?]/, "\\\\&", _string)
    return _string
}
function Unescape(_string,   i) {
    split(_string, StringTokens, "\\")
    _string = ""
  
    for (i = 1; i <= length(StringTokens); i++)
        _string = _string StringTokens[i]

    return _string
}
function EvalExpr(expr,   res,nm,a,s,m,d,u,e) {
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
