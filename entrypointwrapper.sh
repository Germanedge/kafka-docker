#!/bin/sh

IP=$(hostname -i)
echo ip=$IP

consul agent -bind=$IP -join $CONSUL_URL -data-dir /opt/consul-data  -config-dir /etc/consul.d &

filebeat -e -c /etc/filebeat/filebeat.yml -path.home /usr/share/filebeat -path.config /etc/filebeat -path.data /var/lib/filebeat -path.logs /var/log/filebeat &


# back to the real entrypoint - shouldn't be needed for kafka since dockerfile supports custom init sript
#/entrypoint.sh