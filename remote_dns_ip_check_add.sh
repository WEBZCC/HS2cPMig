#/bin/sh
for remote_ip in `cat /root/remote_dns_ips.txt`
  do 
    res=$(grep $remote_ip /etc/ips.remotedns)
    if [[ -z $res ]]; then
      echo $remote_ip >> /etc/ips.remotedns
    fi  
done