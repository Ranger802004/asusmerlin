#!/bin/sh

# WAN Failover for ASUS Routers using Merlin Firmware v386.5.2
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 05/26/2022
# Version: v1.4.1

# Cause the script to exit if errors are encountered
set -e
set -u

# Global Variables
DOWNLOADPATH="https://raw.githubusercontent.com/Ranger802004/asusmerlin/main/wan-failover.sh"
VERSION="v1.4.1"
CONFIGFILE="/jffs/configs/wan-failover.conf"
SYSTEMLOG="/tmp/syslog.log"
DNSRESOLVFILE="/tmp/resolv.conf"
LOCKFILE="/var/lock/wan-failover.lock"
WANPREFIXES="wan0 wan1"
SMTP_SERVER="$(cat /etc/email/email.conf | grep -e SMTP_SERVER | awk -F"'" '{print $2}')"
SMTP_PORT="$(cat /etc/email/email.conf | grep -e SMTP_PORT | awk -F"'" '{print $2}')"
MY_NAME="$(cat /etc/email/email.conf | grep -e MY_NAME | awk -F"'" '{print $2}')"
MY_EMAIL="$(cat /etc/email/email.conf | grep -e MY_EMAIL | awk -F"'" '{print $2}')"
SMTP_AUTH_USER="$(cat /etc/email/email.conf | grep -e SMTP_AUTH_USER | awk -F"'" '{print $2}')"
SMTP_AUTH_PASS="$(cat /etc/email/email.conf | grep -e SMTP_AUTH_PASS | awk -F"'" '{print $2}')"
CAFILE="/rom/etc/ssl/cert.pem"
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
  echo -e "${YELLOW}$0 update${WHITE} - This will download and update to the latest version.${NOCOLOR}"
  echo -e "${YELLOW}$0 cron${WHITE} - This will create the Cron Jobs necessary for the script to run and also perform log cleaning.${NOCOLOR}"
  echo -e "${YELLOW}$0 switchwan${WHITE} - This will manually switch Primary WAN.${NOCOLOR}"
  echo -e "${RED}$0 uninstall${WHITE} - This will uninstall the configuration files necessary to stop the script from running.${NOCOLOR}"
  echo -e "${RED}$0 kill${WHITE} - This will kill any running instances of the script.${NOCOLOR}"
  break && exit
