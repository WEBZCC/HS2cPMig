mail_migration(){
  # Mail server host name and it's IP
  host_name=$(host -t MX $domain_name | grep -v NX | grep 10 | grep world | cut -d' ' -f7)
  ip_addr=$(host $host_name | cut -d' ' -f4)

  # Mail domain directory and email account passwords
  domain_dir=$(ssh root@$ip_addr  `echo  /hsphere/local/var/vpopmail/bin/vdominfo -d $domain_name`)
  ssh root@$ip_addr cat $domain_dir/vpasswd > vpasswd_files/vpasswd_$domain_name
  echo > migrate.sh
  for i in `cat vpasswd_files/vpasswd_$domain_name`
  do
    mailbox_name=$(echo $i | cut -d':' -f1)
    mailbox_quota=$(echo $i | cut -d':' -f7 |cut -d'S' -f1)
    mailbox_password=$(echo $i | cut -d':' -f8)
    mailbox_quotaMB=$((mailbox_quota/1048576))
    ssh root@$target_server /scripts/addpop --email=$mailbox_name@$domain_name --password=$mailbox_password --quota=$mailbox_quotaMB
    echo -e  /usr/local/bin/python2.7 imapcp/imapcp.py $mailbox_name@$domain_name:$mailbox_password:$ip_addr:143 $mailbox_name@$domain_name:$mailbox_password:$target_server:143 >> migrate.sh
  done

  # Copy mails to traget server 
  ./migrate.sh
}

# Force User to enter proper fromat
proper_usage() {
 echo -e "Execute the commands as ./HS_cP_mail_migrate.sh -d domain name -u cPanel user -t Target cPanel Mail server IP \n ./HS_cP_mail_migrate.sh -d domin_name.com -u bobcpanel -t 1.2.3.4"
 exit 1;
}

# Check directory or Binary
check_binary(){
  if [ ! -d ./vpasswd_files ]; then
    mkdir -p vpasswd_files
  fi
}

# Validate user input
user_input_check(){
  if ! $domain_name_check; then
    echo "Please provide domain name"
    proper_usage;
  elif ! $user_check; then
    echo "Please provide cPanel User"
    proper_usage;
  elif ! $target_check; then
    echo "Please provide cPanel Mail server IP Address"
    proper_usage;
  fi
}

# Getting the user input
domain_name_check=false
target_check=false
user_check=false
while getopts ":d:u:t:ip" options; do
  case "${options}" in
    d)
        d=${OPTARG}
        domain_name_check=true;
        ;;
    u)
        u=${OPTARG}
        user_check=true;
        ;;
    t)
       t=${OPTARG}
       target_check=true;
       check_binary
       user_input_check $domain_name_check $user_check $target_check
       domain_name=$d
       target_server=$t
       user_name=$u
       mail_migration $domain_name $target_server $user_name
       ;;
    \?)
       echo "Invalid option: -$OPTARG" >&2
       proper_usage
       exit 1
       ;;
    :)
       echo "Option -$OPTARG requires an argument." >&2
       proper_usage
       exit 1
       ;;
    *)
       proper_usage
       ;;
  esac
 done
if [[ -z $1 ]]; then
  proper_usage
fi
shift $((OPTIND-1))