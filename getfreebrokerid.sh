#!/bin/bash

# contacts zookeeper to get all active brokers
# and tries to get the next free brokerid starting from 1
# to reaquire previously shutdown broker sessions


export BROKERIDS=$(/opt/zookeeper/bin/zkCli.sh -server ${KAFKA_ZOOKEEPER_CONNECT} <<< 'ls /brokers/ids' | tail -2 | head -n1 )
export BROKERIDS=${BROKERIDS//[!0-9 ]/}


ID_ARRAY=()
for ID in $BROKERIDS
do
  ID_ARRAY+=($ID)
done


for i in {1..1000}
do
  MARKER=0
  for z in "${ID_ARRAY[@]}"
  do
    if [ "$i" -eq "$z" ] ; then
      MARKER=1
    fi
  done
  if [ "$MARKER" -eq "0" ]
  then
    echo "$i"
    export KAFKA_BROKER_ID=$i
    break
  fi
done
