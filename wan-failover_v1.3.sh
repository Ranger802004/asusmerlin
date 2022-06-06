#!/bin/sh

# WAN Failover for ASUS Routers using Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 05/22/2022
# Version: v1.3

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
CONFIGFILE="/jffs/configs/wan-failover.conf"
LOGPATH="/tmp/wan_event.log"
LOGNUMBER="1000"
WANPREFIXES="wan0 wan1"
NOCOLOR="\033[0m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;94m"
WHITE="\033[0;37m"

# Set Script Mode
if [ -z "$(echo ${1#})" ] >/dev/null;then
echo -e "${RED}${0##*/} - Executed without a Run Mode Selected!!!${NOCOLOR}"
echo -e "${WHITE}Use one of the following run modes...${NOCOLOR}"
echo -e "${BLUE}$0 install${WHITE} - This will install the script and configuration files necessary for it to run.${NOCOLOR}"
echo -e "${GREEN}$0 run${WHITE} - This mode is for the script to run in the background via cron job.${NOCOLOR}"
echo -e "${GREEN}$0 manual${WHITE} - This will allow you to run the script in a command console.${NOCOLOR}"
echo -e "${GREEN}$0 monitor${WHITE} - This will monitor the log file of the script.${NOCOLOR}"
echo -e "${YELLOW}$0 cronjob${WHITE} - This will kill any running instances of the script.${NOCOLOR}"
echo -e "${YELLOW}$0 logclean${WHITE} - This will clean the log file leaving only the last 1000 messages.${NOCOLOR}"
echo -e "${RED}$0 uninstall${WHITE} - This will uninstall the configuration files necessary to stop the script from running.${NOCOLOR}"
echo -e "${RED}$0 kill${WHITE} - This will create the Cron Jobs necessary for the script to run and also perform log cleaning.${NOCOLOR}"
exit
else
mode="${1#}"
continue
fi
scriptmode ()
{
if [[ "${mode}" == "install" ]] >/dev/null;then
  echo -e "${BLUE}${0##*/} - Install mode...${NOCOLOR}"
install
elif [[ "${mode}" == "run" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Run Mode${NOCOLOR}"
scriptstatus
elif [[ "${mode}" == "manual" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Manual Mode${NOCOLOR}"
scriptstatus
elif [[ "${mode}" == "monitor" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Monitor Mode${NOCOLOR}"
monitor
elif [[ "${mode}" == "kill" ]] >/dev/null;then 
  echo -e "${RED}${0##*/} - Kill Mode${NOCOLOR}"
kill
elif [[ "${mode}" == "uninstall" ]] >/dev/null;then 
  echo -e "${RED}${0##*/} - Uninstall Mode${NOCOLOR}"
uninstall
elif [[ "${mode}" == "cron" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Cron Job Mode${NOCOLOR}"
cronjob
elif [[ "${mode}" == "logclean" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Log Clean Mode${NOCOLOR}"
logclean
else
continue
fi
if [[ ! -f "$CONFIGFILE" ]] >/dev/null;then
  echo -e "${RED}${0##*/} - No Configuration File Detected - Run Install Mode${NOCOLOR}"
else
continue
exit
fi
}

# Install
install ()
{
# Check if JFFS Custom Scripts is enabled
if [[ "$(nvram get jffs2_scripts)" != "1" ]] >/dev/null;then
  echo -e "${RED}Warning!!!  Administration > System > Enable JFFS custom scripts and configs is not enabled.${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: Warning!!!  Administration > System > Enable JFFS custom scripts and configs is not enabled." >> $LOGPATH
else
  echo -e "${GREEN}Administration > System > Enable JFFS custom scripts and configs is enabled...${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: Administration > System > Enable JFFS custom scripts and configs is enabled..." >> $LOGPATH
fi

# Check for Config File
  echo -e "${BLUE}Creating $CONFIGFILE...${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: Creating $CONFIGFILE..." >> $LOGPATH
if [ ! -f $CONFIGFILE ] >/dev/null;then
touch -a $CONFIGFILE
chmod 666 $CONFIGFILE
  echo -e "${GREEN}$CONFIGFILE created.${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: $CONFIGFILE created." >> $LOGPATH
else
  echo -e "${YELLOW}$CONFIGFILE already exists...${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: $CONFIGFILE already exists..." >> $LOGPATH
fi

echo "Setting Custom Variables..."
  echo -e "${YELLOW}***WAN Target IP Addresses will be routed via WAN Gateway dev WAN Interface***${NOCOLOR}"
read -p "Set WAN0 Target IP Address - Will be routed via $(nvram get wan0_gateway) dev $(nvram get wan0_ifname): " SETWAN0TARGET
read -p "Set WAN1 Target IP Address - Will be routed via $(nvram get wan1_gateway) dev $(nvram get wan1_ifname): " SETWAN1TARGET
read -p "Set Ping Count - WAN Failure will be triggered after this many failed ping requests: " SETPINGCOUNT
read -p "Set Ping Timeout - Value is in seconds: " SETPINGTIMEOUT
read -p "Set WAN Disabled Timer - This is how long the script will sleep if Dual WAN/Failover Mode/WAN Links are disabled before checking status again, value is in seconds: " SETWANDISABLEDSLEEPTIMER
  echo -e "${WHITE}***QoS Bandwidth Settings Reference Guide - ${BLUE}1Gbps: 1048576, 500Mbps: 512000 , 250Mbps: 256000, 100Mbps: 102400, 50Mbps: 51200, 25Mbps: 25600, 10Mbps: 10240***${NOCOLOR}"
read -p "Set WAN0 QoS Download Bandwidth - Value is in Kbps: " SETWAN0_QOS_IBW
read -p "Set WAN1 QoS Download Bandwidth - Value is in Kbps: " SETWAN1_QOS_IBW
read -p "Set WAN0 QoS Upload Bandwidth - Value is in Kbps: " SETWAN0_QOS_OBW
read -p "Set WAN1 QoS Upload Bandwidth - Value is in Kbps: " SETWAN1_QOS_OBW
  echo -e "${WHITE}***QoS WAN Packet Overhead Reference Guide - ${BLUE}None: 0, Conservative Default: 48, VLAN: 42, DOCSIS: 18, PPPoE VDSL: 27, ADSL PPPoE VC: 32, ADSL PPPoE LLC: 40, VDSL Bridged: 19, VDSL2 PPPoE: 30, VDSL2 Bridged: 22***${NOCOLOR}"
read -p "Set WAN0 QoS WAN Packet Overhead - Value is in Bytes: " SETWAN0_QOS_OVERHEAD
read -p "Set WAN1 QoS WAN Packet Overhead - Value is in Bytes: " SETWAN1_QOS_OVERHEAD
  echo -e "${WHITE}***QoS ATM Reference Guide - ${BLUE}Recommended is Disabled unless using ISDN***${NOCOLOR}"
read -p "Set WAN0 QoS ATM - Enabled: 1 Disabled: 0: " SETWAN0_QOS_ATM
read -p "Set WAN1 QoS ATM - Enabled: 1 Disabled: 0: " SETWAN1_QOS_ATM

NEWVARIABLES='
WAN0TARGET=|'$SETWAN0TARGET'
WAN1TARGET=|'$SETWAN1TARGET'
PINGCOUNT=|'$SETPINGCOUNT'
PINGTIMEOUT=|'$SETPINGTIMEOUT'
WANDISABLEDSLEEPTIMER=|'$SETWANDISABLEDSLEEPTIMER'
WAN0_QOS_IBW=|'$SETWAN0_QOS_IBW'
WAN1_QOS_IBW=|'$SETWAN1_QOS_IBW'
WAN0_QOS_OBW=|'$SETWAN0_QOS_OBW'
WAN1_QOS_OBW=|'$SETWAN1_QOS_OBW'
WAN0_QOS_OVERHEAD=|'$SETWAN0_QOS_OVERHEAD'
WAN1_QOS_OVERHEAD=|'$SETWAN1_QOS_OVERHEAD'
WAN0_QOS_ATM=|'$SETWAN0_QOS_ATM'
WAN1_QOS_ATM=|'$SETWAN1_QOS_ATM'
'
# Adding Custom Variables to Config File
  echo -e "${BLUE}Adding Custom Settings to $CONFIGFILE...${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: Adding Custom Settings to $CONFIGFILE..." >> $LOGPATH
for NEWVARIABLE in ${NEWVARIABLES};do
if [ -z "$(cat $CONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ] >/dev/null;then
  echo "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" >> $CONFIGFILE
sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
else
sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
fi
done
  echo -e "${GREEN}Custom Variables added to $CONFIGFILE.${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: Custom Variables added to $CONFIGFILE." >> $LOGPATH

# Add Script to Wan-event
  echo -e "${BLUE}Creating Wan-Event script...${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: Creating Wan-Event script..." >> $LOGPATH
if [ ! -f "/jffs/scripts/wan-event" ] >/dev/null;then
touch -a /jffs/scripts/wan-event
chmod 755 /jffs/scripts/wan-event
echo "#!/bin/sh" >> /jffs/scripts/wan-event
  echo -e "${GREEN}Wan-Event script has been created.${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: Wan-Event script has been created." >> $LOGPATH
else
  echo -e "${YELLOW}Wan-Event script already exists...${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: Wan-Event script already exists..." >> $LOGPATH
continue
fi
if [ ! -z "$(cat /jffs/scripts/wan-event | grep -e "# Wan-Failover")" ] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} already added to Wan-Event...${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: ${0##*/} already added to Wan-Event..." >> $LOGPATH
else
cmdline="sh $0 cron"
  echo -e "${BLUE}Adding ${0##*/} to Wan-Event...${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: Adding ${0##*/} to Wan-Event..." >> $LOGPATH
  echo "$cmdline # Wan-Failover" >> /jffs/scripts/wan-event
  echo -e "${GREEN}${0##*/} added to Wan-Event.${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Install: ${0##*/} added to Wan-Event." >> $LOGPATH
fi

# Create Initial Cron Jobs
sh "$0" cron

exit
}

# Uninstall
uninstall ()
{
# Remove Cron Jobs
if [ ! -z "$(crontab -l | grep -e "setup_wan_failover_run")" ] >/dev/null; then
  echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job for Run Mode...${NOCOLOR}"
cru d setup_wan_failover_run
  echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job for Run Mode.${NOCOLOR}"
else
continue
fi
if [ ! -z "$(crontab -l | grep -e "setup_wan_failover_logclean")" ] >/dev/null; then
  echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job for Log Clean Mode...${NOCOLOR}"
cru d setup_wan_failover_logclean
  echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job for Log Clean Mode.${NOCOLOR}"
else
continue
fi

# Check for Config File
  echo -e "${BLUE}${0##*/} - Uninstall: Deleting $CONFIGFILE...${NOCOLOR}"
if [ -f $CONFIGFILE ] >/dev/null;then
rm -f $CONFIGFILE
  echo -e "${GREEN}${0##*/} - Uninstall: $CONFIGFILE deleted.${NOCOLOR}"
else
  echo -e "${RED}${0##*/} - Uninstall: $CONFIGFILE doesn't exist.${NOCOLOR}"
fi

# Check for Log File
  echo -e "${BLUE}${0##*/} - Uninstall: Deleting $LOGPATH...${NOCOLOR}"
if [ -f $LOGPATH ] >/dev/null;then
rm -f $LOGPATH
  echo -e "${GREEN}${0##*/} - Uninstall: $LOGPATH deleted.${NOCOLOR}"
else
  echo -e "${RED}${0##*/} - Uninstall: $LOGPATH doesn't exist.${NOCOLOR}"
fi

# Remove Script from Wan-event
cmdline="sh $0 cron"
if [ ! -z "$(cat /jffs/scripts/wan-event | grep -e "^$cmdline")" ] >/dev/null;then 
  echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from Wan-Event...${NOCOLOR}"
sed -i '\~# Wan-Failover~d' /jffs/scripts/wan-event
  echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from Wan-Event.${NOCOLOR}"
else
  echo -e "${RED}${0##*/} - Uninstall: Cron Job doesn't exist in Wan-Event.${NOCOLOR}"
continue
fi

# Restart WAN Interfaces
if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_state_t)" == "2" ]] >/dev/null;then
  echo -e "${YELLOW}${0##*/} - Uninstall: Restarting interface $(echo $WANPREFIXES | awk '{print $1}')${NOCOLOR}"
nvram set "$(echo $WANPREFIXES | awk '{print $1}')"_state_t=0
service "restart_wan_if 0"
  echo -e "${GREEN}${0##*/} - Uninstall: Restarted interface $(echo $WANPREFIXES | awk '{print $1}')${NOCOLOR}"
else
continue
fi

if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_state_t)" == "2" ]] >/dev/null;then
  echo -e "${YELLOW}${0##*/} - Uninstall: Restarting interface $(echo $WANPREFIXES | awk '{print $2}')${NOCOLOR}"
nvram set "$(echo $WANPREFIXES | awk '{print $2}')"_state_t=0
service "restart_wan_if 1"
  echo -e "${GREEN}${0##*/} - Uninstall: Restarted interface $(echo $WANPREFIXES | awk '{print $2}')${NOCOLOR}"
else
continue
fi

# Kill Running Processes
echo -e "${RED}Killing ${0##*/}...${NOCOLOR}"
sleep 3 && killall ${0##*/}
exit
}

# Kill Script
kill ()
{
echo -e "${RED}Killing ${0##*/}...${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Kill: Killing ${0##*/}..." >> $LOGPATH
sleep 3 && killall ${0##*/}
exit
}

# Script Status
scriptstatus ()
{
# Checking if script is already running
 echo -e "${BLUE}Checking if ${0##*/} is already running..."${NOCOLOR}
if [[ "${mode}" == "manual" ]] >/dev/null;then 
setvariables
elif [[ "$(echo $(ps | grep -v "grep" | grep -e "$0" | wc -l))" -gt "1" ]] >/dev/null; then
  echo -e "${RED}${0##*/} is already running...${NOCOLOR}"
else
setvariables
fi
}

# Cronjob
cronjob ()
{
if [ -z "$(crontab -l | grep -e "$0")" ] >/dev/null; then
  echo -e "${BLUE}Creating cron jobs...${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Cron: Creating cron jobs..." >> $LOGPATH
cru a setup_wan_failover_run "*/1 * * * *" $0 run
cru a setup_wan_failover_logclean "0 * * * *" $0 logclean
  echo -e "${GREEN}Completed creating cron job.${NOCOLOR}"
  echo "$(date "+%D @ %T"): $0 - Cron: Completed creating cron job." >> $LOGPATH
else
exit
fi
exit
}

# Monitor Logging
monitor ()
{
tail -f $LOGPATH
}

# Set Variables
setvariables ()
{
#DNS Resolver File
DNSRESOLVFILE="/tmp/resolv.conf"

#Ping Target for failure detections, must be routed over targeted interface
WAN0TARGET="$(cat $CONFIGFILE | grep -e "WAN0TARGET" | awk -F"=" '{print $2}')"
WAN1TARGET="$(cat $CONFIGFILE | grep -e "WAN1TARGET" | awk -F"=" '{print $2}')"

#Ping count before WAN is considered down, requires 100% Packet Loss.
PINGCOUNT="$(cat $CONFIGFILE | grep -e "PINGCOUNT" | awk -F"=" '{print $2}')"
#Ping timeout in seconds
PINGTIMEOUT="$(cat $CONFIGFILE | grep -e "PINGTIMEOUT" | awk -F"=" '{print $2}')"

# If Dual WAN is disabled, this is how long the script will sleep before checking again.  Value is in seconds
WANDISABLEDSLEEPTIMER="$(cat $CONFIGFILE | grep -e "WANDISABLEDSLEEPTIMER" | awk -F"=" '{print $2}')"

#QoS Manual Settings Variables
#QoS Inbound Bandwidth - Values are in Kbps
WAN0_QOS_IBW="$(cat $CONFIGFILE | grep -e "WAN0_QOS_IBW" | awk -F"=" '{print $2}')"
WAN1_QOS_IBW="$(cat $CONFIGFILE | grep -e "WAN1_QOS_IBW" | awk -F"=" '{print $2}')"
#QoS Outbound Bandwidth - Values are in Kbps
WAN0_QOS_OBW="$(cat $CONFIGFILE | grep -e "WAN0_QOS_OBW" | awk -F"=" '{print $2}')"
WAN1_QOS_OBW="$(cat $CONFIGFILE | grep -e "WAN1_QOS_OBW" | awk -F"=" '{print $2}')"
#QoS WAN Packet Overhead - Values are in Bytes
WAN0_QOS_OVERHEAD="$(cat $CONFIGFILE | grep -e "WAN0_QOS_OVERHEAD" | awk -F"=" '{print $2}')"
WAN1_QOS_OVERHEAD="$(cat $CONFIGFILE | grep -e "WAN1_QOS_OVERHEAD" | awk -F"=" '{print $2}')"
#QoS Enable ATM
WAN0_QOS_ATM="$(cat $CONFIGFILE | grep -e "WAN0_QOS_ATM" | awk -F"=" '{print $2}')"
WAN1_QOS_ATM="$(cat $CONFIGFILE | grep -e "WAN1_QOS_ATM" | awk -F"=" '{print $2}')"

# Services to Restart (single quote at the beginning and end of the list):
SERVICES='
qos
leds
dnsmasq
firewall
'
wanstatus
}

# WAN Status
wanstatus ()
{
# Check Current Status of Dual WAN Mode
if { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] && [[ "$(nvram get wans_mode)" != "fo" ]] ;} >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - Dual WAN Failover Mode: Disabled" >> $LOGPATH
wandisabled
# Check if ASUS Factory WAN Failover is Enabled
elif [[ "$(nvram get wandog_enable)" != "0" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - Dual WAN Failover ASUS Factory Watchdog: Enabled" >> $LOGPATH
wandisabled
# Check if WAN0 or WAN1 is Enabled
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] || [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] >/dev/null;then
for WANPREFIX in ${WANPREFIXES};do
if [[ "$(nvram get "${WANPREFIX}"_enable)" == "0" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} disabled..." >> $LOGPATH
if [[ "${WANPREFIX}" == "wan0" ]] >/dev/null;then
WAN0STATUS="DISABLED"
elif [[ "${WANPREFIX}" == "wan1" ]] >/dev/null;then
WAN1STATUS="DISABLED"
fi
elif [[ "$(nvram get "${WANPREFIX}"_enable)" == "1" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} enabled..." >> $LOGPATH
# Check WAN0 Connection
if [[ "${WANPREFIX}" == "wan0" ]] >/dev/null;then
if [[ "$(nvram get "${WANPREFIX}"_state_t)" != "2" ]] || { [[ "$(nvram get "${WANPREFIX}"_realip_state)" != "2" ]] && [ -z "$(nvram get "${WANPREFIX}"_realip_ip)" ] ;} >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} is not connected, attempting to restart interface..." >> $LOGPATH
service "restart_wan_if 0"
sleep 3
elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] || { [[ "$(nvram get "${WANPREFIX}"_realip_state)" == "2" ]] || [ ! -z "$(nvram get "${WANPREFIX}"_realip_ip)" ] ;} >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} is connected..." >> $LOGPATH
else
wandisabled
fi
if [ -z "$(ip route list $WAN0TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname))" ] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Status: Creating route $WAN0TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname)..." >> $LOGPATH
ip route add $WAN0TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname)
  echo "$(date "+%D @ %T"): $0 - WAN Status: Created route $WAN0TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname)." >> $LOGPATH
else
  echo "$(date "+%D @ %T"): $0 - WAN Status: Route exists for $WAN0TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname)..." >> $LOGPATH
fi
WAN0PACKETLOSS="$(ping -I $(nvram get ${WANPREFIX}_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} has $WAN0PACKETLOSS packet loss..." >> $LOGPATH
WAN0STATUS="CONNECTED"
else
  echo "$(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} has $WAN0PACKETLOSS packet loss..." >> $LOGPATH
WAN0STATUS="DISCONNECTED"
fi
# Check WAN1 Connection
elif [[ "${WANPREFIX}" == "wan1" ]] >/dev/null;then
if [[ "$(nvram get "${WANPREFIX}"_state_t)" != "2" ]] || { [[ "$(nvram get "${WANPREFIX}"_realip_state)" != "2" ]] && [ -z "$(nvram get "${WANPREFIX}"_realip_ip)" ] ;} >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} is not connected, attempting to restart interface..." >> $LOGPATH
service "restart_wan_if 1"
sleep 3
elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] || { [[ "$(nvram get "${WANPREFIX}"_realip_state)" == "2" ]] || [ ! -z "$(nvram get "${WANPREFIX}"_realip_ip)" ] ;} >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} is connected..." >> $LOGPATH
else
wandisabled
fi
if [ -z "$(ip route list $WAN1TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname))" ] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Status: Creating route $WAN1TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname)..." >> $LOGPATH
ip route add $WAN1TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname)
  echo "$(date "+%D @ %T"): $0 - WAN Status: Created route $WAN1TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname)." >> $LOGPATH
else
  echo "$(date "+%D @ %T"): $0 - WAN Status: Route exists for $WAN1TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname)..." >> $LOGPATH
fi
WAN1PACKETLOSS="$(ping -I $(nvram get ${WANPREFIX}_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
if [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} has $WAN1PACKETLOSS packet loss..." >> $LOGPATH
WAN1STATUS="CONNECTED"
else
  echo "$(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} has $WAN1PACKETLOSS packet loss..." >> $LOGPATH
WAN1STATUS="DISCONNECTED"
fi
fi
fi
done
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
wandisabled
fi
if [[ "$WAN0STATUS" == "DISABLED" ]] && { [[ "$WAN1STATUS" == "DISABLED" ]] ;} >/dev/null;then
wandisabled
elif [[ "$WAN0STATUS" == "DISCONNECTED" ]] && { [[ "$WAN1STATUS" == "DISCONNECTED" ]] ;} >/dev/null;then
wandisabled
elif [[ "$WAN0STATUS" == "CONNECTED" ]] || { [[ "$WAN1STATUS" == "DISABLED" ]] || [[ "$WAN1STATUS" == "DISCONNECTED" ]] ;} >/dev/null;then
wan0active
elif [[ "$WAN1STATUS" == "CONNECTED" ]] && { [[ "$WAN0STATUS" == "DISABLED" ]] || [[ "$WAN0STATUS" == "DISCONNECTED" ]] ;} >/dev/null;then
wan1active
else
sleep 5
wanstatus
fi
}

# WAN0 Active
wan0active ()
{
  echo "$(date "+%D @ %T"): $0 - WAN0 Active: Verifying WAN0..." >> $LOGPATH
if [[ "$(nvram get wan0_primary)" != "1" ]] >/dev/null;then
switchwan
elif [[ "$(nvram get wan0_primary)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] >/dev/null;then
wan0monitor
elif [[ "$(nvram get wan0_primary)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "0" ]] >/dev/null;then
wandisabled
fi
}

# WAN1 Active
wan1active ()
{
  echo "$(date "+%D @ %T"): $0 - WAN1 Active: Verifying WAN1..." >> $LOGPATH
if [[ "$(nvram get wan1_primary)" != "1" ]] >/dev/null;then
switchwan
elif [[ "$(nvram get wan1_primary)" == "1" ]] && [[ "$(nvram get wan0_enable)" == "1" ]] >/dev/null;then
wan0restoremonitor
elif [[ "$(nvram get wan1_primary)" == "1" ]] && [[ "$(nvram get wan0_enable)" == "0" ]] >/dev/null;then
wandisabled
fi
}

# WAN0 Monitor
wan0monitor ()
{
  echo "$(date "+%D @ %T"): $0 - WAN0 Monitor: Monitoring WAN0 via $WAN0TARGET for Failure..." >> $LOGPATH
while { [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] ;} && [[ "$(nvram get wan0_primary)" == "1" ]] >/dev/null;do
if [[ "$(ping -I $(nvram get wan0_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" != "100%" ]] >/dev/null;then
  echo "$(echo $(date "+%D @ %T")) - WAN0 Monitor: WAN0 Online..." >/dev/null
else
switchwan
fi
done
wanstatus
}

# WAN0 Restore Monitor
wan0restoremonitor ()
{
  echo "$(date "+%D @ %T"): $0 - WAN0 Restore Monitor: Monitoring WAN0 via $WAN0TARGET for Restoration..." >> $LOGPATH
while [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] && [[ "$(nvram get wan1_primary)" == "1" ]] >/dev/null;do
if [[ "$(ping -I $(nvram get wan0_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" != "0%" ]] >/dev/null;then
  echo "$(echo $(date "+%D @ %T")) - WAN0 Restore Monitor: WAN0 Offline..." >/dev/null
else
switchwan
fi
done
wanstatus
}

# WAN Disabled
wandisabled ()
{
if [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] && [[ "$(nvram get wans_mode)" != "fo" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Failover Disabled: Dual WAN is disabled or not in Failover Mode." >> $LOGPATH
elif [[ "$(nvram get wandog_enable)" != "0" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Failover Disabled: ASUS Factory WAN Failover is enabled." >> $LOGPATH
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Failover Disabled: $(echo $WANPREFIXES | awk '{print $1}') and $(echo $WANPREFIXES | awk '{print $2}') is disabled." >> $LOGPATH
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Failover Disabled: $(echo $WANPREFIXES | awk '{print $1}') is disabled." >> $LOGPATH
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - WAN Failover Disabled: $(echo $WANPREFIXES | awk '{print $2}') is disabled." >> $LOGPATH
fi
  echo "$(date "+%D @ %T"): $0 - WAN Failover Disabled: WAN Failover is currently stopped, will resume when Dual WAN Failover Mode is enabled and WAN Links are enabled with an active connection..." >> $LOGPATH
while { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] && [[ "$(nvram get wans_mode)" != "fo" ]] ;} \
  || [[ "$(nvram get wandog_enable)" != "0" ]] \
  || { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] || [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] ;} \
  || { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_state_t)" != "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_state_t)" != "2" ]] ;} \
  || { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_realip_state)" != "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_realip_state)" != "2" ]] ;} \
  || { [ -z "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_realip_ip)" ] && [ -z "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_realip_ip)" ] ;} >/dev/null;do
sleep $WANDISABLEDSLEEPTIMER
done
wanstatus
}

# Switch WAN
switchwan ()
{
if [[ "$(nvram get wan0_primary)" == "1" ]] >/dev/null;then
ACTIVEWAN=wan1
INACTIVEWAN=wan0
echo Switching to $ACTIVEWAN
elif [[ "$(nvram get wan1_primary)" == "1" ]] >/dev/null;then
ACTIVEWAN=wan0
INACTIVEWAN=wan1
echo Switching to $ACTIVEWAN
fi

until { [[ "$(nvram get "$INACTIVEWAN"_primary)" == "0" ]] && [[ "$(nvram get "$ACTIVEWAN"_primary)" == "1" ]] ;} && [[ "$(echo $(ip route show default | awk '{print $3}'))" == "$(nvram get "$ACTIVEWAN"_gateway)" ]] >/dev/null;do
# Change Primary WAN
  echo "$(date "+%D @ %T"): $0 - Switching $ACTIVEWAN to primary..." >> $LOGPATH
nvram set "$ACTIVEWAN"_primary=1 && nvram set "$INACTIVEWAN"_primary=0
# Change WAN IP Address
  echo "$(date "+%D @ %T"): $0 - Setting WAN IP Address: $(nvram get "$ACTIVEWAN"_ipaddr)..." >> $LOGPATH
nvram set wan_ipaddr=$(nvram get "$ACTIVEWAN"_ipaddr)

# Change WAN Gateway
  echo "$(date "+%D @ %T"): $0 - Setting WAN Gateway: $(nvram get "$ACTIVEWAN"_gateway)..." >> $LOGPATH
nvram set wan_gateway=$(nvram get "$ACTIVEWAN"_gateway)
# Change WAN Interface
  echo "$(date "+%D @ %T"): $0 - Setting WAN Interface: $(nvram get "$ACTIVEWAN"_ifname)..." >> $LOGPATH
nvram set wan_ifname=$(nvram get "$ACTIVEWAN"_ifname)

# Switch DNS
if [ ! -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] || [ ! -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - Setting Manual DNS Settings..." >> $LOGPATH
# Change Manual DNS Settings
if [ ! -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] >/dev/null;then
# Change DNS1 Server
  echo "$(date "+%D @ %T"): $0 - Setting DNS1 Server: $(nvram get "$ACTIVEWAN"_dns1_x)..." >> $LOGPATH
nvram set wan_dns1_x=$(nvram get "$ACTIVEWAN"_dns1_x)
if [[ "$(cat "$DNSRESOLVFILE" | grep -e $(echo $(nvram get "$ACTIVEWAN"_dns1_x)) | wc -l)" == "0" ]] >/dev/null;then
sed -i '1i nameserver '$(nvram get "$ACTIVEWAN"_dns1_x)'' $DNSRESOLVFILE
sed -i '/nameserver '$(nvram get "$INACTIVEWAN"_dns1_x)'/d' $DNSRESOLVFILE
else
  echo "$(date "+%D @ %T"): $0 - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS1 Server..." >> $LOGPATH
fi
else
  echo "$(date "+%D @ %T"): $0 - No DNS1 Server for $ACTIVEWAN..." >> $LOGPATH
fi
if [ ! -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] >/dev/null;then
# Change DNS2 Server
  echo "$(date "+%D @ %T"): $0 - Setting DNS2 Server: $(nvram get "$ACTIVEWAN"_dns2_x)..." >> $LOGPATH
nvram set wan_dns2_x=$(nvram get "$ACTIVEWAN"_dns2_x)
if [[ "$(cat "$DNSRESOLVFILE" | grep -e $(echo $(nvram get "$ACTIVEWAN"_dns2_x)) | wc -l)" == "0" ]] >/dev/null;then
sed -i '2i nameserver '$(nvram get "$ACTIVEWAN"_dns2_x)'' $DNSRESOLVFILE
sed -i '/nameserver '$(nvram get "$INACTIVEWAN"_dns2_x)'/d' $DNSRESOLVFILE
else
  echo "$(date "+%D @ %T"): $0 - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS2 Server..." >> $LOGPATH
fi
else
  echo "$(date "+%D @ %T"): $0 - No DNS2 Server for $ACTIVEWAN..." >> $LOGPATH
fi

# Change Automatic ISP DNS Settings
elif [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns))" ] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - Setting Automatic DNS Settings from ISP: $(nvram get "$ACTIVEWAN"_dns)..." >> $LOGPATH
nvram set wan_dns="$(echo $(nvram get "$ACTIVEWAN"_dns))"
if [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')" ] >/dev/null;then
if [[ "$(cat "$DNSRESOLVFILE" | grep -e $(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}') | wc -l)" == "0" ]] >/dev/null;then
sed -i '1i nameserver '$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')'' $DNSRESOLVFILE
sed -i '/nameserver '$(echo $(nvram get "$INACTIVEWAN"_dns) | awk '{print $1}')'/d' $DNSRESOLVFILE
else
  echo "$(date "+%D @ %T"): $0 - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS1 Server..." >> $LOGPATH
fi
else
  echo "$(date "+%D @ %T"): $0 - DNS1 Server not detected in Automatic ISP Settings for $ACTIVEWAN..." >> $LOGPATH
fi
if [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')" ] >/dev/null;then
if [[ "$(cat "$DNSRESOLVFILE" | grep -e $(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}') | wc -l)" == "0" ]] >/dev/null;then
sed -i '2i nameserver '$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')'' $DNSRESOLVFILE
sed -i '/nameserver '$(echo $(nvram get "$INACTIVEWAN"_dns) | awk '{print $2}')'/d' $DNSRESOLVFILE
else
  echo "$(date "+%D @ %T"): $0 - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS2 Server..." >> $LOGPATH
fi
else
  echo "$(date "+%D @ %T"): $0 - DNS2 Server not detected in Automatic ISP Settings for $ACTIVEWAN..." >> $LOGPATH
fi
else
  echo "$(date "+%D @ %T"): $0 - No DNS Settings detected..." >> $LOGPATH
fi

# Change Default Route
if [ ! -z "$(ip route list default | grep -e "$(nvram get "$INACTIVEWAN"_ifname)")" ]  >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - Deleting default route via $(nvram get "$INACTIVEWAN"_gateway) dev $(nvram get "$INACTIVEWAN"_ifname)..." >> $LOGPATH
ip route del default
else
  echo "$(date "+%D @ %T"): $0 - No default route detected via $(nvram get "$INACTIVEWAN"_gateway) dev $(nvram get "$INACTIVEWAN"_ifname)..." >> $LOGPATH
fi
  echo "$(date "+%D @ %T"): $0 - Adding default route via $(nvram get "$ACTIVEWAN"_gateway) dev $(nvram get "$ACTIVEWAN"_ifname)..." >> $LOGPATH
ip route add default via $(nvram get "$ACTIVEWAN"_gateway) dev $(nvram get "$ACTIVEWAN"_ifname)

# Change QoS Settings
if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - QoS is Enabled..." >> $LOGPATH
if [[ -z "$(nvram get qos_obw)" ]] && [[ -z "$(nvram get qos_obw)" ]] >/dev/null;then
  echo "$(date "+%D @ %T"): $0 - QoS is set to Automatic Bandwidth Setting..." >> $LOGPATH
else
  echo "$(date "+%D @ %T"): $0 - Setting Manual QoS Bandwidth Settings..." >> $LOGPATH
if [[ "$ACTIVEWAN" == "wan0" ]] >/dev/null;then
nvram set qos_obw=$WAN0_QOS_OBW
nvram set qos_ibw=$WAN0_QOS_IBW
nvram set qos_overhead=$WAN0_QOS_OVERHEAD
nvram set qos_atm=$WAN0_QOS_ATM
elif [[ "$ACTIVEWAN" == "wan1" ]] >/dev/null;then
nvram set qos_obw=$WAN1_QOS_OBW
nvram set qos_ibw=$WAN1_QOS_IBW
nvram set qos_overhead=$WAN1_QOS_OVERHEAD
nvram set qos_atm=$WAN1_QOS_ATM
fi
fi
else
  echo "$(date "+%D @ %T"): $0 - QoS is Disabled..." >> $LOGPATH
fi
sleep 1
done
  echo "$(date "+%D @ %T"): $0 - Switched $ACTIVEWAN to primary." >> $LOGPATH
restartservices
}

# Restart Services
restartservices ()
{
for SERVICE in ${SERVICES};do
  echo "$(date "+%D @ %T"): $0 - Restarting $SERVICE service..." >> $LOGPATH
service restart_$SERVICE
  echo "$(date "+%D @ %T"): $0 - Restarted $SERVICE service." >> $LOGPATH
done
wanevent
}

# Trigger WAN Event
wanevent ()
{
if [[ -f "/jffs/scripts/wan-event" ]] >/dev/null;then
/jffs/scripts/wan-event
wanstatus
else
wanstatus
fi
}

# Log Clean
logclean ()
{
if [[ "${mode}" == "logclean" ]] >/dev/null;then
  echo "${0##*/} - Deleting logs older than last $LOGNUMBER messages..." 
else
continue
fi
  echo "$(date "+%D @ %T"): $0 - Log Cleanup: Deleting logs older than last $LOGNUMBER messages..." >> $LOGPATH
tail -n $LOGNUMBER $LOGPATH > $LOGPATH'.tmp'
sleep 1
cp -f $LOGPATH'.tmp' $LOGPATH
sleep 1
rm -f $LOGPATH'.tmp'
sleep 1
exit
}
scriptmode
