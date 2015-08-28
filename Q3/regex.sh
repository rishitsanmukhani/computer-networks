if [ "$#" -ne 2 ]; then
	echo "Usage: sh regex.sh <input> <output>"
	exit 1
fi
inp=$1;
out=$2;
cat $inp | grep -oP "(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])" > $out