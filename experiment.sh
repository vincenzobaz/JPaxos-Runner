#!/bin/bash
log_folder="logs"

if [ ! -d $log_folder ]; then
	echo "Create directory to store logs"
	mkdir $log_folder
fi

# $1 address
function resetPM {
	curl "http://$1/reset"
}

# $1 address $2 label
function notifyPM {
	data="{\"time\": $(date +%s%3N), \"label\": \"$2\"}"
	curl --header "Content-Type: application/json" --request POST --data "$data" "http://$1/control-events" &> /dev/null &
}

function clearLog {
	if [ -f $1 ]; then
		echo "$1 exists, deleting it"
		rm $1
	fi
}

function kill_replica {
	echo "Killing replica $1"
	address="http://127.0.0.1:$((7000 + $1))/kill"
	res="$(curl -s -G $address)"
	echo "Replica replied $res"
}

function start_replica {
	echo "Starting replica $1"
	address="http://127.0.0.1:$((7000 + $1))/start"
	res="$(curl --max-time 60 --connect-timeout 60 -s -G $address)"
	#res="$(curl -s -G $address)"
	echo "Replica replied: $res"
}

function start_replicas {
	for i in `seq 0 $(($1 - 1))`; do
		start_replica $i
	done
}

function stop_replicas {
	for i in `seq 0 $(($1 - 1))`; do
		echo "Stopping replica $i"
		address="http://127.0.0.1:$((7000 + $i))/stop"
		res="$(curl -s -G $address)"
		echo "Replica replied: $res"
	done
}

function start_replica_managers {
	if [ ! -f ./Replica/target/scala-2.12/ReplicaManager.jar ]; then
		echo "ReplicaManager.jar does not exist, creating it"
		if [ -x sbt-client ]; then
			sbt-client "Replica / assembly"
		else
			sbt "Replica / assembly"
		fi
	fi

	for i in `seq 0 $(($1 - 1))`; do
		log="$log_folder/replica$i.out"
		clearLog $log
		# Listens on 7000 + i
		comm="./loop_replica.sh $i $2 $3 > $log 2>&1 &"
		eval $comm
	done
	echo "Starting replica managers"
}

function start_clients {
	if [ ! -f ./Client/target/scala-2.12/Spammer.jar ]; then
		echo "Spammer.jar does not exist, creating it"
		if [ -x sbt-client ]; then
			sbt-client "Client / assembly"
		else
			sbt "Client / assembly"
		fi
	fi

	for i in `seq 0 $(($1 - 1))`; do
		log="$log_folder/client$i.out"
		clearLog $log
		# Listens on 8000 + i, contacts Master @ 127.0.0.1:9090
		comm="java -jar Client/target/scala-2.12/Spammer.jar $2 $((8000 + $i)) $i $3 > $log 2>&1 &"
		echo $comm
		eval $comm
	done
}

function stop_clients {
	for i in `seq 0 $(($1 - 1))`; do
		echo "Stopping client $i"
		address="http://127.0.0.1:$((8000 + $i))/stop"
		res="$(curl -s -G $address)"
		echo "Client replied: $res"
	done
}

function clear_logs {
	rm -rf jpaxosLogs
	rm -rf $log_folder/*.out
}

function get_leader {
	address="http://127.0.0.1:$((7002))/status"
	res="$(curl -s -G $address)"
	echo "$res"
}

