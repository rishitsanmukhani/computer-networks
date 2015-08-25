while true
do
	NUM=`(nmap -n -sP -T4 10.205.156.0/23 | grep hosts | cut -d " " -s -f6 | cut -c2-)`
	DATE=`(date)`
	echo "   " >> out_kara.txt
	echo "HOSTS $NUM " >> out_kara.txt
	echo "DATE $DATE" >> out_kara.txt
	sleep 300
done