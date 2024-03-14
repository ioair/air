#!/bin/bash

# Define vars
who=$USER
config="air.json"
root="" # Root folder of main.js
bash="" # Root folder of Bash script files
update=false
env=""
name=""
domain=""
port=""
peers=()
sync=""
ssl=false
ssl_key=""
ssl_cert=""
godaddy_cron=false
godaddy_key=""
godaddy_secret=""
godaddy_domain=""
godaddy_host=""

# Transform long options to short ones
for arg in $@
do
    shift
    case $arg in
        --root)         set -- $@ -r;;
        --bash)         set -- $@ -b;;
        --update)       set -- $@ -u;;
        --env)          set -- $@ -e;;
        --name)         set -- $@ -n;;
        --domain)       set -- $@ -d;;
        --port)         set -- $@ -p;;
        --peers)        set -- $@ -P;;
        --sync)         set -- $@ -S;;
        --ssl)          set -- $@ -s;;
        --godaddy_cron) set -- $@ -g;;
        *)              set -- $@ $arg
    esac
done

# Check flags
while getopts "r:b:ue:n:d:p:P:S:sg" flag
do
    case $flag in
        r) root=$OPTARG;;
        b) bash=$OPTARG;;
        u) update=true;;
        e) env=$OPTARG;;
        n) name=$OPTARG;;
        d) domain=$OPTARG;;
        p) port=$OPTARG;;
        P) [[ $OPTARG =~ ^([a-zA-Z0-9]+,)*[a-zA-Z0-9]+$ ]] && IFS=',' read -r -a peers <<< "$(echo "$OPTARG" | tr -d '[:space:]')";;
        S) sync=$OPTARG;;
        s) ssl=true;;
        c) godaddy_cron=true
    esac
done

# Config root directory
[ -z $root ] && root=`pwd` # Root folder of main.js

# Config bash directory
[ -z $bash ] && bash=$(cd `dirname $0` && pwd) # Root folder of Bash script files

# Check if jq is installed? Install jq if jq doesn's exist.
if ! command -v jq &> /dev/null
then
    sudo apt install jq
fi

# If config file exists, try to assign variables
if [ -f $root/$config ]
then
    env=`jq -r ".env" $root/$config`
    [[ -z $env || $env = "null" ]] && env=`jq -r ".env" $root/$config`

    [[ -z $name || $name = "null" ]] && name=`jq -r ".name" $root/$config`

    domain=`jq -r ".domain" $root/$config`
    [[ -z $domain || $domain = "null" ]] && domain=`jq -r ".$env.domain" $root/$config`

    port=`jq -r ".port" $root/$config`
    [[ -z $port || $port = "null" ]] && port=`jq -r ".$env.port" $root/$config`
    
    peers=($(jq -r ".peers[]" "$root/$config" 2>/dev/null || jq -r ".$env.peers[]" "$root/$config" 2>/dev/null || echo ""))
    
    [[ -z $sync || $sync = "null" ]] && sync=`jq -r ".sync" $root/$config`

    godaddy_key=`jq -r ".$env.godaddy.key" $root/$config`
    [[ -z $godaddy_key || $godaddy_key = "null" ]] && godaddy_key=`jq -r ".$env.godaddy.key" $root/$config`

    godaddy_secret=`jq -r ".$env.godaddy.secret" $root/$config`
    [[ -z $godaddy_secret || $godaddy_secret = "null" ]] && godaddy_secret=`jq -r ".$env.godaddy.secret" $root/$config`
fi

# Check if env exists
while [ -z $env ] || [[ $env = "null" ]]
do
    read -p "Please enter environment (\"production\" or \"development\"): " env
    if [ ! -z $env ] && [[ $env != "null" ]]
    then
        break
    fi
done
[ ! -z $env ] && echo "Environment: $env"

# Check if name exists
while [ -z $name ] || [[ $name = "null" ]]
do
    read -p "Please enter peer name: " name
    if [ ! -z $name ] && [[ $name != "null" ]]
    then
        break
    fi
done
[ ! -z $name ] && echo "Peer name: $name"

# Check if domain exists
while [ -z $domain ] || [[ $domain = "null" ]]
do
    read -p "Please enter domain: " domain
    if [ ! -z $domain ] && [[ $domain != "null" ]]
    then
        break
    fi
done
[ ! -z $domain ] && echo "Domain: $domain"

# Check if port exists
while [ -z $port ] || [[ $port = "null" ]]
do
    read -p "Please enter port: " port
    if [ ! -z $port ] && [[ $port != "null" ]]
    then
        break
    else
        port=8765
    fi
done
[ ! -z $port ] && echo "Port: $port"

