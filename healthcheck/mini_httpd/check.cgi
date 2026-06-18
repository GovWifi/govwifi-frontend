#!/bin/sh

#
# Simple CGI script to run eapol test
# return 200 on success, 500 on failure
#

OUTPUT_TEMP="/tmp/check.out.$$"

/sbin/eapol_test -r0 -t3 -c /healthcheck/healthcheck.erb -a 127.0.0.1 -s "HEALTH_CHECK_RADIUS_KEY" > ${OUTPUT_TEMP} 2>&1

echo "Content-Type: text/plain"
if [ "$?" == "0" ]; then
    echo "Status: 200"
    echo
    cat ${OUTPUT_TEMP}
    rm ${OUTPUT_TEMP}
    exit
fi

echo "Status: 500" 
echo
cat ${OUTPUT_TEMP}
rm ${OUTPUT_TEMP}

exit
