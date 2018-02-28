#  Release notes for ProgramFPGA bash script

## R1.0.15: 2018-02-28 J. Vasquez
- Add option to use the localhost as CPU.
- Check and handler IPMI errors.
- Verify extraction of MCS file.
- Orginize order of inital testing.
- Print more status messages.
- Code cleanup.

## R1.0.14: 2018-01-29 J. Vasquez
- Fix bug: hardcoded SHM name and IPMB address.

## R1.0.13: 2018-01-10 J. Vasquez
- Verify if FPGA booted correclty after sending reboot command.
- Fix bug when using FSB metod and it didn't go back to SSB.

## R1.0.12: 2017-12-14 J. Vasquez
- Fix bug error when FPGA MAC address is not in the CPU ARP table.
- Test CPU connection earlier.
- Try to (ar)ping two times for better reliability results.
- Some code cleanup.

## R1.0.11: 2017-11-01 J. Vasquez
- Ignore empty MAC addresses from ARP table

## R1.0.10: 2017-10-11 J. Vasquez
- Fix TOP path generation, which was brokne in the R1.0.9 release.

## R1.0.9: 2017-10-11 J. Vasquez
- Get absolute path of the MCS filei given by the user.
  The user can now give a relative path to the file and it will
  be found in the remote CPU correctly.
- Add 1s delays after the ipmitool commands.
- Get the FPGA's MAC address both via IPMI and from the remote CPU
  ARP table and check they match, to avoid programming the wrong FPGA.
- Add a config.site file where the site specific configuration can be specify.
  At this moment the only content of this file is the location of the FirmwareLoaader.

## R1.0.8: 2017-08-30 J. Vasquez
- Omit the ReloadFpga feature of the FirmwareLoader.

## R1.0.7: 2017-07-13 J. Vasquez
- Fix calculation of FPGA's IP subnet based on crateID as 10.x.y

## R1.0.6: 2017-07-12 J. Vasquez
- Add support for MCS.GZ files
- Change reboot IPMI command from 0xF3 to activate/deactivate commands
  via picmg policy set

## R1.0.5: 2017-07-12 J. Vasquez
- Capture return value from FirmwareLoader and print diagnostic info.
- Avoid FPGA rebooting if FirmwareLoader fails.

## R1.0.4: 2017-06-01 J. Vasquez
- Change Build String size from 96 chars to 256.
- Add a YAML definition for the 1st stage bootloader image.
- Use functions to read the Build String and FPGA Version values.

## R1.0.3: 2017-05-31 J. Vasquez
- Use YAML for defining the register space used by the FirmwareLoader.

## R1.0.2: 2017-03-20 J. Vasquez
- Update to FirmwareLoader R1.0.1

## R1.0.1: 2017-03-20 J. Vasquez
- Adapted to the new folder structure for the FirmwareLoader.
- Added support for the new buildroot version 2016.
- Change tag name format.

## ProgramFPGA-R1-0: 2016-11-14 J. Vasquez
- First version, release 1.0