# Ask if user wants to add peers
added=false
while true
do
    [ $added = true ] && question="Do you want to add more external peer? [Y/n]" || question="Do you want to add external peers? [Y/n]"
    read -p "$question" yn
    case $yn in
        [Yy]*)
            read -p "Please enter peer address: " peer
            if [[ ! -z $peer && $peer != "null" && " ${peers[@]} " =~ " ${peer} " ]]
            then
                echo "Peer already exists!"
            else
                peers+=($peer)
                added=true
            fi;;
        [Nn]*) break;;
        *) echo "Please answer [Y]es or [N]o."
    esac
done
[ ! -z $peers ] && echo "Peers: ${peers[@]}"

# Ask if user wants to sync network config
if [[ -z $sync || $sync = "null" ]]
then
    while true
    do
        read -p "Do you want to sync network config? [Y/n]" yn
        case $yn in
            [Yy]*) read -p "Please enter network config URL: " sync; break;;
            [Nn]*) break;;
            *) echo "Please answer [Y]es or [N]o."
        esac
    done
fi
[ ! -z $sync ] && echo "Sync network config: $sync"

# Ask if user wants automatically run system update
if [ $update = false ]
then
    while true
    do
        read -p "Do you want to automatically run system update? [Y/n]" yn
        case $yn in
            [Yy]*) update=true; break;;
            [Nn]*) update=false; break;;
            *) echo "Please answer [Y]es or [N]o."
        esac
    done
fi

# Ask if user wants ssl
if [ $ssl = false ]
then
    while true
    do
        read -p "Do you want to install LetsEncrypt SSL Certificate? [Y/n]" yn
        case $yn in
            [Yy]*) ssl=true; break;;
            [Nn]*) ssl=false; break;;
            *) echo "Please answer [Y]es or [N]o."
        esac
    done
fi

# Ask if user wants to automatically update Godaddy DNS A Record
if [ $godaddy_cron = false ]
then
    while true
    do
        read -p "Do you want to automatically update Godaddy DNS A Record? [Y/n]" yn
        case $yn in
            [Yy]*) godaddy_cron=true; break;;
            [Nn]*) godaddy_cron=false; break;;
            *) echo "Please answer [Y]es or [N]o."
        esac
    done
fi

# If user wants Godaddy DNS cronjob enabled, ask for Godaddy API Key/Secret
if [ $godaddy_cron = true ] && [ ! -z $domain ]
then
    # Check if the domain is a primary domain or subdomain
    count=`echo $domain | grep -o "\." | wc -l`
    if [ $count = 1 ] && [ -z $godaddy_host ]
    then
        godaddy_domain=$domain
        godaddy_host="@"
    elif [ $count -gt 1 ] && [[ $domain =~ ^[a-zA-Z0-9\-]*\.[a-zA-Z0-9\-]*\.[a-zA-Z0-9\-]*(\.[a-zA-Z0-9\-]*)*$ ]]
    then
        while true
        do
            read -p "Is this domain $domain a subdomain? [Y/n]" yn
            case $yn in
                [Yy]*)
                    godaddy_domain=`expr match $domain '^[a-zA-Z0-9\-]*\.\(.*\)$'`
                    godaddy_host=`expr match $domain '^\([a-zA-Z0-9\-]*\)\..*'`
                    break;;
                [Nn]*)
                    godaddy_domain=$domain
                    godaddy_host="@"
                    break;;
                *) echo "Please answer [Y]es or [N]o."
            esac
        done
    fi

    while [ -z $godaddy_key ] || [[ $godaddy_key = "null" ]]
    do
        read -p "Please enter Godaddy API Key: " godaddy_key
        if [ ! -z $godaddy_key ] && [[ $godaddy_key != "null" ]]
        then
            break
        fi
    done

    while [ -z $godaddy_secret ] || [[ $godaddy_secret = "null" ]]
    do
        read -p "Please enter Godaddy API Secret: " godaddy_secret
        if [ ! -z $godaddy_secret ] && [[ $godaddy_secret != "null" ]]
        then
            break
        fi
    done
fi


# BEGIN INSTALLATION PROCESS

# Update/Upgrade
if [ $update = true ]
then
    echo "Connecting to github"
    update=true
    sudo git config --global credential.helper store
    sudo git pull
    echo "Updating system"
    sudo apt update
    echo "Upgrading system"
    sudo apt upgrade
    echo "Installing required programs: nodejs npm certbot curl"
    sudo apt install nodejs npm certbot curl
    sudo npm install
    # Remove old crontab commands if exists
    sudo crontab -u $USER -l | grep -v "$bash/update.sh" | crontab -u $USER -
    # Add new crontab commands
    (sudo crontab -u $USER -l ; echo "0 0 * * * $bash/update.sh --root $root >> $root/$name.update.log 2>&1") | crontab -u $USER -
