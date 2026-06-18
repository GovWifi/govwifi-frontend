#!/bin/sh

if [ -n "${ECS_CONTAINER_METADATA_URI}" ]; then
  export TASK_ID=$(echo $(curl $ECS_CONTAINER_METADATA_URI | jq -r '.Labels ."com.amazonaws.ecs.task-arn"') | tr "/" "\n" | tail -n 1)
fi

c_rehash /etc/raddb/certs/trusted_certificates

cd /healthcheck && bundle exec puma -p 3000 &
/usr/local/sbin/radiusd ${RADIUSD_PARAMS} &

# This is a test replacement for the ruby daemon running,
# simple cgi script http://localhost:4000/check.cgi
# running as unprivilaged user
# In reality the above should be replaced with this

# First create the conf file - readable only by the healthcheck script
# NOTE as the environment has the variables in that is little value in
# hiding these credentials
cat /healthcheck/peap-mschapv2.conf.erb  \
    | sed "s/<.= ssid .>/${HEALTH_CHECK_SSID}/" \
    | sed "s/<.= identity .>/${HEALTH_CHECK_IDENTITY}/" \
    | sed "s/<.= password .>/${HEALTH_CHECK_PASSWORD}/" > /healthcheck/healthcheck.erb
chown healthcheck:healthcheck /healthcheck/healthcheck.erb
chmod 0400 /healthcheck/healthcheck.erb

# Add the radius healthcheck key into script
sed -i "s/HEALTH_CHECK_RADIUS_KEY/${HEALTH_CHECK_RADIUS_KEY}/" /healthcheck/mini_httpd/check.cgi

# Start the mini server
/usr/sbin/mini_httpd -c '*.cgi' -d /healthcheck/mini_httpd -p 4000 -u healthcheck &

freeradius_exporter -web.listen-address 0.0.0.0:9812
