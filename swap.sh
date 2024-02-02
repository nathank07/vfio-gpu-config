#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    exit
fi

declare -a busIDs
declare -a pci_id_list
declare -a device_names

declare -a selected_busIDs
declare -a selected_pci_ids
declare -a selected_device_names

# Get the current bound vfio ids
output=$(sudo kernelstub -p 2>&1 | grep "vfio.pci-ids=")
current_pci_ids=$(echo ${output#*vfio.pci-ids=} | cut -d' ' -f1)
IFS=',' read -ra pci_id_array <<< "$current_pci_ids"

# Store the output of lspci in an array
mapfile -t lspci_output < <(lspci -nn | grep -iE 'nvidia|amd')
for line in "${lspci_output[@]}"; do
    # Extract the busID and pci_id from the line
    busID=$(echo "$line" | cut -d' ' -f1)
    pci_id=$(echo "$line" | grep -oP '\[\K.{9}(?=\])')
    device_name=$(echo "$line" | sed -n -e 's/^.*:\(.*\)\[.*$/\1/p')

    # Store the busID and pci_id in their respective arrays
    busIDs+=("$busID")
    pci_id_list+=("$pci_id")
    device_names+=("$device_name")
done

read -p "Manually select? (y/n): " select

if [ "$select" = "y" ]; then
    printf "\nCurrent IDs: $current_pci_ids"
    printf "\nSelect IDs to use:"

    # Display options
    for ((i=0; i<${#busIDs[@]}; i++)); do
        echo "[$i] ${busIDs[$i]} ${pci_id_list[$i]}${device_names[$i]}"
    done

    # Select options
    printf "\nSelect PCI IDs to passthrough (separated by commas):"
    read -r option_indices

    # Split the input into an array of indices
    IFS=',' read -ra indices_array <<< "$option_indices"

    for index in "${indices_array[@]}"; do
        selected_busIDs+=("${busIDs[$index]}")
        selected_pci_ids+=("${pci_id_list[$index]}")
        selected_device_names+=("${device_names[$index]}")
    done
    printf "\nSelected devices:"
    for ((i=0; i<${#selected_busIDs[@]}; i++)); do
        printf "\n${selected_device_names[$i]}"
    done
else 
    # Use the VGA and Audio driver IDs of the other card
    printf "\nCurrent devices: \n"

    # Display devices
    for line in "${lspci_output[@]}"; do
        # Extract the busID and pci_id from the line
        busID=$(echo "$line" | cut -d' ' -f1)
        pci_id=$(echo "$line" | grep -oP '\[\K.{9}(?=\])')
        device_name=$(echo "$line" | sed -n -e 's/^.*:\(.*\)\[.*$/\1/p')
        for current_pci_id in "${pci_id_array[@]}"; do
            if [[ "$current_pci_id" == "$pci_id" ]]; then
                printf "$busID$device_name\n"
            fi
        done
    done

    # Find VGA devices that are not already linked and select them to be added
    mapfile -t vga_devices < <(lspci -nn | grep -iE 'nvidia|amd' | grep -i vga)
    for line in "${vga_devices[@]}"; do
        # Extract the busID and pci_id from the line
        busID=$(echo "$line" | cut -d' ' -f1)
        pci_id=$(echo "$line" | grep -oP '\[\K.{9}(?=\])')
        device_name=$(echo "$line" | sed -n -e 's/^.*:\(.*\)\[.*$/\1/p')
        declare -i found=0
        for current_pci_id in "${pci_id_array[@]}"; do
            if [[ "$current_pci_id" == "$pci_id" ]]; then
                found=1
                break
            fi
        done
        if [[ "$found" == 0 ]]; then
            selected_busIDs+=("$busID")
            selected_pci_ids+=("$pci_id")
            selected_device_names+=("$device_name")
        fi
    done

    # Add audio devices linked to found VGA device
    audio=$(lspci -nn | grep -i "${selected_busIDs[0]::-2}" | grep -i Audio)
    selected_busIDs+=($(echo "$audio" | cut -d' ' -f1))
    selected_pci_ids+=($(echo "$audio" | grep -oP '\[\K.{9}(?=\])'))
    selected_device_names+=("$(echo "$audio" | sed -n -e 's/^.*:\(.*\)\[.*$/\1/p')")

    # Display new devices to add
    printf "\nSelected devices:\n"
    for ((i=0; i<${#selected_busIDs[@]}; i++)); do
        printf "${selected_busIDs[$i]} ${selected_device_names[$i]}\n"
    done
fi

# Clear kernelstub, modprobe, and xorg.conf

sudo ./clear.sh

# TODO: Add kernelstub parameters

#echo "Running kernelstub -d vfio.pci-ids=${current_pci_ids}"
#sudo kernelstub -d vfio.pci-ids=${current_pci_ids}
#echo "Running kernelstub -a vfio.pci-ids=$(IFS=, ; echo "${selected_pci_ids[*]}")"
#sudo kernelstub -a vfio.pci-ids=$(IFS=, ; echo "${selected_pci_ids[*]}")

# TODO: Add modprobe.d/vfio.conf

#echo "$(cat /etc/modprobe.d/vfio.conf | grep "options vfio-pci ids=${pci_ids}")"


# TODO: Add /etc/X11/xorg.conf