fi
mode="${1#}"
scriptmode ()
{
if [[ "${mode}" == "install" ]] >/dev/null;then
  echo -e "${BLUE}${0##*/} - Install mode...${NOCOLOR}"
  install
elif [[ "${mode}" == "run" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Run Mode${NOCOLOR}"
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || exit
  trap 'rm -f "$LOCKFILE"' EXIT
  setvariables
elif [[ "${mode}" == "manual" ]] >/dev/null;then 
  echo -e "${GREEN}${0##*/} - Manual Mode${NOCOLOR}"
  exec 100>"$LOCKFILE" || exit
  flock -x -n 100 || exit
  trap 'rm -f "$LOCKFILE"' EXIT
  setvariables
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
elif [[ "${mode}" == "switchwan" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Switch WAN Mode${NOCOLOR}"
  setvariables
elif [[ "${mode}" == "update" ]] >/dev/null;then 
  echo -e "${YELLOW}${0##*/} - Update Mode${NOCOLOR}"
  update
fi
if [[ ! -f "$CONFIGFILE" ]] >/dev/null;then
  echo -e "${RED}${0##*/} - No Configuration File Detected - Run Install Mode${NOCOLOR}"
  exit
fi
}

# Install
install ()
{
read -n 1 -s -r -p "Press any key to continue to install..."
if [[ "${mode}" == "install" ]] >/dev/null;then
  # Check if JFFS Custom Scripts is enabled
  if [[ "$(nvram get jffs2_scripts)" != "1" ]] >/dev/null;then
    echo -e "${RED}Warning!!!  Administration > System > Enable JFFS custom scripts and configs is not enabled.${NOCOLOR}"
    logger -t "${0##*/}" "Install - Warning!!!  Administration > System > Enable JFFS custom scripts and configs is not enabled"
  else
    echo -e "${GREEN}Administration > System > Enable JFFS custom scripts and configs is enabled...${NOCOLOR}"
    logger -t "${0##*/}" "Install - Administration > System > Enable JFFS custom scripts and configs is enabled"
  fi

  # Check for Config File
  echo -e "${BLUE}Creating $CONFIGFILE...${NOCOLOR}"
  logger -t "${0##*/}" "Install - Creating $CONFIGFILE"
  if [ ! -f $CONFIGFILE ] >/dev/null;then
    touch -a $CONFIGFILE
    chmod 666 $CONFIGFILE
    echo -e "${GREEN}$CONFIGFILE created.${NOCOLOR}"
    logger -t "${0##*/}" "Install - $CONFIGFILE created"
  else
    echo -e "${YELLOW}$CONFIGFILE already exists...${NOCOLOR}"
    logger -t "${0##*/}" "Install - $CONFIGFILE already exists"
  fi

  # User Input for Custom Variables
  echo "Setting Custom Variables..."
  echo -e "${YELLOW}***WAN Target IP Addresses will be routed via WAN Gateway dev WAN Interface***${NOCOLOR}"
  read -p "Set WAN0 Target IP Address - Will be routed via $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_gateway) dev $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_ifname): " SETWAN0TARGET
  read -p "Set WAN1 Target IP Address - Will be routed via $(nvram get $(echo $WANPREFIXES | awk '{print $2}')_gateway) dev $(nvram get $(echo $WANPREFIXES | awk '{print $2}')_ifname): " SETWAN1TARGET
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

# Create Array for Custom Variables
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
  logger -t "${0##*/}" "Install - Adding Custom Settings to $CONFIGFILE"
  for NEWVARIABLE in ${NEWVARIABLES};do
    if [ -z "$(cat $CONFIGFILE | grep -e "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')")" ] >/dev/null;then
      echo "$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')" >> $CONFIGFILE
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
    else
      sed -i -e "s/\(^"$(echo ${NEWVARIABLE} | awk -F"|" '{print $1}')"\).*/\1"$(echo ${NEWVARIABLE} | awk -F"|" '{print $2}')"/" $CONFIGFILE
    fi
  done
  echo -e "${GREEN}Custom Variables added to $CONFIGFILE.${NOCOLOR}"
  logger -t "${0##*/}" "Install - Custom Variables added to $CONFIGFILE"

  # Create Wan-Event if it doesn't exist
  echo -e "${BLUE}Creating Wan-Event script...${NOCOLOR}"
  logger -t "${0##*/}" "Install - Creating Wan-Event script"
  if [ ! -f "/jffs/scripts/wan-event" ] >/dev/null;then
    touch -a /jffs/scripts/wan-event
    chmod 755 /jffs/scripts/wan-event
    echo "#!/bin/sh" >> /jffs/scripts/wan-event
    echo -e "${GREEN}Wan-Event script has been created.${NOCOLOR}"
  logger -t "${0##*/}" "Install - Wan-Event script has been created"
  else
    echo -e "${YELLOW}Wan-Event script already exists...${NOCOLOR}"
    logger -t "${0##*/}" "Install - Wan-Event script already exists"
  fi

  # Add Script to Wan-event
  if [ ! -z "$(cat /jffs/scripts/wan-event | grep -e "# Wan-Failover")" ] >/dev/null;then 
    echo -e "${YELLOW}${0##*/} already added to Wan-Event...${NOCOLOR}"
    logger -t "${0##*/}" "Install - ${0##*/} already added to Wan-Event"
  else
    cmdline="sh $0 cron"
    echo -e "${BLUE}Adding ${0##*/} to Wan-Event...${NOCOLOR}"
    logger -t "${0##*/}" "Install - Adding ${0##*/} to Wan-Event"
    echo -e "\r\n$cmdline # Wan-Failover" >> /jffs/scripts/wan-event
    echo -e "${GREEN}${0##*/} added to Wan-Event.${NOCOLOR}"
    logger -t "${0##*/}" "Install - ${0##*/} added to Wan-Event"
  fi

  # Create Initial Cron Jobs
  cronjob

  # Start Initial Script
  sh $0 run
fi
exit
}

# Uninstall
uninstall ()
{
if [[ "${mode}" == "uninstall" ]] >/dev/null;then
read -n 1 -s -r -p "Press any key to continue to uninstall..."
  # Remove Cron Job
  if [ ! -z "$(crontab -l | grep -e "setup_wan_failover_run")" ] >/dev/null; then
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job for Run Mode...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removing Cron Job for Run Mode"
    cru d setup_wan_failover_run
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job for Run Mode.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removed Cron Job for Run Mode"
  else
    echo -e "${GREEN}${0##*/} - Uninstall: Cron Job for Run Mode doesn't exist.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Cron Job for Run Mode doesn't exist"
  fi

  # Check for Config File
  echo -e "${BLUE}${0##*/} - Uninstall: Deleting $CONFIGFILE...${NOCOLOR}"
  logger -t "${0##*/}" "Uninstall - Deleting $CONFIGFILE"
  if [ -f $CONFIGFILE ] >/dev/null;then
    rm -f $CONFIGFILE
    echo -e "${GREEN}${0##*/} - Uninstall: $CONFIGFILE deleted.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - $CONFIGFILE deleted"
  else
    echo -e "${RED}${0##*/} - Uninstall: $CONFIGFILE doesn't exist.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - $CONFIGFILE doesn't exist"
  fi

  # Remove Script from Wan-event
  cmdline="sh $0 cron"
  if [ ! -z "$(cat /jffs/scripts/wan-event | grep -e "^$cmdline")" ] >/dev/null;then 
    echo -e "${BLUE}${0##*/} - Uninstall: Removing Cron Job from Wan-Event...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removing Cron Job from Wan-Event"
    sed -i '\~# Wan-Failover~d' /jffs/scripts/wan-event
    echo -e "${GREEN}${0##*/} - Uninstall: Removed Cron Job from Wan-Event.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removed Cron Job from Wan-Event"
  else
    echo -e "${RED}${0##*/} - Uninstall: Cron Job doesn't exist in Wan-Event.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Cron Job doesn't exist in Wan-Event"
  fi

  # Restart WAN Interfaces
  if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] >/dev/null;then
    echo -e "${YELLOW}${0##*/} - Uninstall: Restarting interface $(echo $WANPREFIXES | awk '{print $1}')${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarting interface $(echo $WANPREFIXES | awk '{print $1}')"
    nvram set "$(echo $WANPREFIXES | awk '{print $1}')"_state_t=0
    service "restart_wan_if 0" &
    echo -e "${GREEN}${0##*/} - Uninstall: Restarted interface $(echo $WANPREFIXES | awk '{print $1}')${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarted interface $(echo $WANPREFIXES | awk '{print $1}')"
  fi

  if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] >/dev/null;then
    echo -e "${YELLOW}${0##*/} - Uninstall: Restarting interface $(echo $WANPREFIXES | awk '{print $2}')${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarting interface $(echo $WANPREFIXES | awk '{print $2}')"
    nvram set "$(echo $WANPREFIXES | awk '{print $2}')"_state_t=0
    service "restart_wan_if 1" &
    echo -e "${GREEN}${0##*/} - Uninstall: Restarted interface $(echo $WANPREFIXES | awk '{print $2}')${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Restarted interface $(echo $WANPREFIXES | awk '{print $2}')"
  fi

  # Remove Lock File
  if [ -f "$LOCKFILE" ] >/dev/null;then
    echo -e "${BLUE}${0##*/} - Uninstall: Removing $LOCKFILE...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removing $LOCKFILE"
    rm -f "$LOCKFILE"
    echo -e "${GREEN}${0##*/} - Uninstall: Removed $LOCKFILE...${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - Removed $LOCKFILE"
  else
    echo -e "${RED}${0##*/} - Uninstall: $LOCKFILE doesn't exist.${NOCOLOR}"
    logger -t "${0##*/}" "Uninstall - $LOCKFILE doesn't exist"
  fi

  # Kill Running Processes
  echo -e "${RED}Killing ${0##*/}...${NOCOLOR}"
  logger -t "${0##*/}" "Uninstall - Killing ${0##*/}"
  sleep 3 && killall ${0##*/}
fi
exit
}

# Kill Script
kill ()
{
echo -e "${RED}Killing ${0##*/}...${NOCOLOR}"
logger -t "${0##*/}" "Kill - Killing ${0##*/}"
if [ -f "$LOCKFILE" ] >/dev/null;then
  rm -f "$LOCKFILE"
fi
sleep 3 && killall ${0##*/}
exit
}

# Update Script
update ()
{
REMOTEVERSION="$(echo $(curl "$DOWNLOADPATH" | grep -v "grep" | grep -e "# Version:" | awk '{print $3}'))" 
if [[ "$VERSION" != "$REMOTEVERSION" ]];then
  echo -e "${YELLOW}Script is out of date - Current Version: $VERSION Available Version: $REMOTEVERSION${NOCOLOR}"
  read -n 1 -s -r -p "Press any key to continue to update..."
  /usr/sbin/curl -s "$DOWNLOADPATH" -o "$0" && chmod 755 $0 & kill
  echo -e "${GREEN}Script has been updated...${NOCOLOR}"
elif [[ "$VERSION" == "$REMOTEVERSION" ]];then
  echo -e "${GREEN}Script is up to date - Version: $VERSION${NOCOLOR}"
fi
}

# Cronjob
cronjob ()
{
if [ -z "$(crontab -l | grep -e "$0")" ] >/dev/null; then
  echo -e "${BLUE}Creating cron jobs...${NOCOLOR}"
  logger -t "${0##*/}" "Cron - Creating cron job"
  cru a setup_wan_failover_run "*/1 * * * *" $0 run
  echo -e "${GREEN}Completed creating cron job.${NOCOLOR}"
  logger -t "${0##*/}" "Cron - Completed creating cron job"
fi
exit
}

# Monitor Logging
monitor ()
{
tail -F $SYSTEMLOG | grep -e "${0##*/}" && exit
}

# Set Variables
setvariables ()
{
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
if [[ "${mode}" == "switchwan" ]] >/dev/null;then
  switchwan
else
  wanstatus
fi
}

# WAN Status
wanstatus ()
{
# Check Current Status of Dual WAN Mode
if { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] && [[ "$(nvram get wans_mode)" != "fo" ]] ;} >/dev/null;then
  logger -t "${0##*/}" "Dual WAN Failover Mode - Disabled"
  wandisabled
# Check if ASUS Factory WAN Failover is Enabled
elif [[ "$(nvram get wandog_enable)" != "0" ]] >/dev/null;then
  logger -t "${0##*/}" "Dual WAN Failover Mode - ASUS Factory Watchdog: Enabled"
  wandisabled
# Check if both WAN Interfaces are Disabled
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
  wandisabled
# Check if WAN Interfaces are Enabled and Connected
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] || [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] >/dev/null;then
  for WANPREFIX in ${WANPREFIXES};do
    # Check if WAN Interfaces are Disabled
    if [[ "$(nvram get "${WANPREFIX}"_enable)" == "0" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN Status - ${WANPREFIX} disabled"
      # Set WAN0 as Disabled
      if [[ "${WANPREFIX}" == "$(echo $WANPREFIXES | awk '{print $1}')" ]] >/dev/null;then
        WAN0STATUS="DISABLED"
        continue
      # Set WAN1 as Disabled
      elif [[ "${WANPREFIX}" == "$(echo $WANPREFIXES | awk '{print $2}')" ]] >/dev/null;then
        WAN1STATUS="DISABLED"
        continue
      fi
    # Check if WAN is Enabled
    elif [[ "$(nvram get "${WANPREFIX}"_enable)" == "1" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN Status - ${WANPREFIX} enabled"
      # Check WAN0 Connection
      if [[ "${WANPREFIX}" == "$(echo $WANPREFIXES | awk '{print $1}')" ]] >/dev/null;then
        # Check if WAN0 is Connected
        if { [[ "$(nvram get ${WANPREFIX}_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get ${WANPREFIX}_gateway)" == "0.0.0.0" ]] ;} >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} is disconnected.  IP Address: "$(nvram get ${WANPREFIX}_ipaddr)" Gateway: "$(nvram get ${WANPREFIX}_gateway)""
          WAN0STATUS="DISCONNECTED"
          continue
        # Check WAN0 IP Address Target Route
        elif [ ! -z "$(ip route list default | grep -e "$WAN0TARGET")" ]  >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Default route already exists via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_ifname)""
        elif [ -z "$(ip route list $WAN0TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname))" ] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Creating route $WAN0TARGET via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_ifname)""
          ip route add $WAN0TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname)
          logger -t "${0##*/}" "WAN Status - Created route $WAN0TARGET via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_ifname)""
        else
          logger -t "${0##*/}" "WAN Status - Route already exists for $WAN0TARGET via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_ifname)""
        fi
        # Check WAN0 Packet Loss
        WAN0PACKETLOSS="$(ping -I $(nvram get ${WANPREFIX}_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
        if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN0PACKETLOSS packet loss"
          WAN0STATUS="CONNECTED"
          nvram set ${WANPREFIX}_state_t=2
          continue
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN0PACKETLOSS packet loss ***Verify $WAN0TARGET is a valid server for ICMP Echo Requests***"
          WAN0STATUS="DISCONNECTED"
          continue
        else
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN0PACKETLOSS packet loss"
          WAN0STATUS="DISCONNECTED"
          continue
        fi
      # Check WAN1 Connection
      elif [[ "${WANPREFIX}" == "$(echo $WANPREFIXES | awk '{print $2}')" ]] >/dev/null;then
        # Check if WAN1 is Connected
        if { [[ "$(nvram get ${WANPREFIX}_ipaddr)" == "0.0.0.0" ]] || [[ "$(nvram get ${WANPREFIX}_gateway)" == "0.0.0.0" ]] ;} >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} is disconnected.  IP Address: "$(nvram get ${WANPREFIX}_ipaddr)" Gateway: "$(nvram get ${WANPREFIX}_gateway)""
          WAN1STATUS="DISCONNECTED"
          continue
        # Check WAN1 IP Address Target Route
        elif [ ! -z "$(ip route list default | grep -e "$WAN1TARGET")" ]  >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Default route already exists via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_ifname)""
        elif [ -z "$(ip route list $WAN1TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname))" ] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - Creating route $WAN1TARGET via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_ifname)""
          ip route add $WAN1TARGET via $(nvram get ${WANPREFIX}_gateway) dev $(nvram get ${WANPREFIX}_ifname)
          logger -t "${0##*/}" "WAN Status - Created route $WAN1TARGET via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_ifname)""
        else
          logger -t "${0##*/}" "WAN Status - Route already exists for $WAN1TARGET via "$(nvram get ${WANPREFIX}_gateway)" dev "$(nvram get ${WANPREFIX}_ifname)""
        fi
        # Check WAN1 Packet Loss
        WAN1PACKETLOSS="$(ping -I $(nvram get ${WANPREFIX}_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
        if [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN1PACKETLOSS packet loss"
          WAN1STATUS="CONNECTED"
          nvram set ${WANPREFIX}_state_t=2
          continue
        elif [[ "$(nvram get "${WANPREFIX}"_state_t)" == "2" ]] >/dev/null;then
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN1PACKETLOSS packet loss ***Verify $WAN1TARGET is a valid server for ICMP Echo Requests***"
          WAN1STATUS="DISCONNECTED"
          continue
        else
          logger -t "${0##*/}" "WAN Status - ${WANPREFIX} has $WAN1PACKETLOSS packet loss"
          WAN1STATUS="DISCONNECTED"
          continue
        fi
      fi
    fi
  done
fi
# Set WAN Status to DISABLED, DISCONNECTED, or CONNECTED and select function.
if [[ "$WAN0STATUS" == "DISABLED" ]] && { [[ "$WAN1STATUS" == "DISABLED" ]] ;} >/dev/null;then
  wandisabled
elif [[ "$WAN0STATUS" == "DISCONNECTED" ]] && { [[ "$WAN1STATUS" == "DISCONNECTED" ]] ;} >/dev/null;then
  wandisabled
elif [[ "$WAN0STATUS" == "CONNECTED" ]] || { [[ "$WAN1STATUS" == "DISABLED" ]] || [[ "$WAN1STATUS" == "DISCONNECTED" ]] ;} >/dev/null;then
  wan0active
elif [[ "$WAN1STATUS" == "CONNECTED" ]] && { [[ "$WAN0STATUS" == "DISABLED" ]] || [[ "$WAN0STATUS" == "DISCONNECTED" ]] ;} >/dev/null;then
  wan1active
else
  wanstatus
fi
}

# WAN0 Active
wan0active ()
{
  logger -t "${0##*/}" "WAN0 Active - Verifying WAN0"
if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" != "1" ]] >/dev/null;then
  switchwan
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] >/dev/null;then
  wan0failovermonitor
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
  wandisabled
else
  wanstatus
fi
}

# WAN1 Active
wan1active ()
{
  logger -t "${0##*/}" "WAN0 Active - Verifying WAN1"
if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" != "1" ]] >/dev/null;then
  switchwan
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] >/dev/null;then
  wan0failbackmonitor
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] >/dev/null;then
  wandisabled
