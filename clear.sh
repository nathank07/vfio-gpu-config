# Get the current bound vfio ids
output=$(sudo kernelstub -p 2>&1 | grep "vfio.pci-ids=")
current_pci_ids=$(echo ${output#*vfio.pci-ids=} | cut -d' ' -f1)

printf "\nClearing VFIO config...\n"

# Remove kernelstub parameters

printf "\nRunning sudo kernelstub -d vfio.pci-ids=${current_pci_ids}\n\n"
sudo kernelstub -d vfio.pci-ids=${current_pci_ids}

# Remove modprobe.d/vfio.conf parameters
printf "$(cat /etc/modprobe.d/vfio.conf | grep "options vfio-pci ids=${pci_ids}")"
sudo sed -i 's/options vfio-pci ids=.*/options vfio-pci ids=0000:0000/' /etc/modprobe.d/vfio.conf
printf " in /etc/modprobe.d/vfio.conf file changed to: \n\n"
echo "$(cat /etc/modprobe.d/vfio.conf | sed 's/^/\t/')"

# Change /etc/X11/xorg.conf

printf "\nSetting /etc/X11/xorg.conf display monitor to PCI:1:0:0\n\n"

sudo sed -i 's/BusID.*/BusID          "PCI:1:0:0"/' /etc/X11/xorg.conf
echo "$(cat /etc/X11/xorg.conf | grep -i "BusID")"
printf "\nClearing of VFIO config complete\n\n"