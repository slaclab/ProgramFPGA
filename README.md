# Bash script to program the HPS FPGA image.

[DOE Code](https://www.osti.gov/doecode/biblio/79154)

## Overview

The propose of this bash script is to automatize the procedure of loading a new image into your FPGA.

You just need to know:
- the **shelfmanager** name of the crate where your carrier is installed,
- in which **slot** number,
- the name of the **cpu** connected to the crate, and
- the path to your **MCS** file (**MCS.GZ** files are also accepted).

The script will use by default the second stage boot method, but you can choose using the first stage boot method instead with option -f|--fsb.

The script will by default assume that the IP address of the CPU connected to the FPGA is 10.(crate ID).(slot number + 100).1. You can change the last octect number with option -a|--addr

The script will use by default the username "laci", but you can change it with option -u|–user.

You can run the script from any CPU. It will automatically connect to the CPU connected to the FPGA (defined with the option -c|-cpu), it will detect the architecture used by the cpu and choose the right FirmwareLoader binary for it. Currently it supports: `rhel6-x86_64`, `buildroot-2015.02-x86_64` and `buildroot-2016.11.1-x86_64`.

You can also run the script from the CPU with direct connection with the CPU. In that case you can omit the -c|-cpu and localhost will be used.


## Install

After cloning the repository, follow the instruction in  **README.dependencies.md**

## Script usage:

```
ProgramFPGA.bash -s|--shelfmanager shelfmanager_name -n|--slot slot_number -m|--mcs mcs_file [-c|--cpu cpu_name] [-u|--user cpu_ser_name] [-a|--addr cpu_last_ip_addr_octet] [-f|--fsb] [-h|--help]
    -s|--shelfmanager shelfmaneger_name      : name of the crate's shelfmanager
    -n|--slot         slot_number            : logical slot number
    -m|--mcs          mcs_file               : path to the mcs file. Can be given in GZ format
    -c|--cpu          cpu_name               : name of the cpu connected to the board (default: localhost)
    -u|--user         cpu_user_name          : username for the CPU (default: laci). Omit if localhost is used.
    -a|--addr         cpu_last_ip_addr_octet : last octect on the cpu ip addr (default to 1)
    -f|--fsb                                 : use first stage boot (default to second stage boot)
    -h|--help                                : show this message
```

## Examples:

* Program a FPGA connected to the same CPU the script is being used

```
ProgramFPGA.bash --shelfmanager shelfmanager_name --slot slot_number --mcs mcs_file
```

* Program a FPGA connected to a remote linuxRT CPU (with username "laci")

```
ProgramFPGA.bash --shelfmanager shelfmanager_name --slot slot_number --mcs mcs_file --cpu cpu_name
```

* Program a FPGA connected to a remote CPU with a specific username

```
ProgramFPGA.bash --shelfmanager shelfmanager_name --slot slot_number --mcs mcs_file --cpu cpu_name --user cpu_user_name
```

* Program a FPGA using the first stage boot method

```
ProgramFPGA.bash --shelfmanager shelfmanager_name --slot slot_number --mcs mcs_file --fsb
```

* Program a FPGA using a compressed MCS file (.gz)

```
ProgramFPGA.bash --shelfmanager shelfmanager_name --slot slot_number --mcs mcs_file.gz
```
