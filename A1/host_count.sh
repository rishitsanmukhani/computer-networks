while true
do
	NUM=`(nmap -n -sP -T4 10.251.216.0/23 | grep hosts | cut -d " " -s -f6 | cut -c2-)`
	DATE=`(date)`
	echo "" >> out.txt
	echo "HOSTS $NUM" >> out.txt
	echo "DATE $DATE" >> out.txt
	sleep 300
done