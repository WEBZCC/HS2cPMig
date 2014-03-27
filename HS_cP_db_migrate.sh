db_migration(){
  hsp=~cpanel/shiva/psoft_config/hsphere.properties
  hsphere_db_user=`grep ^DB_USER $hsp|awk '{print $3}'`
  psql_password=`grep ^DB_PASSWORD $hsp|awk '{print $3}'`
  hsphere_db=hsphere
  account_id="$a"
  cpanel_user="$u" 
  cpanel_server="$t"
  # Check account id exists
   account_id_check=`cat << EOF | psql -q -U $hsphere_db_user $hsphere_db 
    \pset t
    select id from accounts where id=$account_id`
  if [[ -z "$account_id_check" ]]; then
    echo "Account ID $account_id is not found, please check"
    exit 0;
  fi
  # Get parent_id for the account
    PARENT_ID=`cat << EOF | psql -q -U $hsphere_db_user $hsphere_db 
    \pset t
    select DISTINCT  parent_id  from parent_child where account_id = $account_id and child_type=6001`
  if [[ -z "$PARENT_ID" ]]; then
    echo "There are no Databases for the AccountID $account_id, please check it"
    exit 0;
  fi
  # Find the databases in the account
    echo `cat << EOF | psql -q -U $hsphere_db_user $hsphere_db 
    \pset t
    select db_name from mysqldb where parent_id=$PARENT_ID` > dbs_$account_id 
  # Find the database users of the account
    echo `cat << EOF | psql -q -U $hsphere_db_user $hsphere_db
    \pset t
    select login from mysql_users where parent_id = $PARENT_ID` > mysqlusers
    echo `cat << EOF | psql -q -U $hsphere_db_user $hsphere_db
    \pset t
    select password from mysql_users where parent_id = $PARENT_ID` > mysqlpass
  # Find the ip address of the mysql server to find mysql user for a db
    IP=`cat << EOF | psql -q -U $hsphere_db_user $hsphere_db
          \pset t
    select ip1 from p_server where id = (select p_server_id from l_server where id = (select mysql_host_id from mysqlres where id = $PARENT_ID))`
  echo>mysqlusers1>mypass1>login>total>mapping

  rpasswd=$(ssh -l  root $IP cat ~mysql/.my.cnf | grep pass |cut -d'=' -f2)
  for i in `cat mysqlusers`
  do 
  echo $i >> mysqlusers1 
  done
  for j in `cat mysqlpass`
  do
  echo $j >> mypass1
  done
  mysql_server=$(ssh root@$cpanel_server grep host /root/.my.cnf | cut -d'"' -f2)
  mysql_pwd=$(ssh root@$cpanel_server grep password /root/.my.cnf | cut -d'"' -f2)
  if [[ -z $mysql_server ]]; then
      mysql_server=$cpanel_server
  fi   
  paste mysqlusers1 mypass1 -d ' ' > login
  for i in `cat dbs_$account_id`
  do
    users=$(ssh -l root $IP /hsphere/shared/scripts/mysql-db-users $i)
    for j in `echo $users`
    do
      mysqlcheck --auto-repair  -s -h $IP -u root -p`echo $rpasswd` $i
      mysqldump --routines -h $IP -u root -p`echo $rpasswd` $i > /tmp/$i.sql
      pass=$(grep $j login | cut -d' ' -f2)
      t=$(echo $j | cut -d'_' -f2 ) # Removing the prefix
      j=$(echo ${t:0:8}) # Limit dbuser to 7 characters
      dbusert=$(echo -e $cpanel_user"_"$j) # Adding cpanel prefix to dbuser
      dbuser=$(echo ${dbusert:0:16}) # Limit dbuser to 16 characters
      t=$(echo $i | cut -d'_' -f2 )
      dbname=$(echo -e $cpanel_user"_"$t)
      mysql -h $mysql_server  -u root -p`echo $mysql_pwd` -e "create database $dbname"
      mysql -h $mysql_server  -u root -p`echo $mysql_pwd` -e "create user $dbuser"
      mysql -h $mysql_server -u root -p`echo $mysql_pwd` -e "grant all privileges on $dbname.* to $dbuser@'%' identified by '$pass'"
      echo -e "/usr/local/cpanel/bin/dbmaptool $cpanel_user --type mysql --dbusers '$dbuser' --dbs '$dbname' " >>mapping
      mysql -h $mysql_server -u root -p`echo $mysql_pwd` $dbname <  /tmp/$i.sql
      rm -rf /tmp/$i.sql
    done
  done
  scp mapping root@$cpanel_server:/root/
  ssh root@$cpanel_server chmod +x  /root/mapping
  ssh root@$cpanel_server /root/mapping
}

# Force user to enter input in proper fromat
proper_usage() {
 echo -e "Execute the commands as ./HS_cP_db_migrate.sh -a hsphere Account Number -u cPanel user -t Target cPanel MySQL server IP \n ./HS_cP_db_migrate.sh -a 123456 -u bobcpanel -t 1.2.3.4" 
 exit 1; 
}

# Getting the user input
account=false
user=false
target=false
while getopts ":a:u:t:" options; do
  case "${options}" in
      a)
          a=${OPTARG}
          account=true;
          ;;
      u)
          u=${OPTARG}
          user=true;
          ;;
      t)
         t=${OPTARG}
         target=true;
         db_migration $a $u $t
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
elif ! $account; then
  echo "Please provide H-Sphee Account Number"
  proper_usage;
elif ! $user; then
  echo "Please provide cPanel User"
  proper_usage;
elif ! $target; then
  echo "Please provide cPanel MySQL server IP Address"
  proper_usage;    
fi
shift $((OPTIND-1))