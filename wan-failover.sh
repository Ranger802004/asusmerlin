#!/bin/sh

# Author: Ranger802004
# Version 1.2

# Cause the script to exit if errors are encountered
set -e
set -u

# Script Status
scriptstatus ()
{
# Checking if script is already running
 echo "Checking if $0 is already running..."
if [[ "$(echo $(ps | grep -v "grep" | grep -e "$0" | wc -l))" -gt "1" ]] >/dev/null; then
  echo "$0 is already running..."
else
setvariables
fi
}

# Set Variables
setvariables ()
{
#WAN Prefixes
WANPREFIXES="wan0 wan1"

#Path to Log File
LOGPATH="/tmp/wan_event.log"

#Number of Log Records to Keep
LOGNUMBER="250"

#DNS Resolver File
DNSRESOLVFILE="/tmp/resolv.conf"

#Ping Target for failure detections, must be routed over targeted interface
WAN0TARGET="$(nvram get wan0_dns1_x)"
WAN1TARGET="$(nvram get wan1_gateway)"

#Ping count before WAN is considered down, requires 100% Packet Loss.
PINGCOUNT="3"
#Ping timeout in seconds
PINGTIMEOUT="1"

# If Dual WAN is disabled, this is how long the script will sleep before checking again.  Value is in seconds
WANDISABLEDSLEEPTIMER="3"

#QoS Manual Settings Variables
#QoS Inbound Bandwidth - Values are in Kbps
WAN0_QOS_IBW=972800
WAN1_QOS_IBW=97280
#QoS Outbound Bandwidth - Values are in Kbps
WAN0_QOS_OBW=972800
WAN1_QOS_OBW=5120
#QoS WAN Packet Overhead - Values are in Bytes
WAN0_QOS_OVERHEAD=42
WAN1_QOS_OVERHEAD=18
#QoS Enable ATM
WAN0_QOS_ATM=0
WAN1_QOS_ATM=0

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
# Check Current Status of Dual WAN Mode, WAN0 & WAN1
if { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] && [[ "$(nvram get wans_mode)" != "fo" ]] ;} >/dev/null;then
  echo $(date "+%D @ %T"): $0 - Dual WAN Failover Mode: Disabled >> $LOGPATH
wandisabled
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "1" ]] || [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "1" ]] >/dev/null;then
for WANPREFIX in ${WANPREFIXES};do
if [[ "$(nvram get "${WANPREFIX}"_enable)" == "0" ]] >/dev/null;then
  echo $(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} disabled... >> $LOGPATH
if [[ "${WANPREFIX}" == "wan0" ]] >/dev/null;then
WAN0STATUS="DISABLED"
elif [[ "${WANPREFIX}" == "wan1" ]] >/dev/null;then
WAN1STATUS="DISABLED"
fi
elif [[ "$(nvram get "${WANPREFIX}"_enable)" == "1" ]] >/dev/null;then
  echo $(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} enabled... >> $LOGPATH
if [[ "${WANPREFIX}" == "wan0" ]] >/dev/null;then
if [[ "$(nvram get "${WANPREFIX}"_state_t)" != "2" ]] >/dev/null;then
  echo $(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} is not connected, attempting to restart interface... >> $LOGPATH
service restart_wan_if 0 && break
else
  echo $(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} is connected... >> $LOGPATH
fi
WAN0PACKETLOSS="$(ping -I $(nvram get ${WANPREFIX}_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
if [[ "$WAN0PACKETLOSS" == "0%" ]] >/dev/null;then
  echo $(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} has $WAN0PACKETLOSS packet loss... >> $LOGPATH
WAN0STATUS="CONNECTED"
else
  echo $(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} has $WAN0PACKETLOSS packet loss... >> $LOGPATH
WAN0STATUS="DISCONNECTED"
fi
elif [[ "${WANPREFIX}" == "wan1" ]] >/dev/null;then
if [[ "$(nvram get "${WANPREFIX}"_state_t)" != "2" ]] >/dev/null;then
  echo $(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} is not connected, attempting to restart interface... >> $LOGPATH
