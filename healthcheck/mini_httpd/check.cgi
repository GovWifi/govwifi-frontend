#!/bin/sh

#
# Simple CGI script to run eapol test
# return 200 on success, 500 on failure
#

CONF_FILE="/healthcheck/peap-mschapv2.conf.erb"
CONF_FILE_TEMP="/tmp/peap-mschapv2.conf.erb"
OUTPUT_TEMP="/tmp/check.out"

cat ${CONF_FILE}        \
    | sed "s/<.= ssid .>/${HEALTH_CHECK_SSID}/" \
    | sed "s/<.= identity .>/${HEALTH_CHECK_IDENTITY}/" \
    | sed "s/<.= password .>/${HEALTH_CHECK_PASSWORD}/" > ${CONF_FILE_TEMP}

/sbin/eapol_test -r0 -t3 -c ${CONF_FILE_TEMP} -a 127.0.0.1 -s "${HEALTH_CHECK_RADIUS_KEY}" > ${OUTPUT_TEMP} 2>&1

echo "Content-Type: text/plain"
if [ "$?" == "0" ]; then
    echo "Status: 200"
    echo
    cat ${OUTPUT_TEMP}
    exit
fi

echo "Status: 500" 
echo
cat ${OUTPUT_TEMP}

exit
