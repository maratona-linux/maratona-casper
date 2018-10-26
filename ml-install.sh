#!/bin/bash
# This script is distributed with Maratona Linux under the terms of GPLv2

exec 2> /tmp/installerrors
export PATH="/bin:/usr/bin:/sbin:/usr/sbin"
cd /dev/disk/by-id
DISKS=($(ls|grep -i ata|grep -v part))

function errorexit()
{
  whiptail --backtitle "Maratona Linux Install - ERRORS" --title "$*" \
    --scrolltext --textbox /tmp/installerrors 15 70
  whiptail --backtitle "Maratona Linux Install" \
    --msgbox "Installation ABORTED. System will now reboot" 10 70
  exit $RETSUM
}

OPTIONS=
for disk in ${DISKS[@]}; do
  dev=$(ls -l $disk|awk -F'/' '{print $NF}')
  if [[ "$dev" == "sr0" ]]; then continue;fi
  OPTIONS+="$dev $disk "
done

whiptail --backtitle "Maratona Linux Install" --title "Maratona Linux Install" \
  --nocancel \
  --menu "Where should I install Maratona Linux?" 15 70 5 $OPTIONS 2>/tmp/choice

DEVICE=/dev/$(</tmp/choice)

whiptail --backtitle "Maratona Linux Install" --title "Maratona Linux Install" \
  --inputbox "ATTENTION: This operation in IRREVERSIBLE! All data will be lost. Are you sure? Write 'I am sure' if you are sure" 15 70 2>/tmp/choice

RESP="$(< /tmp/choice)"

if [[ "$RESP" != "I am sure" ]]; then
  echo "$RESP != I am sure" > /tmp/installerrors
  RETSUM=3
  errorexit "Wrong Confirmation Message"
  exit $RETSUM
fi
echo "INSTALLING IN $DEVICE"

swapoff -a

RETSUM=0
sgdisk -og ${DEVICE}
((RETSUM+=$?))
sgdisk -n 1:2048:4095 -t 1:ef02 ${DEVICE}
((RETSUM+=$?))
sgdisk -n 2:0:+100M -t 2:ef00 ${DEVICE}
((RETSUM+=$?))
sgdisk -n 3:0:+4G ${DEVICE}
((RETSUM+=$?))
sgdisk -n 4:0:+4G ${DEVICE}
((RETSUM+=$?))
sgdisk -n 5:0:+8G ${DEVICE}
((RETSUM+=$?))
sgdisk -n 6:0:+4G -t 6:8200 ${DEVICE}
((RETSUM+=$?))

if (( RETSUM != 0 )); then
  errorexit "SGDISK Error"
  exit $RETSUM
fi

#sleep 1
#cfdisk ${DEVICE}

mkfs.vfat -F32 -n GRUB2EFI ${DEVICE}2
((RETSUM+=$?))
mkfs.ext4 -L maratonalinux -F -O ^has_journal ${DEVICE}3
((RETSUM+=$?))
mkfs.ext4 -L casper-rw -F ${DEVICE}4
((RETSUM+=$?))
mkfs.ext4 -L home-rw -F ${DEVICE}5
((RETSUM+=$?))
mkswap ${DEVICE}6
((RETSUM+=$?))

if (( RETSUM != 0 )); then
  errorexit "MKFS Error"
  exit $RETSUM
fi

gdisk ${DEVICE} << EOF
r
h
1 2 3
N

N

N

Y
x
h
w
Y
EOF
((RETSUM+=$?))
if (( RETSUM != 0 )); then
  errorexit "GDISK Error"
  exit $RETSUM
fi

mkdir -p /media/usbvirtual
mount ${DEVICE}3 /media/usbvirtual
((RETSUM+=$?))
if (( RETSUM != 0 )); then
  errorexit "Mount ${DEVICE}3"
  exit $RETSUM
fi

mkdir -p /media/usbvirtual/boot/efi
mount ${DEVICE}2 /media/usbvirtual/boot/efi
((RETSUM+=$?))
if (( RETSUM != 0 )); then
  errorexit "Mount ${DEVICE}3"
  exit $RETSUM
fi

grub-install --target=x86_64-efi --recheck --removable --boot-directory=/media/usbvirtual/boot --efi-directory=/media/usbvirtual/boot/efi
((RETSUM+=$?))
grub-install --target=i386-pc --recheck --boot-directory=/media/usbvirtual/boot ${DEVICE}
((RETSUM+=$?))
if (( RETSUM != 0 )); then
  errorexit "GRUB Install"
  exit $RETSUM
fi

cat > /media/usbvirtual/boot/grub/grub.cfg << EOF
#insmod part_gpt
#insmod fat
#insmod ext2

set timeout=10

#echo 'Carregando o Maratona Linux ...'
#linux /casper/vmlinuz boot=casper persistent toram
#initrd /casper/initrd.gz
#boot
menuentry "Maratona Linux Default" {
	echo 'Carregando o Maratona Linux ...'
	linux /casper/vmlinuz boot=casper persistent ml=20181025 installed
	initrd /casper/initrd.gz
}
menuentry "Maratona Linux - Factory Reset" {
	echo 'Maratona Linux - Factory Reset...'
	linux /casper/vmlinuz boot=casper persistent ml=20181025 factoryreset
	initrd /casper/initrd.gz
}
EOF
((RETSUM+=$?))

rsync -aHx --progress /cdrom/{casper,cdrom,README.diskdefines} /media/usbvirtual
((RETSUM+=$?))
if (( RETSUM != 0 )); then
  errorexit "RSYNC ERROR"
  exit $RETSUM
fi

whiptail --backtitle "Maratona Linux Install" --title "Maratona Linux Install" \
  --msgbox "Installation SUCCESS." 10 70
umount /media/usbvirtual/boot/efi
umount /media/usbvirtual

exit 0