service restart_wan_if 1 && break
else
  echo $(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} is connected... >> $LOGPATH
fi
WAN1PACKETLOSS="$(ping -I $(nvram get ${WANPREFIX}_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')"
if [[ "$WAN1PACKETLOSS" == "0%" ]] >/dev/null;then
  echo $(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} has $WAN1PACKETLOSS packet loss... >> $LOGPATH
WAN1STATUS="CONNECTED"
else
  echo $(date "+%D @ %T"): $0 - WAN Status: ${WANPREFIX} has $WAN1PACKETLOSS packet loss... >> $LOGPATH
WAN1STATUS="DISCONNECTED"
fi
fi
fi
done
elif [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $1}')_enable)" == "0" ]] && [[ "$(nvram get $(echo $WANPREFIXES | awk '{print $2}')_enable)" == "0" ]] >/dev/null;then
wandisabled
fi
if [[ "$WAN0STATUS" == "CONNECTED" ]] || { [[ "$WAN1STATUS" == "DISABLED" ]] || [[ "$WAN1STATUS" == "DISCONNECTED" ]] ;} >/dev/null;then
wan0active
elif [[ "$WAN1STATUS" == "CONNECTED" ]] && { [[ "$WAN0STATUS" == "DISABLED" ]] || [[ "$WAN0STATUS" == "DISCONNECTED" ]] ;} >/dev/null;then
wan1active
else
wandisabled
fi
}

# WAN0 Active
wan0active ()
{
  echo $(date "+%D @ %T"): $0 - WAN0 Active: Verifying WAN0... >> $LOGPATH
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
  echo $(date "+%D @ %T"): $0 - WAN1 Active: Verifying WAN1... >> $LOGPATH
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
  echo $(date "+%D @ %T"): $0 - WAN0 Monitor: Monitoring WAN0 for Failure... >> $LOGPATH
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
  echo $(date "+%D @ %T"): $0 - WAN0 Restore Monitor: Monitoring WAN0 for Restoration... >> $LOGPATH
while [[ "$(nvram get wan0_enable)" == "1" ]] && [[ "$(nvram get wan1_enable)" == "1" ]] && [[ "$(nvram get wan1_primary)" == "1" ]] >/dev/null;do
if [[ "$(ping -I $(nvram get wan0_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" != "0%" ]] >/dev/null;then
  echo "$(echo $(date "+%D @ %T")) - WAN0 Restore Monitor WAN0 Offline..." >/dev/null
else
switchwan
fi
done
wanstatus
}

