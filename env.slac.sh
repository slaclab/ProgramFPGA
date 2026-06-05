if [ -z "$ARCH" ] ; then
  MACH=`uname -m`
  VERS=`uname -v`
  REL=`uname -r`
  if  echo $VERS | grep -q "PREEMPT[_| ]RT" ; then
    if  echo $REL | grep -q '6[.]12[.]16' ; then
      ARCH=buildroot-2025.02-
    elif  echo $REL | grep -q '4[.]14[.]139' ; then
      ARCH=buildroot-2019.08-
    elif  echo $REL | grep -q '4[.]8[.]11' ; then
      ARCH=buildroot-2016.11.1-
    elif echo $REL | grep -q '3[.]18[.]11' ; then
      ARCH=buildroot-2015.02-
    else
      echo "Unable to determine buildroot version" >&2
    fi
  elif echo $REL | grep -q el6 ; then
    ARCH=rhel6-
  elif echo $REL | grep -q el7 ; then
    ARCH=rhel7-
  elif echo $REL | grep -q el8 ; then
    ARCH=rhel8-
  elif echo $REL | grep -q el9 ; then
    ARCH=rhel9-
  elif echo $VERS | grep -q 22.04 ; then
    ARCH=ubuntu2204-
  elif echo $VERS | grep -q 24.04 ; then
    ARCH=ubuntu2404-
  else
    ARCH="linux-"
  fi
  ARCH=$ARCH$MACH
fi
if [ -z $ARCH ] ; then
  echo ""
else
  echo "$ARCH"
  # TOPDIR is replaced by 'make'!
  #. /sdf/sw/epics/package/cpsw/framework/R4.6.1/${ARCH}/bin/env-*.sh
fi
