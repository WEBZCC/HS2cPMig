web_migration(){
  hsp=~cpanel/shiva/psoft_config/hsphere.properties
  hsphere_db_user=`grep ^DB_USER $hsp|awk '{print $3}'`
  psql_password=`grep ^DB_PASSWORD $hsp|awk '{print $3}'`
  hsphere_db=hsphere
  account_id="$a"
  target_username="$u"
  main_domain="$m"
  target="$t"

  # Check if Account ID Exists
  account_id_check=`cat << EOF | psql -q -U $hsphere_db_user $hsphere_db
	    \pset t 
      select id from accounts where id=$account_id`
	if [[ -z "$account_id_check" ]]; then
	   echo "Account ID $account_id is not found, please check"
	   exit 0;
	fi

 # Find the Domain Names in the Account
	echo `cat << EOF | psql -q -U $hsphere_db_user $hsphere_db
	    \pset t
	    select domains.name from domains, parent_child where domains.id = parent_child.child_id and 
      parent_child.account_id = $account_id` >> domains_list_$account_id

  # Find the Source Server IP
	lserver_id=$(echo `cat << EOF | psql -q -U $hsphere_db_user $hsphere_db
	    \pset t
	     select DISTINCT hostid from unix_user, parent_child where 
       parent_child.account_id = $account_id and child_id = unix_user.id`)
	server_ip=$(echo `cat << EOF | psql -q -U $hsphere_db_user $hsphere_db
	    \pset t
	     select ip1 from p_server where id = (select p_server_id from l_server where id = $lserver_id)`)

  # Arrange the domains in a file
  	for i in `cat domains_list_$account_id`
	  do
		  echo $i >> domainlist_$account_id
	  done
  
  # Remove the main domain from the list
	sed /`echo $main_domain`/d domainlist_$account_id -i
  count=$(cat domainlist_$account_id  | wc -l)

  # Add the main domain to for rsync in the script
  echo  "ssh -l root $server_ip chmod 755  /home/$target_username/www/" > web_migrate_remote.sh
  home_dir=$(echo `cat << EOF | psql -q -U $hsphere_db_user $hsphere_db
            \pset t
		   select dir from unix_user,parent_child where unix_user.id = parent_child.child_id and parent_child.account_id = $account_id  and login=group_name`)
 echo $home_dir  
 echo  "rsync -avze ssh $home_dir/$main_domain/ root@$target:/home/$target_username/www/" >> web_migrate_remote.sh
  # Add the remaining domains for rsync in the script
  if [[ "$count" -gt 1 ]]; then
	   for i in `cat domainlist_$account_id`
	   do
	    	echo  " rsync -avze ssh $home_dir/$i/ root@$target:/home/$target_username/public_html/$i/" >> web_migrate_remote.sh
	   done
  fi
  scp web_migrate_remote.sh root@$target:/root/
  ssh -l root $server_ip chmod 755 /root/web_migrate_remote.sh
  ssh -l root $server_ip sh /root/web_migrate_remote.sh
  ssh -l root $target chown $target_username.$target_username /home/$target_username/public_html/ -R
}

# Force user to enter input in proper fromat
proper_usage() {
	 echo -e "Execute the commands as ./HS_cP_web_migrate.sh -a hsphere Account Number -u Cpanel user name -m Cpanel main domain -t Target cPanel Web server IP \n ./HS_cP_web_migrate.sh -a 123456 -u cpanelftpuser -m domain.com -t 1.2.3.4"
	 exit 1;
}

# Validate user input
user_input_check(){
  if ! $main_domain_check; then
    echo "Please provide domain name"
    proper_usage;
  elif ! $target_user_check; then
    echo "Please provide cPanel User"
    proper_usage;
  elif ! $target_check; then
    echo "Please provide cPanel web server IP Address"
    proper_usage;    
  elif ! $account_check; then
    echo "Pleae provide Acount number"
    proper_usage;
  fi
}

# Getting the user input
account_check=false
main_domain_check=false
target_check=false
target_user_check=false

while getopts ":a:u:m:t:" options; do
  case "${options}" in
      a)
          a=${OPTARG}
          account_check=true;
          ;;
      u)
	        u=${OPTARG}
	        target_user_check=true;
          ;; 
      m)
         m=${OPTARG}
         main_domain_check=true;
          ;;
      t)
         t=${OPTARG}
         target_check=true;
         user_input_check $account_check $target_user_check $main_domain_check $target_check
         web_migration $a $u $m $t
      	 exit 0
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