else
  wanstatus
fi
}

# WAN0 Failover Monitor
wan0failovermonitor ()
{
  logger -t "${0##*/}" "WAN0 Failover Monitor - Monitoring WAN0 via $WAN0TARGET for Failure"
while { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] ;} && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] >/dev/null;do
  WAN0PACKETLOSS="$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
  if [ -z "$(ip route list $WAN0TARGET via "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_gateway)" dev "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_ifname)")" ] >/dev/null;then
    break
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null;then
    continue
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN0 Failover Monitor - Failure Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    switchwan
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN0 Failover Monitor - Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
  fi
done
  wanstatus
}

# WAN0 Failback Monitor
wan0failbackmonitor ()
{
  logger -t "${0##*/}" "WAN0 Failback Monitor - Monitoring WAN0 via $WAN0TARGET for Failback"
while [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] >/dev/null;do
  WAN0PACKETLOSS="$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
  if [ -z "$(ip route list $WAN0TARGET via "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_gateway)" dev "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_ifname)")" ] >/dev/null;then
    break
  elif [[ "$WAN0PACKETLOSS" == "100%" ]] >/dev/null;then
    continue
  elif [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN0 Failback Monitor - Connection Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
    switchwan
  elif [[ "$WAN0PACKETLOSS" != "0%" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN0 Failback Monitor - Packet Loss Detected - WAN0 Packet Loss: $WAN0PACKETLOSS"
  fi
done
  wanstatus
}

# WAN Disabled
wandisabled ()
{
if [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] || [[ "$(nvram get wans_mode)" != "fo" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - Dual WAN is disabled or not in Failover Mode"
elif [[ "$(nvram get wandog_enable)" != "0" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - ASUS Factory WAN Failover is enabled"
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') and $(echo $WANPREFIXES | awk '{print $2}') are disabled"
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') is disabled"
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
  logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $2}') is disabled"
fi
  logger -t "${0##*/}" "WAN Failover Disabled - WAN Failover is currently stopped, will resume when Dual WAN Failover Mode is enabled and WAN Links are enabled with an active connection"
while \
  # Return to WAN Status if both interfaces are Enabled and Connected
  if  { [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_enable)" == "1" ]] && [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $2}')"_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_state_t)" == "2" ]] && [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $2}')"_state_t)" == "2" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') and $(echo $WANPREFIXES | awk '{print $2}') are enabled and connected"
    break
  # Return to WAN Status if both interfaces are Enabled and have Real IP Addresses
  elif  { [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_enable)" == "1" ]] && [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $2}')"_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $1}')"_realip_state)" == "2" ]] && [[ "$(nvram get "$(echo $WANPREFIXES | awk '{print $2}')"_realip_state)" == "2" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') and $(echo $WANPREFIXES | awk '{print $2}') are enabled and connected"
    break
  # Return to WAN Status if only WAN0 is Enabled and Connected but is not Primary WAN
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] \
        && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_state_t)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') is the only enabled WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if only WAN1 is Enabled and Connected but is not Primary WAN
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] \
        && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_state_t)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $2}') is the only enabled WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN0 is Connected and is not Primary WAN.
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] \
        && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_state_t)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') is the only connected WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN1 is Connected and is not Primary WAN.
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] \
        && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_state_t)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $2}') is the only connected WAN interface but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN0 has a Real IP Address and is not Primary WAN.
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_realip_state)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_realip_state)" != "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $2}') has a Real IP Address but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are Enabled but only WAN1 has a Real IP Address and is not Primary WAN.
  elif  { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] ;} \
        && { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_realip_state)" != "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_realip_state)" == "2" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "0" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $2}') has a Real IP Address but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN0 and WAN1 are pinging both Target IP Addresses.
  elif  { [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
        && [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $2}')_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') and $(echo $WANPREFIXES | awk '{print $2}') have 0% packet loss"
    break
  # Return to WAN Status if WAN0 is pinging the Target IP Address and WAN1 is Primary and not pinging the Target IP Address.
  elif  [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
        && { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] && [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $2}')_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "100%" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') has 0% packet loss but is not Primary WAN"
    switchwan && break
  # Return to WAN Status if WAN1 is pinging the Target IP Address and WAN0 is Primary and not pinging the Target IP Address.
  elif  [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $2}')_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "0%" ]] \
        && { [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] && [[ "$(ping -I $(nvram get $(echo $WANPREFIXES | awk '{print $1}')_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" == "100%" ]] ;} >/dev/null;then
    logger -t "${0##*/}" "WAN Failover Disabled - $(echo $WANPREFIXES | awk '{print $1}') has 0% packet loss but is not Primary WAN"
    switchwan && break
  # WAN Failover Disabled if not in Dual WAN Mode Failover Mode or if ASUS Factory Failover is Enabled
  elif { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] || [[ "$(nvram get wans_mode)" != "fo" ]] || [[ "$(nvram get wandog_enable)" != "0" ]] ;} >/dev/null;then
    sleep $WANDISABLEDSLEEPTIMER
    continue
  else
    sleep $WANDISABLEDSLEEPTIMER
    continue
  fi
