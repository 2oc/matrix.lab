
for HOST in `virsh list --all | grep RH6STORAGE | awk '{ print $2 }'`
do 
  virsh destroy $HOST
  virsh undefine $HOST
  rm -rf /home/images/${HOST}/
done

for HOST in 1 2 3 4
do
  ./build_RH6STORAGE0X.sh RH6STORAGE0${HOST}
  sleep 10
done

for HOST in 1 2 3 4
do
  ssh root@RH6STORAGE0${HOST} "shutdown now -r"
done
