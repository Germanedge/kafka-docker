#!/bin/bash

# contacts zookeeper to get all active brokers
# and tries to get the next free brokerid starting from 1
# to reaquire previously shutdown broker sessions


# first check if there already is kafka-log-dir existing with correct meta-data

if [ -d "$KAFKA_LOG_DIRS" ]; then
  if [ -e "$KAFKA_LOG_DIRS/meta.properties" ]; then
    KAFKA_BROKER_ID=$(grep '^broker.id\=[0-9+]' $KAFKA_LOG_DIRS/meta.properties)
    export KAFKA_BROKER_ID=${KAFKA_BROKER_ID//[!0-9 ]/}
    if ! [[ $KAFKA_BROKER_ID =~ '^[0-9]+$' ]] ; then
      echo $KAFKA_BROKER_ID
      exit 0;
    fi
  fi
fi



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
