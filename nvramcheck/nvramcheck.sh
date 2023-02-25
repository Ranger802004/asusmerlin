#!/bin/sh

# NVRAM Check Test for ASUS Routers using ASUS Merlin Firmware
# Author: Ranger802004 - https://github.com/Ranger802004/asusmerlin/
# Date: 2/25/2023
# Version: v1.0.0

# Cause the script to exit if errors are encountered
set -e
set -u

# Function to check if NVRAM Background Process is Stuck and kill PID
nvramcheck ()
{
[[ "$CHECKNVRAM" == "0" ]] >/dev/null 2>&1 && return
# Check if Background Process for NVRAM Call is still running
lastpid="$!"
if [ -z "$(ps | grep -v "grep" | awk '{print $1}' | grep -o "$lastpid")" ] >/dev/null 2>&1;then
  unset lastpid
elif [ ! -z "$(ps | grep -v "grep" | awk '{print $1}' | grep -o "$lastpid")" ] >/dev/null 2>&1;then
  kill -9 $lastpid 2>/dev/null \
  && { e=$(($e+1)) && sed -i '1s/.*/'$e'/' "/tmp/nvramcheck.tmp" ;}
  unset lastpid
fi
return
}

# Ask if NVRAM PID Checks will be performed
echo -e "Do you want to check for stuck NVRAM PIDs and kill them?  If you select no, there possibly will be stuck processes that may need to terminated."
read -p "***Enter Y for Yes or N for No*** `echo $'\n> '`" yn
case $yn in
  [Yy]* ) CHECKNVRAM="1" && break;;
  [Nn]* ) CHECKNVRAM="0" && break;;
  * ) echo -e "${RED}Invalid Selection!!! ***Enter Y for Yes or N for No***${NOCOLOR}"
esac

# Identify Router Model
MODEL="$(nvram get productid)"

# Create Error Count File
if [ ! -f "/tmp/nvramcheck.tmp" ] >/dev/null 2>&1;then
  touch -a /tmp/nvramcheck.tmp
  echo "" >> "/tmp/nvramcheck.tmp"
fi

# Set Error Count
sed -i '1s/.*/0/' "/tmp/nvramcheck.tmp"
e="$(sed -n 1p "/tmp/nvramcheck.tmp")"

# Set Loop Iterations
i=0
e=0

# Run Loop to Check NVRAM Values
while [[ "$i" -le "100000" ]] >/dev/null 2>&1;do
  # Increment loop iteration
  i=$((i+1))
  # Read NVRAM PID Kill Count
  e="$(sed -n 1p "/tmp/nvramcheck.tmp")"
  
  # Check for NVRAM values and if returned if returned null because of stuck process restore from previous value to ensure integrity of output
  while [ -z "${sync+x}" ] >/dev/null 2>&1 || [[ "$sync" == "0" ]] >/dev/null 2>&1;do
    sync="0"

    # client1
    if [ -z "${client1+x}" ] >/dev/null 2>&1 || [ -z "${zclient1+x}" ] >/dev/null 2>&1;then
      client1="$(nvram get vpn_client1_state & nvramcheck)"
      [ ! -z "$client1" ] >/dev/null 2>&1 \
      && zclient1="$client1" \
      || { unset client1 ; unset zclient1 && continue ;}
    else
      [[ "$zclient1" != "$client1" ]] >/dev/null 2>&1 && zclient1="$client1"
      client1="$(nvram get vpn_client1_state & nvramcheck)"
      [ ! -z "$client1" ] >/dev/null 2>&1 || client1="$zclient1"
    fi

    # client2
    if [ -z "${client2+x}" ] >/dev/null 2>&1 || [ -z "${zclient2+x}" ] >/dev/null 2>&1;then
      client2="$(nvram get vpn_client2_state & nvramcheck)"
      [ ! -z "$client2" ] >/dev/null 2>&1 \
      && zclient2="$client2" \
      || { unset client2 ; unset zclient2 && continue ;}
    else
      [[ "$zclient2" != "$client2" ]] >/dev/null 2>&1 && zclient2="$client2"
      client2="$(nvram get vpn_client2_state & nvramcheck)"
      [ ! -z "$client2" ] >/dev/null 2>&1 || client2="$zclient2"
    fi

    # client3
    if [ -z "${client3+x}" ] >/dev/null 2>&1 || [ -z "${zclient3+x}" ] >/dev/null 2>&1;then
      client3="$(nvram get vpn_client3_state & nvramcheck)"
      [ ! -z "$client3" ] >/dev/null 2>&1 \
      && zclient3="$client3" \
      || { unset client3 ; unset zclient3 && continue ;}
    else
      [[ "$zclient3" != "$client3" ]] >/dev/null 2>&1 && zclient3="$client3"
      client3="$(nvram get vpn_client3_state & nvramcheck)"
      [ ! -z "$client3" ] >/dev/null 2>&1 || client3="$zclient3"
    fi

    # client4
    if [ -z "${client4+x}" ] >/dev/null 2>&1 || [ -z "${zclient4+x}" ] >/dev/null 2>&1;then
      client4="$(nvram get vpn_client4_state & nvramcheck)"
      [ ! -z "$client4" ] >/dev/null 2>&1 \
      && zclient4="$client4" \
      || { unset client4 ; unset zclient4 && continue ;}
    else
      [[ "$zclient4" != "$client4" ]] >/dev/null 2>&1 && zclient4="$client4"
      client4="$(nvram get vpn_client4_state & nvramcheck)"
      [ ! -z "$client4" ] >/dev/null 2>&1 || client4="$zclient4"
    fi

    # client5
    if [ -z "${client5+x}" ] >/dev/null 2>&1 || [ -z "${zclient5+x}" ] >/dev/null 2>&1;then
      client5="$(nvram get vpn_client5_state & nvramcheck)"
      [ ! -z "$client5" ] >/dev/null 2>&1 \
      && zclient5="$client5" \
      || { unset client5 ; unset zclient5 && continue ;}
    else
      [[ "$zclient5" != "$client5" ]] >/dev/null 2>&1 && zclient5="$client5"
      client5="$(nvram get vpn_client5_state & nvramcheck)"
      [ ! -z "$client5" ] >/dev/null 2>&1 || client5="$zclient5"
    fi
    sync="1"
  done
  unset sync

  # Buffer Output
  output="$(
  clear
  echo "Router Model: "$MODEL""
  echo "Test Iteration: $i"
  echo "NVRAM PIDs Killed: "$e""
  echo -e "\n"
  echo "$client1 $client2 $client3 $client4 $client5"
  )"

  # Display Output
  echo "$output"
done

# Notify When Script Completes and Exit
echo "Test completed at Iteration: $i
exit 0
