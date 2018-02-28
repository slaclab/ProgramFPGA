#!/usr/bin/env bash
#-----------------------------------------------------------------------------
# Title      : ProgramFPGA
#-----------------------------------------------------------------------------
# File       : ProgramFPGA.bash
# Created    : 2016-11-14
#-----------------------------------------------------------------------------
# Description:
# Bash script to program the HPS FPGA image
#-----------------------------------------------------------------------------
# This file is part of the ProgramFPGA software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

###############
# Definitions #
###############

# TOP directory, replacing the slac.stanford.edu synlink by slac
# which is not always present in the linuxRT CPUs
TOP=$(dirname -- "$(readlink -f $0)" | sed 's/slac.stanford.edu/slac/g')

# Site specific configuration
CONFIG_SITE=$TOP/config.site

# YAML files location
YAML_TOP=$TOP/yaml

# Source site specific configurations
if [ ! -f "$CONFIG_SITE" ]; then
  echo "$CONFIG_SITE file not found!"
  exit
fi
source $CONFIG_SITE

if [ -z "$FIRMWARELOADER_TOP" ]; then
  echo "The location of FirmwareLoader was note defined!. Please update your $CONFIG_SITE file."
  exit
fi

########################
# Function definitions #
########################

# Usage message
usage() {
    echo "usage: ProgramFPGA.bash -s|--shelfmanager shelfmanager_name -n|--slot slot_number -m|--mcs mcs_file -c|--cpu cpu_name [-u|--user cpu_ser_name] [-a|--addr cpu_last_ip_addr_octet] [-f|--fsb] [-h|--help]"
    echo "    -s|--shelfmanager shelfmaneger_name      : name of the crate's shelfmanager"
    echo "    -n|--slot         slot_number            : logical slot number"
    echo "    -m|--mcs          mcs_file               : path to the mcs file. Can be given in GZ format"
    echo "    -c|--cpu          cpu_name               : name of the cpu connected to the board (default: localhost)"
    echo "    -u|--user         cpu_user_name          : username for the CPU (default: laci)"
    echo "    -a|--addr         cpu_last_ip_addr_octet : last octect on the cpu ip addr (default to 1)"
    echo "    -f|--fsb                                 : use first stage boot (default to second stage boot)"
    echo "    -h|--help                                : show this message"
    echo
    exit
}

# Get the Build String
getBuildString()
{
    ADDR=0x1000
    ADDR_STEP=0x10
    BS_LEN=0x100
    for i in $( seq 1 $((BS_LEN/ADDR_STEP)) ); do
      BS=$BS$(ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 $((ADDR/0x100)) $((ADDR%0x100)) $ADDR_STEP)
      ADDR=$((ADDR+ADDR_STEP))
    done

    echo $BS
}

# Get FPGA Version
getFpgaVersion()
{
    echo $(ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0x04 0xf2 0x04)
}

# Set 1st stage boot
setFirstStageBoot()
{
    printf "Setting boot address to 1st stage boot...         "
    ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF1 0 0 0 0 &> /dev/null
    sleep 1
    ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF0 &> /dev/null
    sleep 1
    printf "Done\n"
    rebootFPGA
}

# Set 2nd stage boot
setSecondStageBoot()
{
    printf "Setting boot address back to 2nd stage boot...    "
    ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF1 4 0 0 0 &> /dev/null
    sleep 1
    ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF0 &> /dev/null
    sleep 1
    printf "Done\n"
    rebootFPGA
}

