IP=$1
FREQ=$2
T=`expr 3600 / $FREQ`
while true
do
	NUM=`(nmap -n -sP -T4 $1 | grep hosts | cut -d " " -s -f6 | cut -c2-)`
	DATE=`(date)`
	echo "" >> new.txt
	echo "HOSTS $NUM" >> new.txt
	echo "DATE $DATE" >> new.txt
	sleep $T
done      