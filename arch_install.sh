#!/bin/bash
set -e

DISK="/dev/sdX"
HOSTNAME="ChasePC"
USERNAME="chase"
PASSWORD="password"
LOCALE="en_US.UTF-8"
TIMEZONE="America/Chicago"

sgdisk -Z $DISK
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" $DISK
sgdisk -n 2:0:0     -t 2:8300 -c 2:"LinuxRoot" $DISK

mkfs.fat -F32 ${DISK}1
mkfs.ext4 ${DISK}2

mount ${DISK}2 /mnt
mkdir /mnt/boot
mount ${DISK}1 /mnt/boot

pacstrap /mnt base linux linux-firmware vim sudo networkmanager \
    plasma-desktop konsole dolphin sddm xorg \
    plasma-workspace-wayland xorg-xwayland \
    firefox discord steam \
    bluez bluez-utils blueman \
    pipewire pipewire-audio wireplumber \
    mesa juk

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
echo "$HOSTNAME" > /etc/hostname
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
sed -i '/#\[multilib\]/,/#Include/ s/#//' /etc/pacman.conf
pacman -Sy
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable bluetooth
bootctl install
cat <<LOADER > /boot/loader/loader.conf
default arch
timeout 3
editor no
LOADER
cat <<ENTRY > /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=$(blkid -s UUID -o value ${DISK}2) rw
ENTRY
EOF

echo "Installation complete. Reboot."
