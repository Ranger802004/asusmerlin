#!/bin/sh

# Author: Ranger802004
# Version 1.0

# Cause the script to exit if errors are encountered
set -e
set -u

# Script Status
scriptstatus ()
{
# Checking if script is already running
 echo "Checking if $0 is already running..."
if [[ "$(echo $(ps | grep -v "grep" | grep -e "$0" | wc -l))" -gt "3" ]] >/dev/null; then
  echo "$0 is already running..."
else
setvariables
fi
}

# Set Variables
setvariables ()
{
SMTPSERVER="smtp.gmail.com"
SMTPPORT="587"
FROM="username@gmail.com"
AUTH="Username"
PASS="Password"
FROMNAME="$(nvram get ddns_hostname_x)"
TO="username@email.com"
CAFILE="/jffs/configs/google_root.pem"
TIMEOUT="30"

createemail
}

# Create Email
createemail ()
{
echo "Subject: $(nvram get ddns_hostname_x): WAN Event Notification" >/tmp/mail.txt
echo "From: \"$FROMNAME\"<$FROM>" >>/tmp/mail.txt
echo "Date: $(date -R)" >>/tmp/mail.txt
echo "" >>/tmp/mail.txt
echo "***WAN Event Notification***" >>/tmp/mail.txt
echo "----------------------------------------------------------------------------------------" >>/tmp/mail.txt
echo "Hostname: $(nvram get ddns_hostname_x)" >>/tmp/mail.txt
echo "Event Time: $(date "+%D @ %T")" >>/tmp/mail.txt
echo "System Uptime:$(uptime | cut -d ',' -f1 | sed 's/^.\{12\}//g')" >>/tmp/mail.txt
echo "Active ISP: $(curl ipinfo.io | grep -e "org" | awk '{print $3" "$4}' | cut -f 1 -d "," | cut -f 1 -d '"')" >>/tmp/mail.txt
echo "WAN IPv4 Address: $(nvram get wan_ipaddr)" >>/tmp/mail.txt
if [ ! -z "$(nvram get ipv6_wan_addr)" ] >/dev/null;then
echo "WAN IPv6 Address: $(nvram get ipv6_wan_addr)" >>/tmp/mail.txt
else
echo "WAN IPv6 Address: N/A" >>/tmp/mail.txt
fi
echo "WAN Gateway IP Address: $(nvram get wan_gateway)" >>/tmp/mail.txt
echo "WAN Interface: $(nvram get wan_ifname)" >>/tmp/mail.txt
if [ ! -z "$(nvram get wan_dns1_x)" ] >/dev/null;then
echo "DNS Server 1: $(nvram get wan_dns1_x)" >>/tmp/mail.txt
elif [ ! -z "$(echo $(nvram get wan_dns) | awk '{print $1}')" ] >/dev/null;then
echo "DNS Server 1: $(echo $(nvram get wan_dns) | awk '{print $1}')" >>/tmp/mail.txt
else
echo "DNS Server 1: N/A" >>/tmp/mail.txt
fi
if [ ! -z "$(nvram get wan_dns2_x)" ] >/dev/null;then
echo "DNS Server 2: $(nvram get wan_dns2_x)" >>/tmp/mail.txt
elif [ ! -z "$(echo $(nvram get wan_dns) | awk '{print $2}')" ] >/dev/null;then
echo "DNS Server 2: $(echo $(nvram get wan_dns) | awk '{print $2}')" >>/tmp/mail.txt
else
echo "DNS Server 2: N/A" >>/tmp/mail.txt
fi
if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null;then
echo "QoS Status: Enabled" >>/tmp/mail.txt
if [[ ! -z "$(nvram get qos_obw)" ]] && [[ ! -z "$(nvram get qos_obw)" ]] >/dev/null;then
echo "QoS Mode: Manual Settings" >>/tmp/mail.txt
echo "QoS Download Bandwidth: $(($(nvram get qos_ibw)/1024))Mbps" >>/tmp/mail.txt
echo "QoS Upload Bandwidth: $(($(nvram get qos_obw)/1024))Mbps" >>/tmp/mail.txt
echo "QoS WAN Packet Overhead: $(nvram get qos_overhead)" >>/tmp/mail.txt
else
echo "QoS Mode: Automatic Settings" >>/tmp/mail.txt
fi
else
echo "QoS Status: Disabled" >>/tmp/mail.txt
fi
echo "----------------------------------------------------------------------------------------" >>/tmp/mail.txt
echo "" >>/tmp/mail.txt

sendemail
}

# Send Email
sendemail ()
{
cat /tmp/mail.txt | sendmail -w $TIMEOUT -H "exec openssl s_client -quiet \
-CAfile $CAFILE \
-connect $SMTPSERVER:$SMTPPORT -tls1_3 -starttls smtp" \
-f"$FROM" \
-au"$AUTH" -ap"$PASS" $TO 

rm /tmp/mail.txt
}
scriptstatus