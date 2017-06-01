#!/usr/bin/env bash

# Usage message
usage() {
    echo "usage: ProgramFPGA.bash -s|--shelfmanager shelfmanager_name -n|--slot slot_number -m|--mcs mcs_file -c|--cpu cpu_name [-u|--user cpu_ser_name] [-a|--addr cpu_last_ip_addr_octet] [-f|--fsb] [-h|--help]"
    echo "    -s|--shelfmanager shelfmaneger_name      : name of the crate's shelfmanager"
    echo "    -n|--slot         slot_number            : logical slot number"
    echo "    -m|--mcs          mcs_file               : path to the mcs file"
    echo "    -c|--cpu          cpu_name               : name of the cpu connected to the board"
    echo "    -u|--user         cpu_user_name          : user name for CPU using RT kernels (default: laci)"
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
    MCS_FILE="$2"
    shift
    ;;
    -c|--cpu)
    CPU="$2"
    shift
    ;;
    -u|--user)
    RT_USER="$2"
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

if [ -z "$CPU" ]; then
    echo "CPU name not defined!"
    usage
fi

if [ -z "$SLOT" ]; then
    echo "Slot number not defined!"
    usage
fi

if [ ! -f "$MCS_FILE" ]; then
    echo "MCS file not found!"
    usage
fi

if [ -z $RT_USER ]; then
    RT_USER="laci"
fi

if [ -z $CPU_OCTET ]; then
    CPU_OCTET="1"
fi

# Programing methos to use
printf "Programing method to use:                         "
if [ $USE_FSB ]; then
    printf "1st stage boot\n"
else
    printf "2nd stage boot\n"
fi

# Check connection with shelfmanager. Exit on error
printf "Checking connection with the shelfmanager...      "
if ! ping -c 1 $SHELFMANAGER &> /dev/null ; then
    printf "Shelfmanager unreachable!\n"
    exit
else
    printf "Connection OK!\n"
fi

# Calculate IPMB address based on slot number
IPMB=$(expr 0128 + 2 \* $SLOT)
printf "IPMB address:                                     0x%X\n" $IPMB

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

# Check connection with cpu. Exit on error
printf "Checking connection with CPU...                   "
if ! ping -c 1 $CPU &> /dev/null ; then
    printf "CPU not reachable!\n"
    exit
else
    printf "Connection OK!\n"
fi

# Check kernel version on CPU
printf "Looking for CPU kernel type...                    "
RT=$(ssh -x $RT_USER@$CPU /bin/uname -r | grep rt)
if [ -z $RT ]; then
	printf "non-RT kernel\n"
	ARCH=rhel6-x86_64
else
	printf "RT kernel\n"

    # Check buildroot version
    printf "Looking for Buildroot version...                  "
    BR2015=$(ssh -x $RT_USER@$CPU /bin/uname -r | grep 3.18.11)
    if [ $BR2015 ]; then
        printf "buildroot-2015.02-x86_64\n"
    	ARCH=buildroot-2015.02-x86_64
    else
        BR2016=$(ssh -x $RT_USER@$CPU /bin/uname -r | grep 4.8.11)
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
FW_LOADER_BIN=/afs/slac/g/lcls/package/cpsw/FirmwareLoader/current/$ARCH/bin/FirmwareLoader

# YAML definiton used by the programming tool
if [ $USE_FSB ]; then
    YAML_FILE=/afs/slac/g/lcls/package/cpsw/utils/ProgramFPGA/current/yaml/fsb/FirmwareLoader.yaml
else
    YAML_FILE=/afs/slac/g/lcls/package/cpsw/utils/ProgramFPGA/current/yaml/FirmwareLoader.yaml
fi

# Read crate ID from FPGA
printf "Looking for crate ID...                           "
CRATE_ID=$(ipmitool -I lan -H $SHELFMANAGER  -t $IPMB -b 0 -A NONE raw 0x34 0x04 0xFD 0x02 | awk '{ print $1 + $2*256 }')

if [ -z $CRATE_ID ]; then
    printf "Error getting crate ID\n"
    exit
else
    printf "$CRATE_ID\n"
fi

# Calculate FPGA IP address from carte ID and slot number
FPGA_IP="10.0.$CRATE_ID.$(expr 100 + $SLOT)"
printf "FPGA IP address:                                  $FPGA_IP\n"

