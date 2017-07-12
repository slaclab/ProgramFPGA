# Bash script to program the HPS FPGA image.

## Overview

The propose of this bash script is to automatize the procedure of loading a new image into your FPGA.

You just need to know:
- the *shelfmanager* name of the crate where your carrier is installed,
- in which *slot* number,
- the name of the *cpu* connected to the crate, and
- the path to your *MCS* file.

The script will use by default the second stage boot method, but you can choose using the first stage boot method instead with option -f|--fsb.

The script will by default assume that the IP address of the CPU connected to the FPGA is 10.(crate ID).(slot number + 100).1. You can change the last octect number with option -a|--addr

When the cpu uses a RT kernel, the script will use by default the username "laci", but you can change it with option -u|--user

## Script usage:
```
ProgramFPGA.bash -s|--shelfmanager shelfmanager_name -n|--slot slot_number -m|--mcs mcs_file -c|--cpu cpu_name [-u|--user cpu_user_name] [-a|--addr cpu_last_ip_octect] [-f|--fsb] [-h|--help]
  -s|--shelfmanager shelfmaneger_name      : name of the crate's shelfmanager
  -n|--slot         slot_number            : slot number
  -m|--mcs          mcs_file               : path to the mcs file
  -c|--cpu          cpu_name               : name of the cpu connected to the board
  -u|--user         cpu_user_name          : user name for CPU using RT kernels (default: laci)
  -a|--addr         cpu_last_ip_addr_octet : last octect on the cpu ip addr (default to 1)
  -f|--fsb                                 : use first stage boot (default to second stage boot)
  -h|--help                                : show this message
```