# Reboot FPGA
rebootFPGA()
{
    RETRY_MAX=10
    RETRAY_DELAY=10

    printf "Sending reboot command to FPGA...                 "
    ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x2C 0x0A 0 0 2 0 &> /dev/null
    sleep 1
    ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x2C 0x0A 0 0 1 0 &> /dev/null
    printf "Done\n"

    printf "Waiting for FPGA to boot...                       "
    # Wait until FPGA boots
    for i in $(seq 1 $RETRY_MAX); do
        sleep $RETRAY_DELAY
        BSI_STATE=$(ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF4 2> /dev/null | awk '{print $1}')
        EXIT_CODE=$?
        if [ "$EXIT_CODE" -eq 0 ] && [ $BSI_STATE -eq 3 ]; then
            DONE=1
            break
        fi
    done

    if [ -z $DONE ]; then
        printf "FPGA didn't boot after $(($RETRY_MAX*$RETRAY_DELAY)) seconds. Aborting...\n\n"
        exit
    else
        printf "FPGA booted after $((i*$RETRAY_DELAY)) seconds\n"
    fi
}

# Get FPGA's MAC address via IPMI
getMacIpmi()
{
    MAC=$(ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0x02 0x00 | awk '{print $2 ":" $3 ":" $4 ":" $5 ":" $6 ":" $7}')

    echo $MAC
}
# Get FPGA's MAC address from arp table
getMacArp()
{
    MAC=$($CPU_EXEC cat /proc/net/arp | grep $FPGA_IP | grep -v 00:00:00:00:00:00 | awk '{print $4}')

    echo $MAC
}

# Try to arping the FPGA and get its MAC address
getMacArping()
{
    if $CPU_EXEC "su -c '/usr/sbin/arping -c 2 -I $CPU_ETH $FPGA_IP' &> /dev/null" ; then
        MAC=$($CPU_EXEC "su -c '/usr/sbin/arping -c 2 -I $CPU_ETH $FPGA_IP'" | grep -oE "([[:xdigit:]]{2}(:)){5}[[:xdigit:]]{2}")
        echo $MAC
    else
        echo
    fi
}

#############
# Main body #
#############

# Verify inputs arguments
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -s|--shelfmanager)
    SHELFMANAGER="$2"
    shift
    ;;
    -n|--slot)
    SLOT="$2"
    shift
    ;;
    -m|--mcs)
    MCS_FILE_NAME=$(readlink -e "$2")
    shift
    ;;
    -c|--cpu)
    CPU_NAME="$2"
    shift
    ;;
    -u|--user)
    CPU_USER="$2"
    shift
    ;;
    -a|--addr)
    CPU_OCTET="$2"
    shift
    ;;
    -f|--fsb)
    USE_FSB=1
    shift
    ;;
    -h|--help)
    usage
    ;;
    *)
    echo
    echo "Unknown option"
    usage
    ;;
esac
shift
done

echo

# Verify mandatory parameters
if [ -z "$SHELFMANAGER" ]; then
    echo "Shelfmanager not defined!"
    usage
fi

if [ -z "$SLOT" ]; then
    echo "Slot number not defined!"
    usage
fi

if [ ! -f "$MCS_FILE_NAME" ]; then
    echo "MCS file not found!"
    usage
fi

# Verify optional parameters
if [ -z $CPU_USER ]; then
    CPU_USER="laci"
fi

if [ -z $CPU_OCTET ]; then
    CPU_OCTET="1"
fi

# Check if the CPU to be used is local or remote
if [ -z "$CPU_NAME" ]; then
    # Set the CPU_NAME variable to localhost.
    CPU_NAME=$(hostname)
    printf "Using local CPU: $CPU_NAME\n"

    # Is the CPU is local, execute the commands directly.
    CPU_EXEC="eval"
else
    # Check connection with cpu. Exit on error
    printf "Using remote CPU: $CPU_NAME\n"
    printf "Checking connection with remote CPU...            "
    if ! ping -c 2 $CPU_NAME &> /dev/null ; then
        printf "CPU not reachable!\n"
        exit
    else
        printf "Connection OK!\n"
    fi

    # If the CPU is remote, execute the commands via SSH
    CPU_EXEC="ssh -x $CPU_USER@$CPU_NAME"
fi

