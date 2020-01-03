#!/bin/sh

IP=$(hostname -i)
echo ip=$IP

consul agent -bind=$IP -join $CONSUL_URL -data-dir /opt/consul-data  -config-dir /etc/consul.d &


# back to the real entrypoint - shouldn't be needed for kafka since dockerfile supports custom init sript
#/entrypoint.sh
