#!/bin/bash

if [[ "$(whoami)" != "root" ]]; then
    clear
    echo -e "${RED}Execute the script as root (${YELLOW}sudo -i${RED}).${NC}"
    exit 1
fi

# Define colors using ANSI escape codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Temporary file to store users created during script execution
temp_users_file="/tmp/script_temp_users.txt"
userlist_file="/etc/vsftpd.userlist"

# Function to install vsftpd
install_vsftpd() {
    # Update package list
    apt update

    # Install vsftpd and OpenSSL
    apt install -y vsftpd openssl

    touch "$userlist_file"

    # Generate a self-signed SSL certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/vsftpd.pem -out /etc/ssl/certs/vsftpd.pem -subj "/C=US/ST=State/L=City/O=Organization/CN=example.com"

    # Adjust certificate permissions
    chmod 600 /etc/ssl/private/vsftpd.pem

    # Copy the original configuration file as a backup
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

    # vsftpd.conf configuration
    cat <<EOF > /etc/vsftpd.conf
# Basic settings
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem

# Limit access to local users
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO

# Limit number of connections
max_clients=50
max_per_ip=5

# Enable passive mode and set ports
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100

# Enable protection against attacks
async_abor_enable=YES

EOF

    # Restart vsftpd service
    systemctl restart vsftpd

    echo -e "${GREEN}vsftpd installed and securely configured.${NC}"
}

# Function to add a new user
add_user() {
    read -p "Enter the new username: " username
    read -s -r -p "Enter the password for the new user: " password

    # Check if the user already exists
    if id "$username" >/dev/null 2>&1; then
        echo "User $username already exists. Removing..."
        remove_user "$username"
    fi

    # Add the new user
    useradd -m -s /bin/bash "$username"
    echo "$username:$password" | chpasswd

    # Add the user to the userlist file
    echo "$username" >> "$userlist_file"

    # Create the FTP user directory and set permissions
    user_home="/home/$username"
    mkdir -p "$user_home/ftp"
    chmod 755 "$user_home/ftp"

    # Adjust permissions of the user's root directory to make it non-writable
    chmod a-w "$user_home"

    # Add the user to the temporary file
    echo "$username" >> "$temp_users_file"

    echo -e "${GREEN}New user created: $username${NC}"
}

# Function to open necessary ports in the firewall
open_firewall_ports() {
    # Check if ufw is installed
    if command -v ufw >/dev/null 2>&1; then

        # Open necessary ports for vsftpd
        ufw allow 21/tcp
        ufw allow 22/tcp
        ufw allow 990/tcp
        ufw allow 40000:40100/tcp  # Ports used in passive mode (adjust as needed)
        ufw --force enable  # Enable the firewall
        echo -e "${GREEN}Firewall ports opened successfully.${NC}"
    else
        echo -e "${RED}UFW not installed. Ports cannot be opened.${NC}"
    fi
}

# Function to remove an existing user
remove_user() {
    local username="$1"

    # Check if the user exists before removing
    if id "$username" >/dev/null 2>&1; then
        # Remove the user and their home directory
        userdel -r "$username"

        # Remove the user from the userlist file
        sed -i "/$username/d" "$userlist_file"

        echo -e "${RED}User removed: $username${NC}"
    else
        echo "User $username does not exist."
    fi

    # Remove the user from the temporary file, if present
    [ -e "$temp_users_file" ] && sed -i "/$username/d" "$temp_users_file"
}

# Function to remove everything (users and the program completely)
remove_all() {
    # Read the temporary file and remove listed users
    while IFS= read -r username; do
        remove_user "$username"
    done < "$temp_users_file"

    # Remove vsftpd, OpenSSL, and the temporary file
    apt purge -y vsftpd openssl
    apt autoremove -y
    rm -rf /etc/vsftpd.conf /etc/vsftpd.conf.bak /etc/ssl/private/vsftpd.pem /etc/ssl/certs/vsftpd.pem /etc/vsftpd.userlist "$temp_users_file"

    # Remove the userlist file
    rm -f "$userlist_file"

    # Remove the temporary file, if it exists
    [ -e "$temp_users_file" ] && rm -f "$temp_users_file"

    systemctl restart vsftpd

    echo -e "${RED}Everything removed.${NC}"
}

# Function to change user permissions
change_user_permissions() {
    echo "Choose an option:"
    echo "1. Change write permission"
    echo "2. Change read permission"

    read -p "Enter the number of the desired option: " subchoice

    case $subchoice in
        1)
            change_write_permission
            ;;
        2)
            change_read_permission
            ;;
        *)
            echo "Invalid option. Exiting."
            ;;
    esac
}

# Function to change user write permission
change_write_permission() {
    read -p "Enter the username: " username

    if id "$username" >/dev/null 2>&1; then
        read -p "Allow write permission for user $username? (1 for yes, 2 for no): " choice
        if [ "$choice" -eq 1 ]; then
            chmod +w "/home/$username/ftp"
            sudo chmod 1777 "/home/$username/ftp"
            echo "Write permission granted for user $username."
        elif [ "$choice" -eq 2 ]; then
            chmod -w "/home/$username/ftp"
            sudo chmod 555 "/home/$username/ftp"
            echo "Write permission removed for user $username."
        else
            echo "Write permission not changed for user $username."
        fi
    else
        echo "User $username does not exist."
    fi
}

# Function to change user read permission
change_read_permission() {
    read -p "Enter the username: " username

    if id "$username" >/dev/null 2>&1; then
        read -p "Allow read permission for user $username? (1 for yes, 2 for no): " choice
        if [ "$choice" -eq 1 ]; then
            chmod +r "/home/$username/ftp"
            echo "Read permission granted for user $username."
        elif [ "$choice" -eq 2 ]; then
            chmod -r "/home/$username/ftp"
            echo "Read permission removed for user $username."
        else
            echo "Invalid option. Read permission not changed for user $username."
        fi
    else
        echo "User $username does not exist."
    fi
}

# Menu options
while true; do
    echo -e "${YELLOW}Choose an option:${NC}"
    echo -e "${YELLOW}1. Install vsftpd${NC}"
    echo -e "${YELLOW}2. Add a new user${NC}"
    echo -e "${YELLOW}3. Remove an existing user${NC}"
    echo -e "${YELLOW}4. Change user permissions${NC}"
    echo -e "${YELLOW}5. Remove everything (users and the program completely)${NC}"
    echo -e "${YELLOW}6. Open firewall ports${NC}"
    echo -e "${YELLOW}7. Exit${NC}"

    read -p "Enter the number of the desired option: " choice

    case $choice in
        1)
            install_vsftpd
            ;;
        2)
            add_user
            ;;
        3)
            read -p "Enter the username to be removed: " username
            remove_user "$username"
            ;;
        4)
            change_user_permissions
            ;;
        5)
            remove_all
            ;;
        6)
            open_firewall_ports
            ;;
        7)
            echo -e "${YELLOW}Exiting. Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
done