# Check kernel version on CPU
printf "Looking for CPU kernel type...                    "
RT=$($CPU_EXEC /bin/uname -r | grep rt)
if [ -z $RT ]; then
    printf "non-RT kernel\n"
    ARCH=rhel6-x86_64
else
    printf "RT kernel\n"

    # Check buildroot version
    printf "Looking for Buildroot version...                  "
    BR2015=$($CPU_EXEC /bin/uname -r | grep 3.18.11)
    if [ $BR2015 ]; then
        printf "buildroot-2015.02-x86_64\n"
        ARCH=buildroot-2015.02-x86_64
    else
        BR2016=$($CPU_EXEC /bin/uname -r | grep 4.8.11)
        if [ $BR2016 ]; then
            printf "buildroot-2016.11.1\n"
            ARCH=buildroot-2016.11.1-x86_64
        else
            prtinf "Buildroot version not supported!"
            exit
        fi
    fi
fi

# Choosing the appropiate programming tool binary
FW_LOADER_BIN=$FIRMWARELOADER_TOP/$ARCH/bin/FirmwareLoader

# YAML definiton used by the programming tool
if [ $USE_FSB ]; then
    YAML_FILE=$YAML_TOP/1sb/FirmwareLoader.yaml
else
    YAML_FILE=$YAML_TOP/2sb/FirmwareLoader.yaml
fi

# Check connection with shelfmanager. Exit on error
printf "Checking connection with the shelfmanager...      "
if ! ping -c 2 $SHELFMANAGER &> /dev/null ; then
    printf "Shelfmanager unreachable!\n"
    exit
else
    printf "Connection OK!\n"
fi

# Check if the MCS is reachable on the CPU
printf "Check if the MCS is reachable in the CPU...       "
if $CPU_EXEC [ -f $MCS_FILE_NAME ] ; then
    printf "File was found on CPU!\n"
else
    printf "File was not found on CPU!\n"
    usage
fi

# Checking if MCS file was given in GZ format
printf "Verifying if MCS file is compressed...            "
if [[ $MCS_FILE_NAME == *.gz ]]; then
    printf "Yes, GZ file detected.\n"

    # Extract the MCS file into the remoe host's /tmp folder
    MCS_FILE=/tmp/$(basename "${MCS_FILE_NAME%.*}")

    printf "Extracting GZ file into CPU disk...               "
    $CPU_EXEC "zcat $MCS_FILE_NAME > $MCS_FILE"

    if [ "$?" -eq 0 ]; then
        printf "Done!\n"
    else
        printf "ERROR extracting MCS file. Aborting...\n\n"
        exit
    fi

else
    # If MCS file is not in GZ format, use the original file instead
    printf "No, MCS file detected.\n"
    MCS_FILE=$MCS_FILE_NAME
fi

# Programing methos to use
printf "Programing method to use:                         "
if [ $USE_FSB ]; then
    printf "1st stage boot\n"
else
    printf "2nd stage boot\n"
fi

# Calculate IPMB address based on slot number
IPMB=$(expr 0128 + 2 \* $SLOT)
printf "IPMB address:                                     0x%X\n" $IPMB

# Read crate ID from the shelfmanager, as a 4-digit hex number
printf "Looking for crate ID...                           "
CRATE_ID=`printf %04X  $((0x$(ipmitool -I lan -H $SHELFMANAGER  -t $IPMB -b 0 -A NONE raw 0x34 0x04 0xFD 0x02 | awk '{ print $1 + $2*256 }')))`

if [ -z $CRATE_ID ]; then
    printf "Error getting crate ID\n"
    exit
else
    printf "0x$CRATE_ID\n"
fi

# Calculate FPGA IP subnet from the crate ID
SUBNET="10.$((0x${CRATE_ID:0:2})).$((0x${CRATE_ID:2:2}))"

# Calculate FPGA IP last octect from the slot number
FPGA_IP="$SUBNET.$(expr 100 + $SLOT)"
printf "FPGA IP address:                                  $FPGA_IP\n"

