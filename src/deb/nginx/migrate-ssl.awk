# The legacy panel config has one server block. Refuse ambiguous custom layouts.
/^[[:space:]]*server[[:space:]]*\{/ { servers++ }
/^[[:space:]]*listen[[:space:]]/ {
    listens++
    if ($0 !~ /;[[:space:]]*(#.*)?$/) invalid = 1
}
/^[[:space:]]*ssl[[:space:]]+(on|off)[[:space:]]*;/ { legacy++ }
{ lines[NR] = $0 }
END {
    if (legacy && (servers != 1 || listens == 0 || legacy != 1 || invalid)) {
        print "Convert the legacy panel SSL configuration to listen ... ssl manually." > "/dev/stderr"
        exit 1
    }
    for (i = 1; i <= NR; i++)
        if (lines[i] ~ /^[[:space:]]*ssl[[:space:]]+on[[:space:]]*;/) ssl = 1
    for (i = 1; i <= NR; i++) {
        line = lines[i]
        if (legacy && line ~ /^[[:space:]]*ssl[[:space:]]+(on|off)[[:space:]]*;/) continue
        if (ssl && line ~ /^[[:space:]]*listen[[:space:]]/ && line !~ /[[:space:]]ssl[[:space:];]/)
            sub(/[[:space:]]*;/, " ssl;", line)
        print line
    }
}