do
  sleep $WANDISABLEDSLEEPTIMER
done
# Return to WAN Status
logger -t "${0##*/}" "WAN Failover Disabled - Returning to check WAN Status"
wanstatus
}

# Switch WAN
switchwan ()
{
# Determine Current Primary WAN and change it to the Inactive WAN
if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] >/dev/null;then
  ACTIVEWAN=wan1
  INACTIVEWAN=wan0
  echo Switching to $ACTIVEWAN
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] >/dev/null;then
  ACTIVEWAN=wan0
  INACTIVEWAN=wan1
  echo Switching to $ACTIVEWAN
fi
# Perform WAN Switch until Secondary WAN becomes Primary WAN
until { [[ "$(nvram get "$INACTIVEWAN"_primary)" == "0" ]] && [[ "$(nvram get "$ACTIVEWAN"_primary)" == "1" ]] ;} && [[ "$(echo $(ip route show default | awk '{print $3}'))" == "$(nvram get "$ACTIVEWAN"_gateway)" ]] >/dev/null;do
  # Change Primary WAN
  logger -t "${0##*/}" "WAN Switch - Switching $ACTIVEWAN to Primary WAN"
  nvram set "$ACTIVEWAN"_primary=1 && nvram set "$INACTIVEWAN"_primary=0
  # Change WAN IP Address
  logger -t "${0##*/}" "WAN Switch - WAN IP Address: $(nvram get "$ACTIVEWAN"_ipaddr)"
  nvram set wan_ipaddr=$(nvram get "$ACTIVEWAN"_ipaddr)

  # Change WAN Gateway
  logger -t "${0##*/}" "WAN Switch - WAN Gateway: $(nvram get "$ACTIVEWAN"_gateway)"
  nvram set wan_gateway=$(nvram get "$ACTIVEWAN"_gateway)
  # Change WAN Interface
  logger -t "${0##*/}" "WAN Switch - WAN Interface: $(nvram get "$ACTIVEWAN"_ifname)"
  nvram set wan_ifname=$(nvram get "$ACTIVEWAN"_ifname)

