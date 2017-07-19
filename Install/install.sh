#!/bin/bash

################################################################
# Description:
#  This script will setup Arch with UEFI boot. Just change some
#  of the variables and execute!
#
# WARNING:
#  Please read through this entire script prior to execution.
#  Arch is a great way to learn Linux beyond the "noob" level.
#
#
# FILE:
#   arch-installer.sh
#
#
# Author: Paragonsec
# Date: 7/15/2017
################################################################

# Version
VERSION="v0.1.0"

# Languages
lang1=en_UTF-8

# Timezone
locale=US/Centeral

# Hostname (Change)
host=arch

# Root Password (Change)
password=supersecretpass


# Hard Drive Partition Size Variables #

# Root (/boot)
boot=514

# Root (/)
root=2000

# Swap
swap=1000

# Drive numbers
num1=1
num2=2
num3=3
num4=4

# DO NOT ALTER!!!!!
boot_start=1
boot_end=$(($boot_start+$boot))

swap_start=$boot_end
swap_end=$(($swap_start+$swap))

root_start=$swap_end
root_end=$(($root_start+$root))

home_start=$root_end


checkInternet()
{

    echo "Checking to see if you have internet access!"
    wget -q --tries=10 --timeout=20 --spider http://google.com
    if [[ $? -eq 0 ]]; then
            echo "Online"
            echo "Continuing Installation"
            timedatectl set-ntp true
    else
            echo "Offline"
            echo "No internet, please consult Arch Wiki for assistance"
            exit 0
    fi

}

drivePartition()
{

    echo "Available Drives..."
    lsblk
    
    echo "Please input the drive you wish to format and partition: "
    read -r drive

    # Using Parted to create partitions
    parted -s /dev/$drive mklabel gpt 1>/dev/null
    parted -s /dev/$drive mkpart ESP fat32 $boot_start $boot_end 1>/dev/null
    parted -s /dev/$drive set 1 boot on 1>/dev/null
    parted -s /dev/$drive mkpart primary linux-swap $swap_start $swap_end 1>/dev/null
    parted -s /dev/$drive mkpart primary ext4 $root_start $root_end 1>/dev/null
    parted -s -- /dev/$drive mkpart primary ext4 $home_start -0 1>/dev/null

    # Format Partitions
    echo "Formating boot partition"
    mkfs.fat -F32 /dev/$drive$num1 1>/dev/null
    sleep 1
    echo "Formating root partition"
    mkfs.ext4 /dev/$drive$num3 1>/dev/null
    sleep 1
    echo "Formating home partition"
    mkfs.ext4 /dev/$drive$num4 1>/dev/null

    # Setup and start swap partition
    echo "Formating swap partition"
    mkswap /dev/$drive$num2
    swapon /dev/$drive$num2

    # Mount partitions
    echo "Mounting root partition"
    mount -o noatime /dev/$drive$num3 /mnt
    echo "Mounting boot partition"
    mkdir /mnt/boot
    mount -o noatime,nodev,noexec,nosuid /dev/$drive$num1 /mnt/boot
    echo "Mounting home partition"
    mkdir /mnt/home
    mount -o noatime,nodev,nosuid /dev/$drive$num4 /mnt/home

}


pacstrapInstall()
{

    echo "Installing base and base-devel"
    pacstrap /mnt base base-devel

    echo "Running genfstab"
    genfstab -U /mnt >> /mnt/etc/fstab
}


main()
{
    echo "Welcome to the Arch Install script"
    echo $VERSION
    sleep 1

    checkInternet
    sleep 1
    drivePartition
    sleep 1
    pacstrapInstall
    sleep 1
}

main

# Remainder of Installation
arch-chroot /mnt << EOF

echo "Setting hostname"
echo $host > /etc/hostname

echo "Setting up locale.gen"
cp /etc/locale.gen /etc/locale.gen.bkp
sed 's/^#'$lang1'/'$lang1/ /etc/locale.gen > /tmp/locale
mv /tmp/locale /etc/locale.gen
rm /etc/locale.gen.bkp
locale-gen

echo "Setting up system locale"
echo $lang1 > /etc/locale.conf

echo "Setting up clock"
ln -s /usr/share/zoneinfo/$locale /etc/localetime
hwclock --systohc --utc
    
sleep 1
echo "Installing grub and efibootmgr"
pacman -S --noconfirm grub efibootmgr

sleep 10
echo "Installing GRUB UEFI"
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
mkdir /boot/EFI/boot
cp /boot/EFI/grub/grubx64.efi /boot/EFI/boot/bootx64.efi
    
echo "Setting up intel-ucode for boot"
pacman -S --noconfirm intel-ucode

echo "Generating the GRUB config"
grub-mkconfig -o /boot/grub/grub.cfg
    
echo "Installing Network Manager"
pacman -S --noconfirm networkmanager

echo "Setting up network manager"
systemctl enable NetworkManager.service
nmtui-connect
    
echo "Setting root password"
echo -e $password"\n"$password | passwd
EOF

echo "Unmounting and rebooting"
umount -R /mnt
reboot
