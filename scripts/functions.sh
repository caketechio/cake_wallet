#!/bin/bash

detect_sed() {
    if sed --version 2>/dev/null | grep -q "GNU"; then
        SED_TYPE="GNU"
    else
        SED_TYPE="BSD"
    fi
}

universal_sed() {
    local expression=$1
    local file=$2

    if [[ "$SED_TYPE" == "GNU" ]]; then
        sed -i "$expression" "$file"
    else
        sed -i '' "$expression" "$file"
    fi
}

detect_sed

if [[ "$(uname)" == "Linux" ]];
then
    export MAKE_JOB_COUNT="$(expr $(printf '%s\n%s' $(( $(grep MemTotal: /proc/meminfo | cut -d: -f2 | cut -dk -f1) * 4 / (1048576 * 9) )) $(nproc) | sort -n | head -n1) '|' 1)"
elif [[ "$(uname)" == "Darwin" ]];
then
    export MAKE_JOB_COUNT="$(expr $(printf '%s\n%s' $(( $(sysctl -n hw.memsize) * 4 / (1073741824 * 9) )) $(sysctl -n hw.logicalcpu) | sort -n | head -n1) '|' 1)"
else
    # Assume windows eh?
    export MAKE_JOB_COUNT="$(expr $(printf '%s\n%s' $(( $(grep MemTotal: /proc/meminfo | cut -d: -f2 | cut -dk -f1) * 4 / (1048576 * 9) )) $(nproc) | sort -n | head -n1) '|' 1)"
fi