fi

ssl_key="/etc/letsencrypt/live/$domain/privkey.pem"
ssl_cert="/etc/letsencrypt/live/$domain/cert.pem"

# Register Let'sEncrypt SSL Certificate
if [ $ssl = true ]
then
    echo "Registering LetsEncrypt SSL Certificate"
    ssl=true
    # Stop peer service so that certbot can start on port 80
    [[ -f /etc/systemd/system/$name.service ]] && sudo systemctl stop $name > /dev/null
    sudo certbot certonly --standalone --preferred-challenges http -d $domain

    # Check if SSL certificate exists
    if [ ! -f $ssl_key ] && [ ! -f $ssl_cert ]
    then
        echo "LetsEncrypt SSL Certificate files not found!"
    else
        echo "LetsEncrypt SSL Certificate files found!"
    fi
fi

# Install DDNS Crontab
# Automatically map domain to public IP address
if [ $godaddy_cron = true ] && [ ! -z $godaddy_domain ] && [ ! -z $godaddy_host ] && [ ! -z $godaddy_key ] && [ ! -z $godaddy_secret ]
then
    echo "Installing Crontab commands"
    godaddy_cron=true
    # Remove old crontab commands if exists
    sudo crontab -u $USER -l | grep -v "$bash/ddns.sh" | crontab -u $USER -
    # Add new crontab commands
    (sudo crontab -u $USER -l ; echo "*/5 * * * * $bash/ddns.sh --root $root --domain $godaddy_domain --host $godaddy_host --key $godaddy_key --secret $godaddy_secret >> $root/$name.ddns.log 2>&1") | crontab -u $USER -
fi

# Create config file if no file exists
if [ ! -f "$root/$config" ] && [ ! -z $domain ] && [ ! -z $port ]
then
    [ ! -z $sync ] && sync_json="\"sync\": \"$sync\"," || sync_json=""
    [ -f $ssl_key ] && [ -f $ssl_cert ] && ssl_json=",\"ssl\": { \"key\": \"$ssl_key\", \"cert\": \"$ssl_cert\" }" || ssl_json=""
    [ ! -z $godaddy_domain ] && [ ! -z $godaddy_host ] && [ ! -z $godaddy_key ] && [ ! -z $godaddy_secret ] && godaddy_json=",\"godaddy\": { \"domain\": \"$godaddy_domain\", \"host\": \"$godaddy_host\", \"key\": \"$godaddy_key\", \"secret\": \"$godaddy_secret\" }" || godaddy_json=""
    
    # Create JSON text for peers
    peers_json=""
    peers_length=${#peers[@]}
    if [ $peers_length -gt 0 ]
    then
        peers_json=",\"peers\": ["
            for (( i=0; i<peers_length; i++ )) do
                peers_json+="\"${peers[$i]}\""
                if [ $i -lt $((test_length - 1)) ]
                then
                    peers_json+=", "
                fi
            done
        peers_json+="]"
    fi
    
    # Định nghĩa nội dung JSON trong biến json_content
    json_content="{
        \"root\": \"$root\",
        \"bash\": \"$bash\",
        \"env\": \"$env\",
        \"name\": \"$name\",
        $sync_json
        \"$env\": {
            \"domain\": \"$domain\",
            \"port\": $port
            $ssl_json
            $godaddy_json
            $peers_json
        }
    }"

    # Beautify JSON content using jq
    beautified_json=$(echo -e "$json_content" | jq '.')

    # Ghi nội dung JSON vào tệp
    echo "$beautified_json" > $root/$config

fi

# Create Air service
echo "Installing $name service"
echo "[Unit]
Description=Super Peer Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$root
StandardOutput=file:$root/$name.log
StandardError=file:$root/$name.error.log
ExecStart=sudo ROOT=$root BASH=$bash ENV=$env NAME=$name DOMAIN=$domain PORT=$port SSL_KEY=$ssl_key SSL_CERT=$ssl_cert npm start
Restart=on-failure

[Install]
WantedBy=multi-user.target" > $bash/$name.service

sudo cp $bash/$name.service /etc/systemd/system/$name.service
sudo rm $bash/$name.service

# Start and enable service
sudo systemctl daemon-reload
sudo systemctl start $name
sudo systemctl enable $name

# FINISH INSTALLATION
echo "
====================================
  PEER INSTALLED AND RUNNING
  User:            $who
  Peer name:       $name
  Root path:       $root
  Bash path:       $bash
  Domain:          $domain
  Port:            $port
  SSL:             $ssl
  Godaddy cron:    $godaddy_cron
====================================
"