# Calculate CPU IP address connected to the FPGA
CPU_IP="$SUBNET.$CPU_OCTET"
printf "CPU IP address:                                   $CPU_IP\n"

# Check network interface name on CPU connected to the FPGA based on its IP address. Exit on error
printf "Looking interface connected to the FPGA...        "
CPU_ETH=$($CPU_EXEC /sbin/ifconfig | grep -wB1 $CPU_IP | awk 'NR==1{print $1}')

if [ -z $CPU_ETH ]; then
    printf "Interface not found!\n"
    printf "\n"
    printf "Aborting as the interace connected to the FPGA was not found.\n"
    printf "Make sure an interface is configured correctly based on the shelfmanager's crateID\n"
    printf "\n"
    exit
else
    printf "$CPU_ETH\n"
fi

# Check connection between CPU and FPGA.
printf "Testing CPU and FPGA connection (with ping)...    "

# Trying first with ping
if $($CPU_EXEC /bin/ping -c 2 $FPGA_IP &> /dev/null) ; then
    printf "FPGA connection OK!\n"

    # Get the MAC address from the CPU ARP table
    MAC_ARP=$(getMacArp)
else
    # On nor-RT linux, exit in case of error
    if [ -z $RT ]; then
        printf "FPGA unreachable!\n"
        exit
    else
        # But on linux-RT, we try with arping first.
        printf "Failed!\n"
        printf "Testing CPU and FPGA connection (with arping)...  "

        # In this case, we also get the MAC address from the arping command
        # as Aarping doesn't update the ARP table
        MAC_ARP=$(getMacArping)

        if [ -z MAC_ARP ]; then
            printf "FPGA unreachable!\n"
            exit
        else
            printf "FPGA connection OK!\n"
        fi
    fi
fi

# Check if FPGA's MAC get via IPMI and ARP match
MAC_IPMI=$(getMacIpmi)
printf "FPGA's MAC address read via IPMI:                 $MAC_IPMI\n"
printf "FPGA's MAC address read from ARP:                 $MAC_ARP, "
if [ "$MAC_IPMI" == "$MAC_ARP" ]; then
    printf "They match!\n"
else
    printf "They don't match\n"

    printf "\n"
    printf "Aborting as the MAC adress checking failed.\n"
    printf "Make sure the CPU is connecte to the correct ATCA crate\n"
    printf "\n"
    exit
fi

# Current firmware build string from FPGA
printf "Current firmware build string:                    "
BS_OLD=$(getBuildString)
for c in $BS_OLD ; do printf "\x$c" ; done
printf "\n"

# Current firmware version from FPGA
printf "Current FPGA Version:                             "
VER_OLD=$(getFpgaVersion)
for c in $VER_OLD ; do VER_SWAP_OLD="$c"$VER_SWAP_OLD ; done
printf "0x$VER_SWAP_OLD\n"

# If 1st stage boot method is used, then:
if [ $USE_FSB ]; then
    # Change bootload address and reboot
    setFirstStageBoot

    # Read FSB firmware build string
    printf "1st stage boot firmware build string:             "
    BS_FSB=$(getBuildString)
    for c in $BS_FSB ; do printf "\x$c" ; done
    printf "\n"

    # Read FSB firmware version
    printf "1st stage boot FPGA Version:                      "
    VER_FSB=$(getFpgaVersion)
    for c in $VER_FSB ; do VER_SWAP_FSB="$c"$VER_SWAP_FSB ; done
    printf "0x$VER_SWAP_FSB\n"
fi

# Load image into FPGA
printf "Programming the FPGA...\n"
$CPU_EXEC $FW_LOADER_BIN -r -Y $YAML_FILE -a $FPGA_IP $MCS_FILE

# Catch the return value from the FirmwareLoader application (0: Normal, 1: Error)
RET=$?