# Calculate CPU IP address connected to the FPGA, whic alwys ends in x.x.x.1 
CPU_IP="10.0.$CRATE_ID.$CPU_OCTET"
printf "CPU IP address:                                   $CPU_IP\n"

# Check network interface name on CPU connected to the FPGA based on its IP address. Exit on error
printf "Looking interface connected to the FPGA...        "
CPU_ETH=$(ssh -x $RT_USER@$CPU /sbin/ifconfig | grep -wB1 $CPU_IP | awk 'NR==1{print $1}')

if [ -z $CPU_ETH ]; then
    printf "Interface not found!\n"
    exit
else
    printf "$CPU_ETH\n"
fi

# If 1st stage boot method is used, then:
if [ $USE_FSB ]; then
    # Change bootload address and reboot
    printf "Setting boot address to 1st stage boot...         "
    ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF1 0 0 0 0 &> /dev/null
    ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF0 &> /dev/null
    ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF9 &> /dev/null
    sleep 20
    printf "Done\n"

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

# Check connection between CPU and FPGA.
if [ -z $RT ]; then
    if [ -z $USE_FSB ]; then
        # On non-RT linux, try ping as arping need root permissions which we don't usually have
        # But try it only when using 2nd stage boot, as ping is not implemented on 1st stage boot
        printf "Testing CPU and FPGA connection (with ping)...    "
        if ! ssh -x $RT_USER@$CPU "/bin/ping -c 1 $FPGA_IP &> /dev/null" ; then
            # We don't exit as we don't know if arping works...
            printf "FPGA unreachable!\n"
        else
            printf "OK!\n"
        fi    
    fi
else
    printf "Testing CPU and FPGA connection (with arping)...  "
    if ! ssh -x $RT_USER@$CPU "su -c '/usr/sbin/arping -c 1 -I $CPU_ETH $FPGA_IP' &> /dev/null" ; then
        # In this case we do exit in case of an error
        printf "FPGA unreachable!\n"

        # If 1st stage boot was used, return boot address to the second stage boot
        if [ $USE_FSB ]; then
            printf "Setting boot address back to 2nd stage boot...    "
            ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF1 4 0 0 0 &> /dev/null
            ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF0 &> /dev/null
            ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF3 &> /dev/null
            printf "Done\n"
        fi
        exit 
    else
        printf "FPGA connection OK!\n"
    fi
fi

# Load image into FPGA
printf "Programming the FPGA...\n"
ssh -x $RT_USER@$CPU $FW_LOADER_BIN -Y $YAML_FILE -a $FPGA_IP $MCS_FILE
printf "\n"

if [ $USE_FSB ]; then
    printf "Setting boot address back to 2nd stage boot...    "
    ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF1 4 0 0 0 &> /dev/null
    ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF0 &> /dev/null
    printf "Done\n"
fi

# Reboot the FPGA
printf "Rebooting FPGA...                                 "
ipmitool -I lan -H $SHELFMANAGER -t $IPMB -b 0 -A NONE raw 0x34 0xF3 &> /dev/null
sleep 10
printf "Done\n" 

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

printf "CPU name:                                         $CPU\n"

printf "CPU interface name (to FPGA):                     $CPU_ETH\n"

printf "CPU IP address (to FPGA):                         $CPU_IP\n"

printf "CPU kernel type:                                  " 
if [ -z $RT ] ; then 
    printf "non-RT"
else 
    printf "RT"
fi
printf "\n"

printf "MCS file:                                         $MCS_FILE\n"

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

if [ -z $RT ]; then
    # On non-RT linux, try ping as arping need root permissions which we don't usually have
    printf "Connection between CPU and FPGA (using ping):     "
    if ! ssh -x $RT_USER@$CPU "/bin/ping -c 1 $FPGA_IP &> /dev/null" ; then
        printf "FPGA unreachable!\n"
    else
        printf "OK!\n"
    fi    
else
    # on RT linux, use arping as we do have root permission here
    printf "Connection between CPU and FPGA (using arping):   "
    if ! ssh -x $RT_USER@$CPU "su -c '/usr/sbin/arping -c 1 -I $CPU_ETH $FPGA_IP' &> /dev/null" ; then
        printf "FPGA unreachable!\n"
    else
        printf "OK!\n"
    fi
fi

printf "\nDone!\n\n"