# Switch DNS
  # Change Manual DNS Settings
  if [ ! -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] || [ ! -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - Setting Manual DNS Settings"
    # Change Manual DNS1 Server
    if [ ! -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - DNS1 Server: "$(nvram get "$ACTIVEWAN"_dns1_x)""
      nvram set wan_dns1_x=$(nvram get "$ACTIVEWAN"_dns1_x)
      if [ -z "$(cat "$DNSRESOLVFILE" | grep -e "$(echo $(nvram get "$ACTIVEWAN"_dns1_x))")" ] >/dev/null;then
        sed -i '1i nameserver '$(nvram get "$ACTIVEWAN"_dns1_x)'' $DNSRESOLVFILE
        sed -i '/nameserver '$(nvram get "$INACTIVEWAN"_dns1_x)'/d' $DNSRESOLVFILE
      else
        logger -t "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS1 Server"
      fi
    else
      logger -t "${0##*/}" "WAN Switch - No DNS1 Server for $ACTIVEWAN"
    fi
    # Change Manual DNS2 Server
    if [ ! -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - DNS2 Server: "$(nvram get "$ACTIVEWAN"_dns2_x)""
      nvram set wan_dns2_x=$(nvram get "$ACTIVEWAN"_dns2_x)
      if [ -z "$(cat "$DNSRESOLVFILE" | grep -e "$(echo $(nvram get "$ACTIVEWAN"_dns2_x))")" ] >/dev/null;then
        sed -i '2i nameserver '$(nvram get "$ACTIVEWAN"_dns2_x)'' $DNSRESOLVFILE
        sed -i '/nameserver '$(nvram get "$INACTIVEWAN"_dns2_x)'/d' $DNSRESOLVFILE
      else
        logger -t "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS2 Server"
      fi
    else
      logger -t "${0##*/}" "WAN Switch - No DNS2 Server for $ACTIVEWAN"
    fi

  # Change Automatic ISP DNS Settings
  elif [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns))" ] >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - Automatic DNS Settings from ISP: "$(nvram get "$ACTIVEWAN"_dns)""
    nvram set wan_dns="$(echo $(nvram get "$ACTIVEWAN"_dns))"
    # Change Automatic DNS1 Server
    if [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')" ] >/dev/null;then
      if [ -z "$(cat "$DNSRESOLVFILE" | grep -e "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')")" ] >/dev/null;then
        sed -i '1i nameserver '$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')'' $DNSRESOLVFILE
        sed -i '/nameserver '$(echo $(nvram get "$INACTIVEWAN"_dns) | awk '{print $1}')'/d' $DNSRESOLVFILE
      else
        logger -t "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS1 Server"
      fi
    else
      logger -t "${0##*/}" "WAN Switch - DNS1 Server not detected in Automatic ISP Settings for $ACTIVEWAN"
    fi
    # Change Automatic DNS2 Server
    if [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')" ] >/dev/null;then
      if [ -z "$(cat "$DNSRESOLVFILE" | grep -e "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')")" ] >/dev/null;then
        sed -i '2i nameserver '$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')'' $DNSRESOLVFILE
        sed -i '/nameserver '$(echo $(nvram get "$INACTIVEWAN"_dns) | awk '{print $2}')'/d' $DNSRESOLVFILE
      else
        logger -t "${0##*/}" "WAN Switch - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS2 Server"
      fi
    else
      logger -t "${0##*/}" "WAN Switch - DNS2 Server not detected in Automatic ISP Settings for $ACTIVEWAN"
    fi
  else
    logger -t "${0##*/}" "WAN Switch - No DNS Settings Detected"
  fi

  # Delete Old Default Route
  if [ ! -z "$(ip route list default | grep -e "$(nvram get "$INACTIVEWAN"_ifname)")" ]  >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - Deleting default route via "$(nvram get "$INACTIVEWAN"_gateway)" dev "$(nvram get "$INACTIVEWAN"_ifname)""
    ip route del default
  else
    logger -t "${0##*/}" "WAN Switch - No default route detected via "$(nvram get "$INACTIVEWAN"_gateway)" dev "$(nvram get "$INACTIVEWAN"_ifname)""
  fi
  # Add New Default Route
  if [ -z "$(ip route list default | grep -e "$(nvram get "$ACTIVEWAN"_ifname)")" ]  >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - Adding default route via "$(nvram get "$ACTIVEWAN"_gateway)" dev "$(nvram get "$ACTIVEWAN"_ifname)""
    ip route add default via $(nvram get "$ACTIVEWAN"_gateway) dev $(nvram get "$ACTIVEWAN"_ifname)
  else
    logger -t "${0##*/}" "WAN Switch - Default route detected via "$(nvram get "$ACTIVEWAN"_gateway)" dev "$(nvram get "$ACTIVEWAN"_ifname)""
  fi

  # Change QoS Settings
  if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null;then
    logger -t "${0##*/}" "WAN Switch - QoS is Enabled"
    if [[ -z "$(nvram get qos_obw)" ]] && [[ -z "$(nvram get qos_obw)" ]] >/dev/null;then
      logger -t "${0##*/}" "WAN Switch - QoS is set to Automatic Bandwidth Settings"
    else
      logger -t "${0##*/}" "WAN Switch - Applying Manual QoS Bandwidth Settings"
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
      logger -t "${0##*/}" "WAN Switch - QoS Settings: Download Bandwidth: $(($(nvram get qos_ibw)/1024))Mbps Upload Bandwidth: $(($(nvram get qos_obw)/1024))Mbps"
    fi
  else
    logger -t "${0##*/}" "WAN Switch - QoS is Disabled"
  fi
  sleep 1
done
  logger -t "${0##*/}" "WAN Switch - Switched $ACTIVEWAN to Primary WAN"
restartservices
}

# Restart Services
restartservices ()
{
for SERVICE in ${SERVICES};do
  logger -t "${0##*/}" "Service Restart - Restarting $SERVICE service"
  service restart_$SERVICE
  logger -t "${0##*/}" "Service Restart - Restarted $SERVICE service"
done
if [[ "${mode}" == "switchwan" ]] >/dev/null;then
  exit
else
  sendemail
fi
}

# Send Email
sendemail ()
{
if [ ! -z "$SMTP_SERVER" ] && [ ! -z "$SMTP_PORT" ] && [ ! -z "$MY_NAME" ] && [ ! -z "$MY_EMAIL" ] && [ ! -z "$SMTP_AUTH_USER" ] && [ ! -z "$SMTP_AUTH_PASS" ] >/dev/null;then
  if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] >/dev/null;then
    echo "Subject: WAN Failover Notification" >/tmp/mail.txt
  elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] >/dev/null;then
    echo "Subject: WAN Failback Notification" >/tmp/mail.txt
  fi
  echo "From: \"$MY_NAME\"<$MY_EMAIL>" >>/tmp/mail.txt
  echo "Date: $(date -R)" >>/tmp/mail.txt
  echo "" >>/tmp/mail.txt
  if [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_primary)" == "1" ]] >/dev/null;then
    echo "***WAN Failover Notification***" >>/tmp/mail.txt
  elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_primary)" == "1" ]] >/dev/null;then
    echo "***WAN Failback Notification***" >>/tmp/mail.txt
  fi
  echo "----------------------------------------------------------------------------------------" >>/tmp/mail.txt
  if [ ! -z "$(nvram get ddns_hostname_x)" ] >/dev/null;then
    echo "Hostname: $(nvram get ddns_hostname_x)" >>/tmp/mail.txt
  elif [ ! -z "$(nvram get lan_hostname)" ] >/dev/null;then
    echo "Hostname: $(nvram get lan_hostname)" >>/tmp/mail.txt
  fi
  echo "Event Time: $(date | awk '{print $2,$3,$4}')" >>/tmp/mail.txt
  echo "Active ISP: $(curl ipinfo.io | grep -e "org" | awk '{print $3" "$4}' | cut -f 1 -d "," | cut -f 1 -d '"')" >>/tmp/mail.txt
  echo "WAN IPv4 Address: $(nvram get wan_ipaddr)" >>/tmp/mail.txt
  if [ ! -z "$(nvram get ipv6_wan_addr)" ] >/dev/null;then
    echo "WAN IPv6 Address: $(nvram get ipv6_wan_addr)" >>/tmp/mail.txt
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
  fi
  echo "----------------------------------------------------------------------------------------" >>/tmp/mail.txt
  echo "" >>/tmp/mail.txt

  cat /tmp/mail.txt | sendmail -w 30 -H "exec openssl s_client -quiet -CAfile $CAFILE -connect $SMTP_SERVER:$SMTP_PORT -tls1_3 -starttls smtp" -f"$MY_EMAIL" -au"$SMTP_AUTH_USER" -ap"$SMTP_AUTH_PASS" "$MY_EMAIL"
  rm /tmp/mail.txt
  logger -t "${0##*/}" "Email Notification - Email Notification Sent"
  wanevent
else
  logger -t "${0##*/}" "Email Notification - Email Notifications are not configured"
  wanevent
fi
}

# Trigger WAN Event
wanevent ()
{
if [ -f "/jffs/scripts/wan-event" ] >/dev/null;then
  sh /jffs/scripts/wan-event
  wanstatus
else
  wanstatus
fi
}

# Log Clean - Feature has been deprecated
logclean ()
{
if [[ "${mode}" == "logclean" ]] >/dev/null;then
LOGPATH="/tmp/wan_event.log"
  echo -e "${YELLOW}Log Cleanup - This mode has been deprecated${NOCOLOR}"
  logger -t "${0##*/}" "Log Cleanup - This mode has been deprecated"
  # Will delete legacy cron job
  if [ ! -z "$(crontab -l | grep -e "setup_wan_failover_logclean")" ] >/dev/null; then
    logger -t "${0##*/}" "Log Cleanup - Removing Cron Job for Log Clean Mode"
    cru d setup_wan_failover_logclean
    logger -t "${0##*/}" "Log Cleanup - Removed Cron Job for Log Clean Mode"
  fi
  # Will remove legacy log file
  if [ -f "$LOGPATH" ] >/dev/null;then
    logger -t "${0##*/}" "Log Cleanup - Removing $LOGPATH"
    rm -f $LOGPATH
    logger -t "${0##*/}" "Log Cleanup - Removed $LOGPATH"
  fi
fi
exit
}
scriptmode