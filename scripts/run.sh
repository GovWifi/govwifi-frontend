#!/bin/sh

if [ -n "${ECS_CONTAINER_METADATA_URI}" ]; then
  export TASK_ID=$(echo $(curl $ECS_CONTAINER_METADATA_URI | jq -r '.Labels ."com.amazonaws.ecs.task-arn"') | tr "/" "\n" | tail -n 1)
fi

GOVLOGGER_FILE="/healthcheck/govlogs.log"

if [ "x${GOVLOGGER_LOG_PROG_COMMAND}" == "x" ]; then
    GOVLOGGER_LOG_PROG_COMMAND="/usr/bin/process_gov_logs --pretty --canonical --state /healthcheck/statefile --expires 30 --reduce_duplicates --reduce_freeradius_proxied --reduce_last_date_only --reduce_drop_eap_peap --wait 6 --logfile ${GOVLOGGER_FILE} >> /healthcheck/reduced_logs.out 2>>/healthcheck/process_gov_logs.err"
fi

export GOVLOGGER_FILE
export GOVLOGGER_LOG_PROG_COMMAND

c_rehash /etc/raddb/certs/trusted_certificates

cd /healthcheck && bundle exec puma -p 3000 &
/usr/local/sbin/radiusd ${RADIUSD_PARAMS} &
freeradius_exporter -web.listen-address 0.0.0.0:9812