# WAN Disabled
wandisabled ()
{
  echo $(date "+%D @ %T"): $0 - WAN Failover Disabled: Verify Dual WAN is enabled and in Failover Mode with both WAN links enabled... >> $LOGPATH
while { [[ "$(nvram get wans_dualwan | awk '{print $2}')" == "none" ]] && [[ "$(nvram get wans_mode)" != "fo" ]] ;} \
  || { [[ "$(nvram get wan0_enable)" == "0" ]] || [[ "$(nvram get wan1_enable)" == "0" ]] ;} \
  || { [[ "$(ping -I $(nvram get wan0_ifname) $WAN0TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" != "0%" ]] || [[ "$(ping -I $(nvram get wan1_ifname) $WAN1TARGET -c $PINGCOUNT -W $PINGTIMEOUT | grep -e "packet loss" | awk '{print $7}')" != "0%" ]] ;} >/dev/null;do
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
  echo $(date "+%D @ %T"): $0 - Switching $ACTIVEWAN to primary... >> $LOGPATH
nvram set "$ACTIVEWAN"_primary=1 && nvram set "$INACTIVEWAN"_primary=0
# Change WAN IP Address
  echo $(date "+%D @ %T"): $0 - Setting WAN IP Address: $(nvram get "$ACTIVEWAN"_ipaddr)... >> $LOGPATH
nvram set wan_ipaddr=$(nvram get "$ACTIVEWAN"_ipaddr)

# Change WAN Gateway
  echo $(date "+%D @ %T"): $0 - Setting WAN Gateway: $(nvram get "$ACTIVEWAN"_gateway)... >> $LOGPATH
nvram set wan_gateway=$(nvram get "$ACTIVEWAN"_gateway)
# Change WAN Interface
  echo $(date "+%D @ %T"): $0 - Setting WAN Interface: $(nvram get "$ACTIVEWAN"_ifname)... >> $LOGPATH
nvram set wan_ifname=$(nvram get "$ACTIVEWAN"_ifname)

# Switch DNS
if [ ! -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] || [ ! -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] >/dev/null;then
  echo $(date "+%D @ %T"): $0 - Setting Manual DNS Settings... >> $LOGPATH
# Change Manual DNS Settings
if [ ! -z "$(nvram get "$ACTIVEWAN"_dns1_x)" ] >/dev/null;then
# Change DNS1 Server
  echo $(date "+%D @ %T"): $0 - Setting DNS1 Server: $(nvram get "$ACTIVEWAN"_dns1_x)... >> $LOGPATH
nvram set wan_dns1_x=$(nvram get "$ACTIVEWAN"_dns1_x)
if [[ "$(cat "$DNSRESOLVFILE" | grep -e $(echo $(nvram get "$ACTIVEWAN"_dns1_x)) | wc -l)" == "0" ]] >/dev/null;then
sed -i '1i nameserver '$(nvram get "$ACTIVEWAN"_dns1_x)'' $DNSRESOLVFILE
sed -i '/nameserver '$(nvram get "$INACTIVEWAN"_dns1_x)'/d' $DNSRESOLVFILE
else
  echo $(date "+%D @ %T"): $0 - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS1 Server... >> $LOGPATH
fi
else
  echo $(date "+%D @ %T"): $0 - No DNS1 Server for $ACTIVEWAN... >> $LOGPATH
fi
if [ ! -z "$(nvram get "$ACTIVEWAN"_dns2_x)" ] >/dev/null;then
# Change DNS2 Server
  echo $(date "+%D @ %T"): $0 - Setting DNS2 Server: $(nvram get "$ACTIVEWAN"_dns2_x)... >> $LOGPATH
nvram set wan_dns2_x=$(nvram get "$ACTIVEWAN"_dns2_x)
if [[ "$(cat "$DNSRESOLVFILE" | grep -e $(echo $(nvram get "$ACTIVEWAN"_dns2_x)) | wc -l)" == "0" ]] >/dev/null;then
sed -i '2i nameserver '$(nvram get "$ACTIVEWAN"_dns2_x)'' $DNSRESOLVFILE
sed -i '/nameserver '$(nvram get "$INACTIVEWAN"_dns2_x)'/d' $DNSRESOLVFILE
else
  echo $(date "+%D @ %T"): $0 - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS2 Server... >> $LOGPATH
fi
else
  echo $(date "+%D @ %T"): $0 - No DNS2 Server for $ACTIVEWAN... >> $LOGPATH
fi

# Blank Value Test
if [ ! -z "$(nvram get "$ACTIVEWAN"_desc)" ] >/dev/null;then
  echo $(date "+%D @ %T"): $0 - Setting DNS Test: Value Exists - $ACTIVEWAN... >> $LOGPATH
else
  echo $(date "+%D @ %T"): $0 - Setting DNS Test: Blank - $ACTIVEWAN... >> $LOGPATH
fi

# Change Automatic ISP DNS Settings
elif [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns))" ] >/dev/null;then
  echo $(date "+%D @ %T"): $0 - Setting Automatic DNS Settings from ISP: $(nvram get "$ACTIVEWAN"_dns)... >> $LOGPATH
nvram set wan_dns="$(echo $(nvram get "$ACTIVEWAN"_dns))"
if [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')" ] >/dev/null;then
if [[ "$(cat "$DNSRESOLVFILE" | grep -e $(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}') | wc -l)" == "0" ]] >/dev/null;then
sed -i '1i nameserver '$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $1}')'' $DNSRESOLVFILE
sed -i '/nameserver '$(echo $(nvram get "$INACTIVEWAN"_dns) | awk '{print $1}')'/d' $DNSRESOLVFILE
else
  echo $(date "+%D @ %T"): $0 - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS1 Server... >> $LOGPATH
