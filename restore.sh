#!/bin/bash

: "${BACKUP_ID:=latest}"

if [ "${SKIP_RESTORE}" = "true" ]; then
    echo "SKIP_RESTORE is set, skipping restore."
    exit 0
fi

if [ -z "$(ls -A /data 2>/dev/null)" ]; then
    echo "/data is empty, checking for backups..."

    # check if any snapshot exists
    if restic -r rclone:onedrive-mc:Games/Minecraft_Servers_and_Saves/Docker snapshots --json | grep -q '"short_id"'; then
        echo "Backup found, restoring latest snapshot..."
        restic -r rclone:onedrive-mc:Games/Minecraft_Servers_and_Saves/Docker restore "${BACKUP_ID}" --tag "${BACKUP_NAME}" --target /data
    else
        echo "No backups found, skipping restore."
        exit 0
    fi
else
    echo "/data is not empty, skipping restore."
    exit 0
fi

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Please run it with sudo or as the root user."
    exit 1
fi

# Define root directory
root_dir="/data"

# Get the current date and time
current_datetime=$(date +%Y-%m-%dT%H:%M)

# Define folder names with absolute paths
folders_to_delete=("libraries" "mods" "resources" "scripts")
files_to_delete=("lwjgl3ify-forgePatches.jar" "java9args.txt" "startserver-java9.bat" "startserver-java9.sh")
config_folder="$root_dir/config"
backup_folder="$root_dir/config_backup_$current_datetime"
journey_map_folder="JourneyMapServer"
zip_file="$1"
temp_dir="/tmp/unzipped_data"

if [ ! -z "$1" ]; then
    # Check if the unzip command exists
    if ! command -v unzip &> /dev/null; then
        echo "unzip command not found. Attempting to install it..."
        if [ -x "$(command -v apt-get)" ]; then
            apt-get update && apt-get install -y unzip
        elif [ -x "$(command -v yum)" ]; then
            yum install -y unzip
        elif [ -x "$(command -v pacman)" ]; then
            pacman -Sy --noconfirm unzip
        elif [ -x "$(command -v zypper)" ]; then
            zypper install -y unzip
        else
            echo "Package manager not supported. Please install unzip manually."
            exit 1
        fi
    fi
    # Unzip the file to a temporary directory
    echo "Unzipping $zip_file to $temp_dir"
    mkdir -p "$temp_dir"
    unzip -q "$zip_file" -d "$temp_dir"
fi

# Delete specified folders if they exist
for folder in "${folders_to_delete[@]}"; do
    folder_path="$root_dir/$folder"
    if [ -d "$folder_path" ]; then
        echo "Deleting folder: $folder_path"
        rm -rf "$folder_path"
    fi
done

# Delete specific files in the root directory if they exist
for file in "${files_to_delete[@]}"; do
    file_path="$root_dir/$file"
    if [ -f "$file_path" ]; then
        echo "Deleting file: $file_path"
        rm -f "$file_path"
    fi
done

# Backup the config folder
if [ -d "$config_folder" ]; then
    echo "Creating backup of $config_folder"
    cp -r "$config_folder" "$backup_folder"
    echo "Deleting original $config_folder"
    rm -rf "$config_folder"
fi

if [ ! -z "$1" ]; then
# Copy the required folders to the /data directory
for folder in "libraries" "mods" "resources" "scripts" "config"; do
    if [ -d "$temp_dir/$folder" ]; then
        echo "Copying $folder to $root_dir"
        cp -r "$temp_dir/$folder" "$root_dir/"
    else
        echo "Warning: $folder not found in the unzipped data"
    fi
done

# Copy specific files to the /data directory
for file in "lwjgl3ify-forgePatches.jar" "java9args.txt" "startserver-java9.bat" "startserver-java9.sh"; do
    if [ -f "$temp_dir/$file" ]; then
        echo "Copying $file to $root_dir"
        cp "$temp_dir/$file" "$root_dir/"
    else
        echo "Warning: $file not found in the unzipped data"
    fi
done

# Clean up the temporary directory
echo "Cleaning up temporary data"
rm -rf "$temp_dir"
fi

# Ensure the config folder exists
if [ ! -d "$config_folder" ]; then
    echo "$config_folder does not exist. Creating it now."
    mkdir -p "$config_folder"
fi

# Restore JourneyMapServer folder from backup
if [ -d "$backup_folder/$journey_map_folder" ]; then
    echo "Restoring $journey_map_folder to $config_folder"
    cp -r "$backup_folder/$journey_map_folder" "$config_folder/"
else
    echo "Warning: $journey_map_folder not found in backup"
fi

# Change ownership of all contents in the root directory to uid 1000 and gid 1000
echo "Changing ownership of all contents in $root_dir to uid 1000 and gid 1000"
chown -R 1000:1000 "$root_dir"

echo "Script execution completed."