# Show result of the firmaware loading proceccess
printf "\n"
if [ "$RET" -eq 0 ]; then
    printf "FPGA programmed successfully!\n\n"
else
    printf "ERROR: Errors were found during the FPGA Programming phase (Error code $RET)\n\n"
fi

# If 1st stage boot was used, return boot address to the second stage boot
if [ $USE_FSB ]; then
    setSecondStageBoot
fi

# If FirmwareLoader returned with errors, end script here
if [ "$RET" -ne 0 ]; then
    printf "\n"
    printf "Aborting as the FirmwareLoader failed\n"
    printf "\n"
    exit
fi

# If 2st stage boot was not used, reboot FPGA.
# If 1st stage boot was used, a reboot was done when returning to the second stage boot
if [ -z $USE_FSB ]; then
    rebootFPGA
fi

# Read the new firmware build string
printf "New firmware build string:                        "
BS_NEW=$(getBuildString)
for c in $BS_NEW ; do printf "\x$c" ; done
printf "\n"

# Read the new firmware version
printf "New FPGA Version:                                 "
VER_NEW=$(getFpgaVersion)
for c in $VER_NEW ; do VER_SWAP_NEW="$c"$VER_SWAP_NEW ; done
printf "0x$VER_SWAP_NEW\n"

# Print summary
printf "\n"
printf "  SUMMARY:\n"
printf "============================================================\n"

printf "Programing method used:                           "
if [ $USE_FSB ]; then
    printf "1st stage boot\n"
else
    printf "2nd stage boot\n"
fi

printf "Shelfnamager name:                                $SHELFMANAGER\n"

printf "Crate ID:                                         $CRATE_ID\n"

printf "Slot number:                                      $SLOT\n"

printf "IPMB address:                                     0x%x\n" $IPMB

printf "FPGA IP address:                                  $FPGA_IP\n"

printf "CPU name:                                         $CPU_NAME\n"

printf "CPU interface name (to FPGA):                     $CPU_ETH\n"

printf "CPU IP address (to FPGA):                         $CPU_IP\n"

printf "CPU kernel type:                                  "
if [ -z $RT ] ; then
    printf "non-RT"
else
    printf "RT"
fi
printf "\n"

printf "MCS file:                                         $MCS_FILE_NAME\n"

printf "Programming method used:                          "
if [ $USE_FSB ]; then
    printf "1st stage boot\n"
else
    printf "2sn stage boot\n"
fi

printf "Old firmware build string:                        "
for c in $BS_OLD ; do printf "\x$c" ; done
printf "\n"

printf "Old FPGA version:                                 0x$VER_SWAP_OLD\n"
if [ $USE_FSB ]; then
    printf "1st stage boot firmware build string:             "
    for c in $BS_FSB ; do printf "\x$c" ; done
    printf "\n"

    printf "1st stage boot FPGA Version:                      0x$VER_SWAP_FSB\n"
fi

printf "New firmware build string:                        "
for c in $BS_NEW ; do printf "\x$c" ; done
printf "\n"

printf "New FPGA version:                                 0x$VER_SWAP_NEW\n"

printf "Connection between CPU and FPGA (using ping):     "
# Trying first with ping
if $CPU_EXEC "/bin/ping -c 2 $FPGA_IP &> /dev/null" ; then
    printf "FPGA connection OK!\n"
else
    # On nor-RT linux, the test failed
    if [ -z $RT ]; then
        printf "FPGA unreachable!\n"
    else
        # But on linux-RT, we try with arping first
        printf "Failed!\n"
        printf "Connection between CPU and FPGA (using arping):   "

        if ! $CPU_EXEC "su -c '/usr/sbin/arping -c 2 -I $CPU_ETH $FPGA_IP' &> /dev/null" ; then
            printf "FPGA unreachable!\n"
        else
            printf "FPGA connection OK!\n"
        fi
    fi
fi

printf "\nDone!\n\n"
