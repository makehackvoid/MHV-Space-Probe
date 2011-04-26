#!/bin/sh

email=`cat /dev/stdin`
#echo "Message"
#echo "$email"
while ! echo "$email" | /usr/sbin/ssmtp "$@"; do
	echo "Failed to send email, sleeping to try again..."
	sleep 60
done