fi
else
  echo $(date "+%D @ %T"): $0 - DNS1 Server not detected in Automatic ISP Settings for $ACTIVEWAN... >> $LOGPATH
fi
if [ ! -z "$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')" ] >/dev/null;then
if [[ "$(cat "$DNSRESOLVFILE" | grep -e $(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}') | wc -l)" == "0" ]] >/dev/null;then
sed -i '2i nameserver '$(echo $(nvram get "$ACTIVEWAN"_dns) | awk '{print $2}')'' $DNSRESOLVFILE
sed -i '/nameserver '$(echo $(nvram get "$INACTIVEWAN"_dns) | awk '{print $2}')'/d' $DNSRESOLVFILE
else
  echo $(date "+%D @ %T"): $0 - $DNSRESOLVFILE already updated for $ACTIVEWAN DNS2 Server... >> $LOGPATH
fi
else
  echo $(date "+%D @ %T"): $0 - DNS2 Server not detected in Automatic ISP Settings for $ACTIVEWAN... >> $LOGPATH
fi
else
  echo $(date "+%D @ %T"): $0 - No DNS Settings detected... >> $LOGPATH
fi

# Change Default Route
if [[ "$(ip route list default | grep -e "$(nvram get "$INACTIVEWAN"_ifname)" | wc -l)" != "0" ]]  >/dev/null;then
  echo $(date "+%D @ %T"): $0 - Deleting default route via $(nvram get "$INACTIVEWAN"_gateway) dev $(nvram get "$INACTIVEWAN"_ifname)... >> $LOGPATH
ip route del default
else
  echo $(date "+%D @ %T"): $0 - No default route detected via $(nvram get "$INACTIVEWAN"_gateway) dev $(nvram get "$INACTIVEWAN"_ifname)... >> $LOGPATH
fi
  echo $(date "+%D @ %T"): $0 - Adding default route via $(nvram get "$ACTIVEWAN"_gateway) dev $(nvram get "$ACTIVEWAN"_ifname)... >> $LOGPATH
ip route add default via $(nvram get "$ACTIVEWAN"_gateway) dev $(nvram get "$ACTIVEWAN"_ifname)

# Change QoS Settings
if [[ "$(nvram get qos_enable)" == "1" ]] >/dev/null;then
  echo $(date "+%D @ %T"): $0 - QoS is Enabled... >> $LOGPATH
if [[ -z "$(nvram get qos_obw)" ]] && [[ -z "$(nvram get qos_obw)" ]] >/dev/null;then
  echo $(date "+%D @ %T"): $0 - QoS is set to Automatic Bandwidth Setting... >> $LOGPATH
else
  echo $(date "+%D @ %T"): $0 - Setting Manual QoS Bandwidth Settings... >> $LOGPATH
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
  echo $(date "+%D @ %T"): $0 - QoS is Disabled... >> $LOGPATH
fi
sleep 1
done
  echo $(date "+%D @ %T"): $0 - Switched $ACTIVEWAN to primary. >> $LOGPATH
restartservices
}

# Restart Services
restartservices ()
{
for SERVICE in ${SERVICES};do
  echo $(date "+%D @ %T"): $0 - Restarting $SERVICE service... >> $LOGPATH
service restart_$SERVICE
  echo $(date "+%D @ %T"): $0 - Restarted $SERVICE service... >> $LOGPATH
done
wanevent
}

# Trigger WAN Event
wanevent ()
{
if [[ -f "/jffs/scripts/wan-event" ]] >/dev/null;then
/jffs/scripts/wan-event
logclean
else
logclean
fi
}

# Log Clean
logclean ()
{
  echo $(date "+%D @ %T"): $0 - Log Cleanup: Deleting logs older than last $LOGNUMBER log messages... >> $LOGPATH
tail -n $LOGNUMBER $LOGPATH > $LOGPATH'.tmp'
sleep 1
cp -f $LOGPATH'.tmp' $LOGPATH
sleep 1
rm -f $LOGPATH'.tmp'
sleep 1
wanstatus
}
scriptstatus
