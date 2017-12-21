#! /bin/bash
set -o nounset

ORADIR=/opt/oraadm
echo -e "\n本自动安装脚本仅适用于安装Oracle 11gR2 Single DataBase，安装前请把安装包上传至$ORADIR目录下，安装包列表如下：\n\nThis script is for installation Oracle DataBase 11gR2 Single instance, before installation, you should upload the \ninstallation medium to $ORADIR, the media list is :\n\n\n1. p13390677_112040_Linux-x86-64_1of7.zip\n2. p13390677_112040_Linux-x86-64_2of7.zip\n3. p13390677_112040_Linux-x86-64_3of7.zip   --unused\n4. p13390677_112040_Linux-x86-64_4of7.zip   --unused\n\nCreate By ZhangYi @2016-11-27\n"

read -p "...安装包上传完成后，按回车键继续...
...Upload Installation media is complete, press Enter to continue..."

ALLVersionFile=/tmp/tmpversion.txt
LOGFILE=/tmp/setup.log
UNZIPLOG=/tmp/unzip.log

echo > $LOGFILE
echo > $ALLVersionFile
chmod 777 $LOGFILE $ALLVersionFile

ORAPWD=oracle
GRIDPWD=grid

ORACLEPORT=1521

DATAPATH=/oradata
ORACLEBASE=/opt/oracle
ORACLEHOME=$ORACLEBASE/product/11gR2/db
GRIDBASE=/opt/oracrs/base
GRIDHOME=/opt/oracrs/product/11gR2/grid
RSPPATH=/tmp/respfile

export LANG=en

echo "2.6.32-642.el6.x86_64=Red Hat Enterprise Linux Server 6.8
2.6.32-573.el6.x86_64=Red Hat Enterprise Linux Server 6.7
2.6.32-504.el6.x86_64=Red Hat Enterprise Linux Server 6.6
2.6.32-431.el6.x86_64=Red Hat Enterprise Linux Server 6.5
2.6.32-358.el6.x86_64=Red Hat Enterprise Linux Server 6.4
2.6.32-279.el6.x86_64=Red Hat Enterprise Linux Server 6.3
2.6.32-220.el6.x86_64=Red Hat Enterprise Linux Server 6.2
2.6.32-131.0.15.el6.x86_64=Red Hat Enterprise Linux Server 6.1
2.6.32-71.el6.x86_64=Red Hat Enterprise Linux Server 6.0
2.6.32.59-0.7-default=SUSE Linux Enterprise Server 11 SP1
3.0.101-63-default=SUSE Linux Enterprise Server 11 SP4
3.0.76-0.11.1-default=SUSE Linux Enterprise Server 11 SP3" > $ALLVersionFile

OSKernel=`uname -r`
KernelVersion=`grep $OSKernel $ALLVersionFile|wc -l`
OSVersion=`grep $OSKernel $ALLVersionFile|awk -F\= '{print $2}'`

if [[ $KernelVersion -ne '1' ]]; then 
  echo -e "\nCurrent OS is not in this OS list...\n\e[1;34m`cat $ALLVersionFile|awk -F\= '{print $2}'`\e[0m\n\nPlease Reinstall the system or try Manual installation..." | tee -a $LOGFILE
  exit
fi
echo -e "\nCurrent OS is\v\e[1;34m$OSVersion\n\e[0m" | tee -a $LOGFILE

#########################检测oracle是否已经安装#######################################
echo -e "\nINFO:===`date`===new installing oracle 11.2.0.4.0 begin!" | tee -a $LOGFILE
echo -e "\n============begin check if oracle is installed...."

ps -ef|grep tnslsnr|grep -v grep > /dev/null

if [ $? = 0 ]; then
  echo "ERROR:===`date`===oracle already install..." | tee -a  $LOGFILE
  exit 1
fi
echo -e "\n============end check if oracle is not-installed...." | tee -a $LOGFILE

#########################检测oracle安装所需动态库是否已经安装#########################
echo -e "\nINFO:===`date`===Check Lib......\n" | tee -a $LOGFILE

if [[ $OSVersion =~ "Hat Enterprise Linux Server 6" ]]; then 
for rpmpkg in binutils compat-libcap1 compat-libstdc++-33 gcc gcc-c++ glibc glibc-devel ksh libaio libaio-devel libgcc libstdc++ libstdc++-devel make sysstat; do rpm -q $rpmpkg > /dev/null
  if [ $? != 0 ]; then
    echo "ERROR:==`date`===$rpmpkg is not installed..." | tee -a $LOGFILE
  fi
    echo "INFO:===`date`===$rpmpkg was installed..." | tee -a $LOGFILE
    done
fi

if [[ $OSVersion =~ "SUSE Linux Enterprise Server 11 SP" ]]; then 
for rpmpkg in binutils gcc gcc-c++ glibc glibc-devel ksh libaio libaio-devel libgcc43 libstdc++-devel libstdc++33 libstdc++43 libstdc++43-devel make sysstat; do rpm -q $rpmpkg > /dev/null
  if [ $? != 0 ]; then
    echo "ERROR:==`date`===$rpmpkg is not installed..."| tee -a $LOGFILE
  fi
    echo "INFO:===`date`===$rpmpkg was installed..." | tee -a $LOGFILE
    done
fi

Not_ins_count=`grep "not installed" $LOGFILE|wc -l`
Not_installed=`grep "not installed" $LOGFILE`

if [[ $Not_ins_count -gt '0' ]]; then 
  echo -e "\n\n\e[1;31m$Not_installed\e[0m\n\n\033[34;31;5mPlease install the rpm-package...\033[39;49;0m\n"
  exit 2
fi

echo -e "\v\e[1;34mAll package was installed\n\e[0m" 

#########################检测oracle安装所需操作系统内核参数是否正确###################
#检测内存
echo -e "\nINFO:===`date`===Check MEM......" | tee -a $LOGFILE
MEMSIZE=`grep MemTotal /proc/meminfo|awk '{print $2}'`
if [ $MEMSIZE -lt 1000000 ]; then
  echo "ERROR:===`date`===sytem memory is less 1G..." | tee -a $LOGFILE
  exit 3
fi
echo "============sytem memory is $MEMSIZE...." | tee -a $LOGFILE

###############################检测交换分区大小#######################################
echo -e "\nINFO:===`date`===Check swap partition......" | tee -a $LOGFILE
SWAPSIZE=`grep SwapTotal /proc/meminfo|awk '{print $2}'`
if [ $SWAPSIZE -lt 2000000 ]; then
  echo "ERROR:===`date`===sytem swap partition is less 2G..." | tee -a $LOGFILE
  exit 4
fi
echo "============sytem swap partition is $SWAPSIZE...." | tee -a $LOGFILE

################################查看共享内存大小######################################
echo -e "\nINFO:===`date`===Check shm......" | tee -a $LOGFILE
SHMSIZE=`df -k /dev/shm/|grep -v Filesystem|awk '{print $2}'`
if [ $SHMSIZE -lt 512000 ]; then
  echo "ERROR:===`date`===sytem shm is less 512000..." | tee -a $LOGFILE
  exit 5
fi
echo "============sytem shm is $SHMSIZE...." | tee -a $LOGFILE

#################################/tmp目录空间大小#####################################
echo -e "\nINFO:===`date`===Check /tmp......" | tee -a $LOGFILE
TMPSIZE=`df -k /tmp|grep -v Filesystem|awk '{print $2}'`
if [ $TMPSIZE -lt 400000 ]; then
  echo "ERROR:===`date`===sytem /tmp is less 400M..." | tee -a $LOGFILE
  exit 6
fi
echo "============/tmp is $TMPSIZE...." | tee -a $LOGFILE

#################################安装目录磁盘空间######################################
echo -e "\nINFO:===`date`===Check INSTALLSIZE......" | tee -a $LOGFILE
INSTALLSIZE=`df -kP /opt|grep -v Filesystem|awk '{print $2}'`
if [ $? = 0 ] && [ $INSTALLSIZE -lt 4500000 ]; then
  echo "ERROR:===`date`===partition /opt is less 4.5G..." | tee -a $LOGFILE
  exit 7
fi
echo "============partition /opt is $INSTALLSIZE...." | tee -a $LOGFILE

#################################设定SID######################################
read -t 60 -p "Please Select a Oracle instance name (Instance name length is less than 8) [Default is zhangyi514]: " SID
[ -z $SID ]&& SID=zhangyi514
OracleSID=$SID
ASMSID=+ASM
echo $OracleSID 

#################################重建用户######################################
echo -e "\nINFO:===`date`===Create UserGroups and Users......" | tee -a $LOGFILE
/usr/bin/pgrep -u oracle | xargs kill -9 > /dev/null
/usr/bin/pgrep -u grid | xargs kill -9 > /dev/null
userdel -r oracle
userdel -r grid
rm -rf /etc/ora*
rm -rf /opt/oraInventory
rm -rf /home/oracle
groupdel oinstall
groupdel dba
groupadd -g 120 oinstall
groupadd -g 121 dba
useradd -u 120 -s /bin/bash -g oinstall -G dba -md /home/grid grid
useradd -u 121 -s /bin/bash -g oinstall -G dba -md /home/oracle oracle

#######################################重置密码######################################
echo -e "\nINFO:===`date`===Create password of Users......\n" | tee -a $LOGFILE
echo oracle:$ORAPWD |chpasswd
echo grid:$GRIDPWD |chpasswd
echo "password of user oracle is ----$ORAPWD----" | tee -a $LOGFILE
echo "password of user grid is ----$GRIDPWD----" | tee -a $LOGFILE

###################################选择数据文件存储方式###############################
read -t 60 -p "
Please Select datafiletype,  press Enter is used LocalDisk. 
[Example: fs (filesystem)|raw (PV/VG/LV)]: " datafiletype
[ -z $datafiletype ] && datafiletype=Null
DATATYPE=$datafiletype
Disk=Null

############################外部存储文件系统方式################################
if [[ "$DATATYPE"x == "fs"x ]]; then 
read -t 60 -p "Please Select a Disk name [Default is not use External Disk. Example: /dev/sdb]: " PV
[ -z $PV ] && PV=Null
Disk=$PV

if [[ "$Disk"x != "Null"x ]]; then
listfile=/tmp/pvlist.txt
pvlist=`fdisk -l |grep "Disk $Disk:" > $listfile`
pvsize=`grep "Disk $Disk:" $listfile|awk '{print $3}'|awk -F\. '{print $1}'`
disksize=`expr \( $pvsize \) \* 93 \/ 100`
lvsize=`echo $disksize"G"`
echo "Disk $Disk space available is $lvsize ..."
pvcreate $Disk | tee -a $LOGFILE

read -t 60 -p "
Will be create VG, Please Select a VG name [Default: datavg]: " VG
[ -z $VG ] && VG=datavg
vgname=$VG
echo $vgname
vgcreate $vgname $Disk | tee -a $LOGFILE

read -t 60 -p "
Will be create LV, Please Select a LV name [Default: lv_ora]: " LV
[ -z $LV ] && LV=lv_ora
Lvname=$LV
lvcreate -L $lvsize -n $Lvname $vgname

read -t 60 -p "
Will be make FileSystem, Please Select a FileSystem Type [Default: mkfs.ext4. Example: mkfs.ext3 | mkfs.ext4 | mkfs.reiserfs]: " MKFS
[ -z $MKFS ] && MKFS=mkfs.ext4
FSTYPE=$MKFS
$FSTYPE -q /dev/$vgname/$Lvname
sleep 3
mkdir -p $DATAPATH
mount /dev/$vgname/$Lvname $DATAPATH
##################################检查挂载情况和空间#################################
echo -e "\nINFO:===`date`===Check $DATAPATH......" | tee -a $LOGFILE
DATAFILESIZE=`df -kP $DATAPATH|grep -v Filesystem|awk '{print $2}'`
if [ $? = 0 ] && [ $DATAFILESIZE -lt 10000000 ]; then
  echo "ERROR:===`date`===partition $DATAPATH is less 10G..." | tee -a $LOGFILE
  exit 7
fi
echo "============partition $DATAPATH is $DATAFILESIZE...." | tee -a $LOGFILE
fi
fi

#################################裸设备方式################################
if [[ "$DATATYPE"x == "raw"x ]]; then 
read -t 60 -p "
Please Select a Disk name [Default is not use External Disk. Example: /dev/sdb]: " PV
[ -z $PV ] && PV=Null
Disk=$PV

if [[ "$Disk"x != "Null"x ]]; then
listfile=/tmp/pvlist.txt
pvlist=`fdisk -l |grep "Disk $Disk:" > $listfile`
pvsize=`grep "Disk $Disk:" $listfile|awk '{print $3}'|awk -F\. '{print $1}'`
disksize=`expr \( $pvsize \) \* 93 \/ 100`
lvsize=`echo $disksize"G"`
echo "Disk $Disk space available is $lvsize ..."
pvcreate $Disk | tee -a $LOGFILE

read -t 60 -p "
Will be create ----VG----, Please Select a VG name [Default: datavg]: " VG
[ -z $VG ] && VG=datavg
vgname=$VG
echo $vgname
vgcreate $vgname $Disk | tee -a $LOGFILE

read -t 60 -p "
Create ----lv_system---- , Please Select a size [Default: 4G ; Example: 4G | 8000M]: " systemlv
[ -z $systemlv ] && systemlv=4G
systemsize=$systemlv
lvcreate -L $systemsize -n lv_system $vgname

read -t 60 -p "
Create ----lv_sysaux----, Please Select a size [Default: 4G ; Example: 4G | 8000M]: " sysauxlv
[ -z $sysauxlv ] && sysauxlv=4G
sysauxsize=$sysauxlv
lvcreate -L $sysauxsize -n lv_sysaux $vgname

read -t 60 -p "
Create ----lv_users---- , Please Select a size [Default: 2G ; Example: 4G | 8000M]: " userslv
[ -z $userslv ] && userslv=2G
userssize=$userslv
lvcreate -L $userssize -n lv_users $vgname

read -t 60 -p "
Create ----lv_temp---- , Please Select a size [Default: 4G ; Example: 4G | 8000M]: " templv
[ -z $templv ] && templv=4G
tempsize=$templv
lvcreate -L $tempsize -n lv_temp $vgname

read -t 60 -p "
Create ----lv_undotbs----, Please Select a size [Default: 4G ; Example: 4G | 8000M]: " undotbslv
[ -z $undotbslv ] && undotbslv=4G
undotbssize=$undotbslv
lvcreate -L $undotbssize -n lv_undotbs $vgname

read -t 60 -p "
Create ----lv_redo---- , Please Select a size [Default: 1G ; Example: 4G | 8000M]: " redolv
[ -z $redolv ] && redolv=1G
redosize=$redolv
lvcreate -L $redosize -n lv_redo1 $vgname
lvcreate -L $redosize -n lv_redo2 $vgname
lvcreate -L $redosize -n lv_redo3 $vgname
lvcreate -L $redosize -n lv_redo4 $vgname
lvcreate -L $redosize -n lv_redo5 $vgname
lvcreate -L $redosize -n lv_redo6 $vgname

read -t 60 -p "
Create ----lv_ctrl---- , Please Select a size [Default: 256M ; Example: 4G | 8000M]: " ctrllv
[ -z $ctrllv ] && ctrllv=256M
ctrlsize=$ctrllv
lvcreate -L $ctrlsize -n lv_ctrl1 $vgname
lvcreate -L $ctrlsize -n lv_ctrl2 $vgname
lvcreate -L $ctrlsize -n lv_ctrl3 $vgname

read -t 60 -p "
Create ----lv_spfile---- , Please Select a size [Default: 128M ; Example: 4G | 8000M]: " spfilelv
[ -z $spfilelv ] && spfilelv=128M
spfilesize=$spfilelv
lvcreate -L $spfilesize -n lv_spfile $vgname

echo "LV created OK"
echo "raw"

raw /dev/raw/raw1 0 0
raw /dev/raw/raw2 0 0
raw /dev/raw/raw3 0 0
raw /dev/raw/raw4 0 0
raw /dev/raw/raw5 0 0
raw /dev/raw/raw6 0 0
raw /dev/raw/raw7 0 0
raw /dev/raw/raw8 0 0
raw /dev/raw/raw9 0 0
raw /dev/raw/raw10 0 0
raw /dev/raw/raw11 0 0
raw /dev/raw/raw12 0 0
raw /dev/raw/raw13 0 0
raw /dev/raw/raw14 0 0
raw /dev/raw/raw15 0 0

rm -rf /dev/raw/raw?

mknod /dev/raw/raw1 c 162 1
mknod /dev/raw/raw2 c 162 2
mknod /dev/raw/raw3 c 162 3
mknod /dev/raw/raw4 c 162 4
mknod /dev/raw/raw5 c 162 5
mknod /dev/raw/raw6 c 162 6
mknod /dev/raw/raw7 c 162 7
mknod /dev/raw/raw8 c 162 8
mknod /dev/raw/raw9 c 162 9
mknod /dev/raw/raw10 c 162 10
mknod /dev/raw/raw11 c 162 11
mknod /dev/raw/raw12 c 162 12
mknod /dev/raw/raw13 c 162 13
mknod /dev/raw/raw14 c 162 14
mknod /dev/raw/raw15 c 162 15

raw /dev/raw/raw1 /dev/$vgname/lv_system
raw /dev/raw/raw2 /dev/$vgname/lv_sysaux
raw /dev/raw/raw3 /dev/$vgname/lv_users
raw /dev/raw/raw4 /dev/$vgname/lv_temp
raw /dev/raw/raw5 /dev/$vgname/lv_undotbs
raw /dev/raw/raw6 /dev/$vgname/lv_redo1
raw /dev/raw/raw7 /dev/$vgname/lv_redo2
raw /dev/raw/raw8 /dev/$vgname/lv_redo3
raw /dev/raw/raw9 /dev/$vgname/lv_redo4
raw /dev/raw/raw10 /dev/$vgname/lv_redo5
raw /dev/raw/raw11 /dev/$vgname/lv_redo6
raw /dev/raw/raw12 /dev/$vgname/lv_ctrl1
raw /dev/raw/raw13 /dev/$vgname/lv_ctrl2
raw /dev/raw/raw14 /dev/$vgname/lv_ctrl3
raw /dev/raw/raw15 /dev/$vgname/lv_spfile

sleep 1

chown -R oracle:oinstall /dev/raw/raw* 
chown -R root:disk /dev/raw/rawctl 

raw -qa > /tmp/raw.txt
sed -i 's/\t/ /g' /tmp/raw.txt
echo '/dev/raw/raw1: bound to major 253, minor 0
/dev/raw/raw2: bound to major 253, minor 1
/dev/raw/raw3: bound to major 253, minor 2
/dev/raw/raw4: bound to major 253, minor 3
/dev/raw/raw5: bound to major 253, minor 4
/dev/raw/raw6: bound to major 253, minor 5
/dev/raw/raw7: bound to major 253, minor 6
/dev/raw/raw8: bound to major 253, minor 7
/dev/raw/raw9: bound to major 253, minor 8
/dev/raw/raw10: bound to major 253, minor 9
/dev/raw/raw11: bound to major 253, minor 10
/dev/raw/raw12: bound to major 253, minor 11
/dev/raw/raw13: bound to major 253, minor 12
/dev/raw/raw14: bound to major 253, minor 13
/dev/raw/raw15: bound to major 253, minor 14' > /tmp/raw1.txt

DIFFFILE=/tmp/diff.txt
DIFFTWO=`diff /tmp/raw.txt /tmp/raw1.txt > $DIFFFILE`
DIFFCOUNT=`wc -l $DIFFFILE`
if [[ "$DIFFCOUNT"x != "0 $DIFFFILE"x ]]; then 
exit 0
fi
echo "raw is OK"
rm -rf $DIFFFILE $DIFFTWO $DIFFCOUNT
fi
fi

#################################本地磁盘方式################################
if [[ "$DATATYPE"x == "Null"x ]]; then
echo -e "\nINFO:===`date`===Check $DATAPATH......" | tee -a $LOGFILE
DATAFILESIZE=`df -kP $DATAPATH|grep -v Filesystem|awk '{print $2}'`
if [ $? == 0 ] && [ $DATAFILESIZE -lt 10000000 ]; then
  echo "ERROR:===`date`===partition $DATAPATH is less 10G..." | tee -a $LOGFILE
  exit 7
fi
echo "============partition $DATAPATH is $DATAFILESIZE...." | tee -a $LOGFILE
fi

#######################################重建目录######################################
echo -e "\nINFO:===`date`===Create Directorys for Oracle......" | tee -a $LOGFILE
rm -rf /etc/ora*
rm -rf /opt/oraInventory
rm -rf /opt/oracle
rm -rf /opt/oracrs
mkdir -p /opt/oraInventory
chown -R oracle:oinstall /opt/oraInventory
chmod -R 775 /opt/oraInventory
mkdir -p $ORACLEBASE
chown -R oracle:oinstall $ORACLEBASE
chmod -R 775 $ORACLEBASE
mkdir -p $GRIDBASE
chown -R grid:oinstall /opt/oracrs
chmod -R 775 /opt/oracrs
mkdir -p $RSPPATH $ORADIR
chown -R oracle:dba $ORADIR $RSPPATH
chmod -R 770 $ORADIR $RSPPATH
chown -R oracle:oinstall $DATAPATH
chmod -R 770 $DATAPATH

####################配置系统参数及用户限制######################################
echo -e "\nINFO:===`date`===Change limits for Oracle Users......\n" | tee -a $LOGFILE
MEM=`grep MemTotal /proc/meminfo|awk '{print $2}'`
StandardMEM=`expr \( $MEM \) \/ 1024 \/ 1024 + 1`
shmmax=`expr \( $MEM \) \* 512`
shmall=`expr \( $StandardMEM \) \* 1024 \* 256`
#echo $shmmax $shmall

#MEM=`free -m|grep Mem|awk '{print $2}'`
#shmmax=`expr \( $MEM \) \* 1024 \* 1024 - 1`
#shmall=`expr \( $MEM \) \* 256 - 1`
#echo $shmmax $shmall

for name in file-max aio-max-nr shmmax shmall shmmni kernel.sem msgmax msgmnb msgmni ip_local_port_range rmem_default rmem_max wmem_default wmem_max; do sed -i "/$name/"d /etc/sysctl.conf;done
echo "
fs.file-max = 6815744
fs.aio-max-nr = 1048576
kernel.shmmax = $shmmax
kernel.shmall = $shmall
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
kernel.msgmax = 1048576
kernel.msgmnb = 4194304
kernel.msgmni = 256
net.ipv4.ip_local_port_range = 9000 65000
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576 " >> /etc/sysctl.conf

echo "
oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536
grid soft nproc 2047
grid hard nproc 16384
grid soft nofile 1024
grid hard nofile 65536" >> /etc/security/limits.conf

##########################使启动时自动读取内核参数################################
/sbin/chkconfig boot.sysctl on
#使当前内核参数生效
/sbin/sysctl -p >> $LOGFILE

#################################配置用户变量######################################
echo -e "\nINFO:===`date`===Configure Environment for Oracle Users......" | tee -a $LOGFILE

echo "export ORACLE_SID=$OracleSID
# Oracle Environment
export ORACLE_BASE=$ORACLEBASE
export ORACLE_HOME=$ORACLEHOME
export GRID_HOME=$GRIDHOME" > /home/oracle/.profile

echo '
export ORACLE_TERM=xterm
LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:$ORACLE_HOME/rdbms/lib
export LD_LIBRARY_PATH
SHLIB_PATH=$ORACLE_HOME/lib:$ORACLE_HOME/rdbms/lib
export SHLIB_PATH
# Set shell search paths:
export PATH=$ORACLE_HOME/bin:/usr/sbin:$PATH:/usr/local/bin
# CLASSPATH must include the following JRE locations:
CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export CLASSPATH=$CLASSPATH:$ORACLE_HOME/network/jlib
export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK' >> /home/oracle/.profile

echo 'source $HOME/.profile' >> /home/oracle/.bashrc

echo "export ORACLE_BASE=$GRIDBASE
export ORACLE_HOME=$GRIDHOME
export ORACLE_SID=$ASMSID" > /home/grid/.profile

echo 'source $HOME/.profile' >> /home/grid/.bashrc

echo '
# Grid Environment
export ORACLE_TERM=xterm
LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib:$ORACLE_HOME/rdbms/lib
export LD_LIBRARY_PATH
SHLIB_PATH=$ORACLE_HOME/lib:$ORACLE_HOME/rdbms/lib
export SHLIB_PATH
# Set shell search paths:
export PATH=$ORACLE_HOME/bin:/usr/sbin:$PATH:/usr/local/bin
# CLASSPATH must include the following JRE locations:
CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib
export CLASSPATH=$CLASSPATH:$ORACLE_HOME/network/jlib
export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK' >> /home/grid/.profile

####################去掉root用户下默认的ORACLE变量######################################
echo '
unset ORA_CRS_HOME
unset ORA_ASM_HOME
unset ORACLE_SID
unset ORACLE_BASE
unset ORACLE_HOME
export PATH=$PATH:/opt/VRTSvcs/bin/:/opt/VRTS/bin' >> /etc/profile

####################如果安装ASM，添加diskgroup，以下为样例###################
echo -e "\nINFO:===`date`===Create Sample Diskgroup for Oracle......" | tee -a $LOGFILE
echo "
#mkdir -p /dev/diskgroup
#chmod 770 /dev/diskgroup
#chown grid:oinstall /dev/diskgroup

#ln -f -s /dev/disk/by-id/scsi-36000c29cd857fcc387ad682423df00b1 /dev/diskgroup/dg_ocr
#ln -f -s /dev/disk/by-id/scsi-36000c29cd857fcc387ad682423df00b2 /dev/diskgroup/dg_data1
#ln -f -s /dev/disk/by-id/scsi-36000c29cd857fcc387ad682423df00b3 /dev/diskgroup/dg_data2
#ln -f -s /dev/disk/by-id/scsi-36000c29cd857fcc387ad682423df00b4 /dev/diskgroup/dg_fra

#ln -f -s /dev/sdb /dev/diskgroup/dg_ocr
#ln -f -s /dev/sdc /dev/diskgroup/dg_data1
#ln -f -s /dev/sdd /dev/diskgroup/dg_data2
#ln -f -s /dev/sde /dev/diskgroup/dg_fra

#chmod 660 /dev/diskgroup/dg_*
#chown grid:oinstall /dev/diskgroup/dg_*

#chown -R grid:oinstall /dev/sdb 
#chown -R grid:oinstall /dev/sdc 
#chown -R grid:oinstall /dev/sdd 
#chown -R grid:oinstall /dev/sde" >> /etc/init.d/after.local

#######################################ntp文件配置######################################
sed -i 's/NTPD_OPTIONS="-g -u ntp:ntp"/NTPD_OPTIONS="-g -x -u ntp:ntp"/g' /etc/sysconfig/ntp

##########################解压oracle安装文件###################
echo -e "\nINFO:===`date`===unzip Oracle Media to ${ORADIR}..." | tee -a $LOGFILE
#unzip -o p13390677_112040_Linux-x86-64_1of7.zip -d $ORADIR | tee -a $UNZIPLOG
#unzip -o p13390677_112040_Linux-x86-64_2of7.zip -d $ORADIR | tee -a $UNZIPLOG
#unzip -o p13390677_112040_Linux-x86-64_3of7.zip -d $ORADIR | tee -a $UNZIPLOG
#unzip -o p13390677_112040_Linux-x86-64_4of7.zip -d $ORADIR | tee -a $UNZIPLOG
chown -R oracle.oinstall $ORADIR/database
chown -R grid.dba $ORADIR/grid

#########################准备安装数据库软件#############################
echo -e "\nINFO:===`date`===Begin installing Oracle 11.2.0.4.0 Software Only..." | tee -a $LOGFILE

########################配置数据库软件安装响应文件######################
echo "oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v11_2_0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=/opt/oraInventory
SELECTED_LANGUAGES=en,zh_CN
ORACLE_HOME=$ORACLEHOME
ORACLE_BASE=$ORACLEBASE
oracle.install.db.InstallEdition=EE
oracle.install.db.EEOptionsSelection=false
oracle.install.db.DBA_GROUP=dba
oracle.install.db.OPER_GROUP=oinstall
oracle.install.db.isRACOneInstall=false
oracle.install.db.config.starterdb.type=GENERAL_PURPOSE
oracle.install.db.config.starterdb.memoryOption=false
oracle.install.db.config.starterdb.installExampleSchemas=false
oracle.install.db.config.starterdb.enableSecuritySettings=true
oracle.install.db.config.starterdb.control=DB_CONTROL
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
DECLINE_SECURITY_UPDATES=true
oracle.installer.autoupdates.option=SKIP_UPDATES" > $RSPPATH/install.rsp

chown oracle:oinstall $RSPPATH/install.rsp
chmod 755 $RSPPATH/install.rsp

###########################静默安装数据库软件###########################
su - oracle -c "$ORADIR/database/runInstaller -silent \ -responseFile $RSPPATH/install.rsp -showprogress" | tee -a $LOGFILE |grep -v ACTION
echo "setup oracle software complete!" | tee -a $LOGFILE
echo -e "\nwaiting for system running root.sh. \n"
/opt/oraInventory/orainstRoot.sh | tee -a $LOGFILE
$ORACLEBASE/product/11gR2/db/root.sh | tee -a $LOGFILE

###########################创建数据库实例################################
. /home/oracle/.profile

#################FileSystem方式或本地磁盘模式的响应文件##################
if [[ "$DATATYPE"x != "raw"x ]] || [[ "$Disk"x == "Null"x ]]; then
######################创建dbca.rsp响应文件###############################
echo '[GENERAL]
RESPONSEFILE_VERSION = "11.2.0"
OPERATION_TYPE = "createDatabase"
[CREATEDATABASE]
GDBNAME = "zhangyi"
SID = "zhangyi"
PROCESSES=1000
SYSPASSWORD = "oracle"
SYSTEMPASSWORD = "oracle"
EMCONFIGURATION = "NONE"
DISABLESECURITYCONFIGURATION = "NONE"
SYSMANPASSWORD = "oracle"
DBSNMPPASSWORD = "oracle"
HOSTUSERNAME = "oracle"
HOSTUSERPASSWORD= "oracle"
STORAGETYPE=FS
CHARACTERSET = "ZHS16GBK"
NATIONALCHARACTERSET= "UTF8"
MEMORYPERCENTAGE = "40"
TOTALMEMORY = "800"
[createTemplateFromDB]
SOURCEDB = "myhost:1521:orcl"
SYSDBAUSERNAME = "system"
TEMPLATENAME = "My Copy TEMPLATE"
[createCloneTemplate]
SOURCEDB = "orcl"
TEMPLATENAME = "My Clone TEMPLATE"
[DELETEDATABASE]
SOURCEDB = "orcl"
[generateScripts]
TEMPLATENAME = "New Database"
GDBNAME = "orcl11.us.oracle.com"
[CONFIGUREDATABASE]
[ADDINSTANCE]
DB_UNIQUE_NAME = "orcl11g.us.oracle.com"
NODELIST=
SYSDBAUSERNAME = "sys"
[DELETEINSTANCE]
DB_UNIQUE_NAME = "orcl11g.us.oracle.com"
INSTANCENAME = "orcl11g"
SYSDBAUSERNAME = "sys"' > $RSPPATH/dbca_$OracleSID.rsp
sed -i "/HOSTUSERPASSWORD/a\DATAFILEDESTINATION = '$DATAPATH'" $RSPPATH/dbca_$OracleSID.rsp
sed -i s#\'#\"#g $RSPPATH/dbca_$OracleSID.rsp
###########################创建模版##########################
echo '<?xml version = "'1.0'"?>
<DatabaseTemplate name="ZhangYi" description=" " version="11.2.0.4.0">
   <CommonAttributes>
      <option name="OMS" value="false"/>
      <option name="JSERVER" value="false"/>
      <option name="SPATIAL" value="false"/>
      <option name="IMEDIA" value="false"/>
      <option name="XDB_PROTOCOLS" value="false">
         <tablespace id="SYSAUX"/>
      </option>
      <option name="ORACLE_TEXT" value="false">
         <tablespace id="SYSAUX"/>
      </option>
      <option name="SAMPLE_SCHEMA" value="false"/>
      <option name="CWMLITE" value="false">
         <tablespace id="SYSAUX"/>
      </option>
      <option name="EM_REPOSITORY" value="false">
         <tablespace id="SYSAUX"/>
      </option>
      <option name="APEX" value="false"/>
      <option name="OWB" value="false"/>
      <option name="DV" value="false"/>
   </CommonAttributes>
   <Variables/>
   <CustomScripts Execute="false"/>
   <InitParamAttributes>
      <InitParams>
         <initParam name="db_name" value=""/>
         <initParam name="db_domain" value=""/>
         <initParam name="audit_file_dest" value="{ORACLE_BASE}/admin/{DB_UNIQUE_NAME}/adump"/>
         <initParam name="compatible" value="11.2.0.4.0"/>
         <initParam name="remote_login_passwordfile" value="EXCLUSIVE"/>
         <initParam name="sga_target" value="3600" unit="MB"/>
         <initParam name="processes" value="1500"/>
         <initParam name="undo_tablespace" value="UNDOTBS1"/>
         <initParam name="control_files" value="(&quot;/oradata/{DB_UNIQUE_NAME}/control01.ctl&quot;, &quot;/oradata/{DB_UNIQUE_NAME}/control02.ctl&quot;;/oradata/{DB_UNIQUE_NAME}/control03.ctl&quot;))"/>
         <initParam name="diagnostic_dest" value="{ORACLE_BASE}"/>
         <initParam name="audit_trail" value="db"/>
         <initParam name="nls_territory" value="CHINA"/>
         <initParam name="sessions" value="1655"/>
         <initParam name="db_block_size" value="8" unit="KB"/>
         <initParam name="open_cursors" value="300"/>
         <initParam name="nls_language" value="SIMPLIFIED CHINESE"/>
         <initParam name="pga_aggregate_target" value="798" unit="MB"/>
      </InitParams>
      <MiscParams>
         <databaseType>MULTIPURPOSE</databaseType>
         <maxUserConn>200</maxUserConn>
         <percentageMemTOSGA>60</percentageMemTOSGA>
         <customSGA>false</customSGA>
         <characterSet>ZHS16GBK</characterSet>
         <nationalCharacterSet>AL16UTF16</nationalCharacterSet>
         <archiveLogMode>false</archiveLogMode>
         <initParamFileName>{ORACLE_BASE}/admin/{DB_UNIQUE_NAME}/pfile/init.ora</initParamFileName>
      </MiscParams>
      <SPfile useSPFile="true">{ORACLE_HOME}/dbs/spfile{SID}.ora</SPfile>
   </InitParamAttributes>
   <StorageAttributes>
      <ControlfileAttributes id="Controlfile">
         <maxDatafiles>100</maxDatafiles>
         <maxLogfiles>16</maxLogfiles>
         <maxLogMembers>3</maxLogMembers>
         <maxLogHistory>1</maxLogHistory>
         <maxInstances>8</maxInstances>
         <image name="control01.ctl" filepath="/oradata/{DB_UNIQUE_NAME}/"/>
         <image name="control02.ctl" filepath="/oradata/{DB_UNIQUE_NAME}/"/>
         <image name="control03.ctl" filepath="/oradata/{DB_UNIQUE_NAME}/"/>
      </ControlfileAttributes>
      <DatafileAttributes id="/oradata/{DB_UNIQUE_NAME}/sysaux01.dbf">
         <tablespace>SYSAUX</tablespace>
         <temporary>false</temporary>
         <online>true</online>
         <status>0</status>
         <size unit="MB">600</size>
         <reuse>true</reuse>
         <autoExtend>true</autoExtend>
         <increment unit="KB">10240</increment>
         <maxSize unit="MB">-1</maxSize>
      </DatafileAttributes>
      <DatafileAttributes id="/oradata/{DB_UNIQUE_NAME}/system01.dbf">
         <tablespace>SYSTEM</tablespace>
         <temporary>false</temporary>
         <online>true</online>
         <status>0</status>
         <size unit="MB">700</size>
         <reuse>true</reuse>
         <autoExtend>true</autoExtend>
         <increment unit="KB">10240</increment>
         <maxSize unit="MB">-1</maxSize>
      </DatafileAttributes>
      <DatafileAttributes id="/oradata/{DB_UNIQUE_NAME}/temp01.dbf">
         <tablespace>TEMP</tablespace>
         <temporary>false</temporary>
         <online>true</online>
         <status>0</status>
         <size unit="MB">20</size>
         <reuse>true</reuse>
         <autoExtend>true</autoExtend>
         <increment unit="KB">640</increment>
         <maxSize unit="MB">-1</maxSize>
      </DatafileAttributes>
      <DatafileAttributes id="/oradata/{DB_UNIQUE_NAME}/undotbs01.dbf">
         <tablespace>UNDOTBS1</tablespace>
         <temporary>false</temporary>
         <online>true</online>
         <status>0</status>
         <size unit="MB">200</size>
         <reuse>true</reuse>
         <autoExtend>true</autoExtend>
         <increment unit="KB">5120</increment>
         <maxSize unit="MB">-1</maxSize>
      </DatafileAttributes>
      <DatafileAttributes id="/oradata/{DB_UNIQUE_NAME}/users01.dbf">
         <tablespace>USERS</tablespace>
         <temporary>false</temporary>
         <online>true</online>
         <status>0</status>
         <size unit="MB">5</size>
         <reuse>true</reuse>
         <autoExtend>true</autoExtend>
         <increment unit="KB">1280</increment>
         <maxSize unit="MB">-1</maxSize>
      </DatafileAttributes>
      <TablespaceAttributes id="SYSAUX">
         <online>true</online>
         <offlineMode>1</offlineMode>
         <readOnly>false</readOnly>
         <temporary>false</temporary>
         <defaultTemp>false</defaultTemp>
         <undo>false</undo>
         <local>true</local>
         <blockSize>-1</blockSize>
         <allocation>1</allocation>
         <uniAllocSize unit="KB">-1</uniAllocSize>
         <initSize unit="KB">64</initSize>
         <increment unit="KB">64</increment>
         <incrementPercent>50</incrementPercent>
         <minExtends>1</minExtends>
         <maxExtends>4096</maxExtends>
         <minExtendsSize unit="KB">64</minExtendsSize>
         <logging>true</logging>
         <recoverable>false</recoverable>
         <maxFreeSpace>0</maxFreeSpace>
         <autoSegmentMgmt>true</autoSegmentMgmt>
         <bigfile>false</bigfile>
         <datafilesList>
            <TablespaceDatafileAttributes id="/oradata/{DB_UNIQUE_NAME}/sysaux01.dbf">
               <id>-1</id>
            </TablespaceDatafileAttributes>
         </datafilesList>
      </TablespaceAttributes>
      <TablespaceAttributes id="SYSTEM">
         <online>true</online>
         <offlineMode>1</offlineMode>
         <readOnly>false</readOnly>
         <temporary>false</temporary>
         <defaultTemp>false</defaultTemp>
         <undo>false</undo>
         <local>true</local>
         <blockSize>-1</blockSize>
         <allocation>3</allocation>
         <uniAllocSize unit="KB">-1</uniAllocSize>
         <initSize unit="KB">64</initSize>
         <increment unit="KB">64</increment>
         <incrementPercent>50</incrementPercent>
         <minExtends>1</minExtends>
         <maxExtends>-1</maxExtends>
         <minExtendsSize unit="KB">64</minExtendsSize>
         <logging>true</logging>
         <recoverable>false</recoverable>
         <maxFreeSpace>0</maxFreeSpace>
         <autoSegmentMgmt>true</autoSegmentMgmt>
         <bigfile>false</bigfile>
         <datafilesList>
            <TablespaceDatafileAttributes id="/oradata/{DB_UNIQUE_NAME}/system01.dbf">
               <id>-1</id>
            </TablespaceDatafileAttributes>
         </datafilesList>
      </TablespaceAttributes>
      <TablespaceAttributes id="TEMP">
         <online>true</online>
         <offlineMode>1</offlineMode>
         <readOnly>false</readOnly>
         <temporary>true</temporary>
         <defaultTemp>true</defaultTemp>
         <undo>false</undo>
         <local>true</local>
         <blockSize>-1</blockSize>
         <allocation>1</allocation>
         <uniAllocSize unit="KB">-1</uniAllocSize>
         <initSize unit="KB">64</initSize>
         <increment unit="KB">64</increment>
         <incrementPercent>0</incrementPercent>
         <minExtends>1</minExtends>
         <maxExtends>0</maxExtends>
         <minExtendsSize unit="KB">64</minExtendsSize>
         <logging>true</logging>
         <recoverable>false</recoverable>
         <maxFreeSpace>0</maxFreeSpace>
         <autoSegmentMgmt>true</autoSegmentMgmt>
         <bigfile>false</bigfile>
         <datafilesList>
            <TablespaceDatafileAttributes id="/oradata/{DB_UNIQUE_NAME}/temp01.dbf">
               <id>-1</id>
            </TablespaceDatafileAttributes>
         </datafilesList>
      </TablespaceAttributes>
      <TablespaceAttributes id="UNDOTBS1">
         <online>true</online>
         <offlineMode>1</offlineMode>
         <readOnly>false</readOnly>
         <temporary>false</temporary>
         <defaultTemp>false</defaultTemp>
         <undo>true</undo>
         <local>true</local>
         <blockSize>-1</blockSize>
         <allocation>1</allocation>
         <uniAllocSize unit="KB">-1</uniAllocSize>
         <initSize unit="KB">512</initSize>
         <increment unit="KB">512</increment>
         <incrementPercent>50</incrementPercent>
         <minExtends>8</minExtends>
         <maxExtends>4096</maxExtends>
         <minExtendsSize unit="KB">512</minExtendsSize>
         <logging>true</logging>
         <recoverable>false</recoverable>
         <maxFreeSpace>0</maxFreeSpace>
         <autoSegmentMgmt>true</autoSegmentMgmt>
         <bigfile>false</bigfile>
         <datafilesList>
            <TablespaceDatafileAttributes id="/oradata/{DB_UNIQUE_NAME}/undotbs01.dbf">
               <id>-1</id>
            </TablespaceDatafileAttributes>
         </datafilesList>
      </TablespaceAttributes>
      <TablespaceAttributes id="USERS">
         <online>true</online>
         <offlineMode>1</offlineMode>
         <readOnly>false</readOnly>
         <temporary>false</temporary>
         <defaultTemp>false</defaultTemp>
         <undo>false</undo>
         <local>true</local>
         <blockSize>-1</blockSize>
         <allocation>1</allocation>
         <uniAllocSize unit="KB">-1</uniAllocSize>
         <initSize unit="KB">128</initSize>
         <increment unit="KB">128</increment>
         <incrementPercent>0</incrementPercent>
         <minExtends>1</minExtends>
         <maxExtends>4096</maxExtends>
         <minExtendsSize unit="KB">128</minExtendsSize>
         <logging>true</logging>
         <recoverable>false</recoverable>
         <maxFreeSpace>0</maxFreeSpace>
         <autoSegmentMgmt>true</autoSegmentMgmt>
         <bigfile>false</bigfile>
         <datafilesList>
            <TablespaceDatafileAttributes id="/oradata/{DB_UNIQUE_NAME}/users01.dbf">
               <id>-1</id>
            </TablespaceDatafileAttributes>
         </datafilesList>
      </TablespaceAttributes>
      <RedoLogGroupAttributes id="1">
         <reuse>false</reuse>
         <fileSize unit="KB">512000</fileSize>
         <Thread>1</Thread>
         <member ordinal="0" memberName="redo01.log" filepath="/oradata/{DB_UNIQUE_NAME}/"/>
         <member ordinal="2" memberName="redo02.log" filepath="/oradata/{DB_UNIQUE_NAME}/"/>
      </RedoLogGroupAttributes>
      <RedoLogGroupAttributes id="2">
         <reuse>false</reuse>
         <fileSize unit="KB">512000</fileSize>
         <Thread>1</Thread>
         <member ordinal="0" memberName="redo03.log" filepath="/oradata/{DB_UNIQUE_NAME}/"/>
         <member ordinal="2" memberName="redo04.log" filepath="/oradata/{DB_UNIQUE_NAME}/"/>
      </RedoLogGroupAttributes>
      <RedoLogGroupAttributes id="3">
         <reuse>false</reuse>
         <fileSize unit="KB">512000</fileSize>
         <Thread>1</Thread>
         <member ordinal="0" memberName="redo05.log" filepath="/oradata/{DB_UNIQUE_NAME}/"/>
         <member ordinal="1" memberName="redo06.log" filepath="/oradata/{DB_UNIQUE_NAME}/"/>
      </RedoLogGroupAttributes>
   </StorageAttributes>
</DatabaseTemplate>' > $ORACLE_HOME/assistants/dbca/templates/ZhangYi.dbt
sed -i "s#/oradata#$DATAPATH#g" $ORACLE_HOME/assistants/dbca/templates/ZhangYi.dbt
###############################修改响应文件和模板权限###############################
chown oracle:oinstall $RSPPATH/dbca_$OracleSID.rsp $ORACLE_HOME/assistants/dbca/templates/ZhangYi.dbt
chmod 755 $RSPPATH/dbca_$OracleSID.rsp $ORACLE_HOME/assistants/dbca/templates/ZhangYi.dbt
else
#####################创建RAW方式的响应文件和模板######################
if [[ "$DIFFCOUNT"x == "0 $DIFFFILE"x ]]; then
mkdir -p $ORACLEBASE/admin/$OracleSID/scripts/
echo "SET VERIFY OFF
connect \"SYS\"/\"&&sysPassword\" as SYSDBA
set echo on
spool /opt/oracle/admin/zhangyi/scripts/CreateDB.log append
startup nomount pfile=\"/opt/oracle/admin/zhangyi/scripts/init.ora\";
CREATE DATABASE \"zhangyi\"
MAXINSTANCES 8
MAXLOGHISTORY 1
MAXLOGFILES 16
MAXLOGMEMBERS 3
MAXDATAFILES 200
DATAFILE '/dev/raw/raw1' SIZE 4000M REUSE AUTOEXTEND OFF 
EXTENT MANAGEMENT LOCAL
SYSAUX DATAFILE '/dev/raw/raw2' SIZE 4000M REUSE AUTOEXTEND OFF
SMALLFILE DEFAULT TEMPORARY TABLESPACE TEMP TEMPFILE '/dev/raw/raw4' SIZE 4000M REUSE AUTOEXTEND OFF
SMALLFILE UNDO TABLESPACE \"UNDOTBS1\" DATAFILE '/dev/raw/raw5' SIZE 4000M REUSE AUTOEXTEND OFF
CHARACTER SET ZHS16GBK
NATIONAL CHARACTER SET UTF8
LOGFILE GROUP 1 ('/dev/raw/raw6', '/dev/raw/raw7') SIZE 500M,
GROUP 2 ('/dev/raw/raw8', '/dev/raw/raw9') SIZE 500M,
GROUP 3 ('/dev/raw/raw10', '/dev/raw/raw11') SIZE 500M
USER SYS IDENTIFIED BY \"&&sysPassword\" USER SYSTEM IDENTIFIED BY \"&&systemPassword\";
spool off
" > $ORACLEBASE/admin/$OracleSID/scripts/CreateDB.sql

echo "SET VERIFY OFF
connect \"SYS\"/\"&&sysPassword\" as SYSDBA
set echo on
spool /opt/oracle/admin/zhangyi/scripts/CreateDBCatalog.log append
@/opt/oracle/product/11gR2/db/rdbms/admin/catalog.sql;
@/opt/oracle/product/11gR2/db/rdbms/admin/catblock.sql;
@/opt/oracle/product/11gR2/db/rdbms/admin/catproc.sql;
@/opt/oracle/product/11gR2/db/rdbms/admin/catoctk.sql;
@/opt/oracle/product/11gR2/db/rdbms/admin/owminst.plb;
connect \"SYSTEM\"/\"&&systemPassword\"
@/opt/oracle/product/11gR2/db/sqlplus/admin/pupbld.sql;
connect \"SYSTEM\"/\"&&systemPassword\"
set echo on
spool /opt/oracle/admin/zhangyi/scripts/sqlPlusHelp.log append
@/opt/oracle/product/11gR2/db/sqlplus/admin/help/hlpbld.sql helpus.sql;
spool off
spool off
" > $ORACLEBASE/admin/$OracleSID/scripts/CreateDBCatalog.sql

echo "SET VERIFY OFF
connect \"SYS\"/\"&&sysPassword\" as SYSDBA
set echo on
spool /opt/oracle/admin/zhangyi/scripts/CreateDBFiles.log append
CREATE SMALLFILE TABLESPACE \"USERS\" LOGGING DATAFILE '/dev/raw/raw3' SIZE 2000M REUSE AUTOEXTEND OFF EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT  AUTO;
ALTER DATABASE DEFAULT TABLESPACE \"USERS\";
spool off
" > $ORACLEBASE/admin/$OracleSID/scripts/CreateDBFiles.sql

echo "db_block_size=8192
open_cursors=300
db_domain=\"\"
db_name=\"zhangyi\"
control_files=(\"/dev/raw/raw12\", \"/dev/raw/raw13\", \"/dev/raw/raw14\")
compatible=11.2.0.4.0
db_unique_name=\"zhangyi\"
diagnostic_dest=/opt/oracle
nls_language=\"SIMPLIFIED CHINESE\"
nls_territory=\"CHINA\"
processes=1500
sessions=1655
sga_target=3774873600
audit_file_dest=\"/opt/oracle/admin/zhangyi/adump\"
audit_trail=db
remote_login_passwordfile=EXCLUSIVE
pga_aggregate_target=1258291200
undo_tablespace=UNDOTBS1
" > $ORACLEBASE/admin/$OracleSID/scripts/init.ora

echo "SET VERIFY OFF
set echo on
spool /opt/oracle/admin/zhangyi/scripts/lockAccount.log append
BEGIN 
 FOR item IN ( SELECT USERNAME FROM DBA_USERS WHERE ACCOUNT_STATUS IN ('OPEN', 'LOCKED', 'EXPIRED') AND USERNAME NOT IN ( 
'SYS','SYSTEM') ) 
 LOOP 
  dbms_output.put_line('Locking and Expiring: ' || item.USERNAME); 
  execute immediate 'alter user ' ||
 	 sys.dbms_assert.enquote_name(
 	 sys.dbms_assert.schema_name(
 	 item.USERNAME),false) || ' password expire account lock' ;
 END LOOP;
END;
/
spool off
" > $ORACLEBASE/admin/$OracleSID/scripts/lockAccount.sql

echo "SET VERIFY OFF
connect \"SYS\"/\"&&sysPassword\" as SYSDBA
set echo on
spool /opt/oracle/admin/zhangyi/scripts/postDBCreation.log append
execute DBMS_AUTO_TASK_ADMIN.disable();
@/opt/oracle/product/11gR2/db/rdbms/admin/catbundleapply.sql;
select 'utl_recomp_begin: ' || to_char(sysdate, 'HH:MI:SS') from dual;
execute utl_recomp.recomp_serial();
select 'utl_recomp_end: ' || to_char(sysdate, 'HH:MI:SS') from dual;
connect \"SYS\"/\"&&sysPassword\" as SYSDBA
set echo on
create spfile='/dev/raw/raw15' FROM pfile='/opt/oracle/admin/zhangyi/scripts/init.ora';
shutdown immediate;
connect \"SYS\"/\"&&sysPassword\" as SYSDBA
startup ;
spool off
exit;
" > $ORACLEBASE/admin/$OracleSID/scripts/postDBCreation.sql

echo '#!/bin/sh

OLD_UMASK=`umask`
umask 0027
mkdir -p /opt/oracle/admin/zhangyi/adump
mkdir -p /opt/oracle/admin/zhangyi/dpdump
mkdir -p /opt/oracle/admin/zhangyi/pfile
mkdir -p /opt/oracle/cfgtoollogs/dbca/zhangyi
mkdir -p /opt/oracle/oradata
mkdir -p /opt/oracle/oradata/zhangyi
mkdir -p /opt/oracle/product/11gR2/db/dbs
umask ${OLD_UMASK}
ORACLE_SID=zhangyi; export ORACLE_SID
PATH=$ORACLE_HOME/bin:$PATH; export PATH
echo You should Add this entry in the /etc/oratab: zhangyi:/opt/oracle/product/11gR2/db:Y
/opt/oracle/product/11gR2/db/bin/sqlplus /nolog @/opt/oracle/admin/zhangyi/scripts/zhangyi.sql
' > $ORACLEBASE/admin/$OracleSID/scripts/$OracleSID.sh

echo "set verify off
ACCEPT sysPassword CHAR PROMPT 'Enter new password for SYS: ' HIDE
ACCEPT systemPassword CHAR PROMPT 'Enter new password for SYSTEM: ' HIDE
host /opt/oracle/product/11gR2/db/bin/orapwd file=/opt/oracle/product/11gR2/db/dbs/orapwzhangyi force=y
@/opt/oracle/admin/zhangyi/scripts/CreateDB.sql
@/opt/oracle/admin/zhangyi/scripts/CreateDBFiles.sql
@/opt/oracle/admin/zhangyi/scripts/CreateDBCatalog.sql
@/opt/oracle/admin/zhangyi/scripts/lockAccount.sql
@/opt/oracle/admin/zhangyi/scripts/postDBCreation.sql
" > $ORACLEBASE/admin/$OracleSID/scripts/$OracleSID.sql

sed -i "s/zhangyi/$OracleSID/" $ORACLEBASE/admin/$OracleSID/scripts/*.sh
sed -i "s/zhangyi/$OracleSID/" $ORACLEBASE/admin/$OracleSID/scripts/*.sql
sed -i "s/zhangyi/$OracleSID/" $ORACLEBASE/admin/$OracleSID/scripts/*.ora
sed -i "s/zhangyi/$OracleSID/" $ORACLEBASE/admin/$OracleSID/scripts/$OracleSID.sh

chmod -R 755 $ORACLEBASE/admin/$OracleSID
chown -R oracle.oinstall $ORACLEBASE/admin/$OracleSID

echo "Create CreateDB script for raw , ORACLE_sid is $OracleSID ..."
fi

fi
#################################选择相应数据库模版#################################
echo "Which Database_Mode you like to install :"
echo -e "\n   1) Custum Database -Slow(raw or FS)       2) General Purpose -Fast(Only FS)       3) Exit.\n"
read -p "Please Make Choice  (Choose a Number...)   " DBTemplateName
case $DBTemplateName in
1) 
if [[ "$DATATYPE"x != "raw"x ]] || [[ "$Disk"x == "Null"x ]]; then
sed -i "s/zhangyi/$OracleSID/g" $RSPPATH/dbca_$OracleSID.rsp
sed -i '/TEMPLATENAME/'d $RSPPATH/dbca_$OracleSID.rsp
sed -i '/PROCESSES/a\TEMPLATENAME = "ZhangYi.dbt"' $RSPPATH/dbca_$OracleSID.rsp
echo "===`date`===begin create oracle instance...." | tee -a $LOGFILE
su -  oracle -c "export LANG=en; dbca -silent -responseFile $RSPPATH/dbca_$OracleSID.rsp" | tee -a $LOGFILE
else
if [[ "$DIFFCOUNT"x == "0 $DIFFFILE"x ]]; then
su - oracle -c "$ORACLEBASE/admin/$OracleSID/scripts/$OracleSID.sh"
sleep 3;
echo "spfile=dev/raw/raw15" > $ORACLEHOME/dbs/init$OracleSID.ora
chown oracle:oinstall $ORACLEHOME/dbs/init$OracleSID.ora
su - oracle -c "echo startup|sqlplus / as sysdba" | tee -a $LOGFILE
fi
fi
;;
2) 
if [[ "$DATATYPE"x != "raw"x ]] || [[ "$Disk"x == "Null"x ]]; then
sed -i "s/zhangyi/$OracleSID/g" $RSPPATH/dbca_$OracleSID.rsp
sed -i '/TEMPLATENAME/'d $RSPPATH/dbca_$OracleSID.rsp
sed -i '/PROCESSES/a\TEMPLATENAME = "General_Purpose.dbc"' $RSPPATH/dbca_$OracleSID.rsp
sed -i 's#<percentageMemTOSGA>40</percentageMemTOSGA>#<percentageMemTOSGA>60</percentageMemTOSGA>#g' $ORACLE_HOME/assistants/dbca/templates/General_Purpose.dbc
#sed -i 's#{ORACLE_BASE}/fast_recovery_area/#{ORACLE_BASE}/oradata/#g' $ORACLE_HOME/assistants/dbca/templates/General_Purpose.dbc
echo "===`date`===begin create oracle instance...." | tee -a $LOGFILE
su -  oracle -c "export LANG=en; dbca -silent -responseFile $RSPPATH/dbca_$OracleSID.rsp" | tee -a $LOGFILE
else
exit 0
fi
;;
3)
exit 8
;;
esac

echo "INFO:===`date`===end create oracle instance...." | tee -a $LOGFILE
echo "INFO:===`date`===config dbca for oracle successful " | tee -a $LOGFILE
#######################################配置监听######################################
HOSTNAME=`hostname`
echo -e "\nhost name is $HOSTNAME" | tee -a $LOGFILE
echo -e "\nORACLE_HOME is $ORACLE_HOME" | tee -a $LOGFILE

su - oracle -c "lsnrctl stop;sleep 1"
su - oracle -c "lsnrctl stop LISTENER_$OracleSID;sleep 1"

. /home/oracle/.profile

sed -i "/LISTENER_$OracleSID/,+12d" $ORACLE_HOME/network/admin/listener.ora
sed -i "/$OracleSID/,+8d" $ORACLE_HOME/network/admin/tnsnames.ora
cd $ORACLE_HOME/network/admin/
echo "LISTENER_$OracleSID =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = $HOSTNAME)(PORT = $ORACLEPORT))
  )

SID_LIST_LISTENER_$OracleSID =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = $OracleSID)
      (ORACLE_HOME = $ORACLE_HOME)
      (SID_NAME = $OracleSID)
    )
  )" >> listener.ora

echo "$OracleSID =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = $HOSTNAME)(PORT = $ORACLEPORT))
    )
    (CONNECT_DATA =
      (SERVICE_NAME = $OracleSID)
    )
  )" >> tnsnames.ora
  
chmod 755 listener.ora tnsnames.ora
chown oracle.oinstall listener.ora tnsnames.ora

su - oracle -c "lsnrctl stop;sleep 1"
su - oracle -c "lsnrctl stop LISTENER_$OracleSID;sleep 1"
su - oracle -c "lsnrctl start LISTENER_$OracleSID"| tee -a $LOGFILE
echo -e "\nconfig oracle Listener and Net Service complete!" | tee -a $LOGFILE

####################检查数据库实例状态###################
TNSPROC=`ps -ef|grep "tnslsnr "|grep -v grep` >/dev/null
DBWPROC=`ps -ef|grep "ora_dbw"|grep -v grep` >/dev/null
LGWRPROC=`ps -ef|grep "ora_lgwr_"|grep -v grep` >/dev/null
SMONPROC=`ps -ef|grep "ora_smon_"|grep -v grep` >/dev/null
PMONPROC=`ps -ef|grep "ora_pmon_"|grep -v grep` >/dev/null
MMONPROC=`ps -ef|grep "ora_mmon_"|grep -v grep` >/dev/null
CHECKRESULT=0
su - oracle -c 'sqlplus -S system/oracle@"$ORACLE_SID" << !
spool $ORACLE_BASE/checkresult.t;
select * from all_users;
spool off;
exit;
!
exit 9'
if [ -f $ORACLEBASE/checkresult.t ]; then
  CHECKRESULT=`cat $ORACLEBASE/checkresult.t|wc -l` >/dev/null   
  rm $ORACLEBASE/checkresult.t
fi

TNSPROC1=`echo "$TNSPROC" | awk '{print $2}'`
DBWPROC1=`echo "$DBWPROC" | awk '{print $2}'`
LGWRPROC1=`echo "$LGWRPROC" | awk '{print $2}'`
SMONPROC1=`echo "$SMONPROC" | awk '{print $2}'`
PMONPROC1=`echo "$PMONPROC" | awk '{print $2}'`
MMONPROC1=`echo "$MMONPROC" | awk '{print $2}'`
echo "TNSPROC=$TNSPROC1,DBWPROC=$DBWPROC1,LGWRPROC=$LGWRPROC1,SMONPROC=$SMONPROC1,PMONPROC=$PMONPROC1,MMONPROC=$MMONPROC1,CHECKRESULT=$CHECKRESULT"

if [ -n "$TNSPROC" -a -n "$DBWPROC" -a $CHECKRESULT -gt 0 -a -n "$LGWRPROC" -a -n "$SMONPROC" -a -n "$PMONPROC" -a -n "$MMONPROC" ]; then
  echo "INFO:===`date`===Setup Successful"| tee -a $LOGFILE
else
  echo "INFO:===`date`===Setup Failed" | tee -a $LOGFILE
  exit 10
fi

######################数据库调优###################
echo -e "INFO:===`date`===Please Check Oracle...\n" | tee -a $LOGFILE

su - oracle -c "sqlplus / as sysdba" << !
alter system set recyclebin= off scope=spfile;
alter system set audit_trail=none scope=spfile;
truncate table sys.aud$;
ALTER PROFILE DEFAULT LIMIT FAILED_LOGIN_ATTEMPTS UNLIMITED;
ALTER PROFILE DEFAULT LIMIT PASSWORD_LIFE_TIME UNLIMITED;
shutdown immediate
!

####################文件系统方式-修改spfile位置#################
if [[ "$DATATYPE"x != "raw"x ]] || [[ "$Disk"x == "Null"x ]]; then
. /home/oracle/.profile
mv $ORACLE_HOME/dbs/spfile$OracleSID.ora $DATAPATH/$OracleSID/
mv $ORACLE_HOME/dbs/init$OracleSID.ora $ORACLE_HOME/dbs/`date +"%Y%m%d"`_init$OracleSID.ora
echo "spfile=$DATAPATH/$OracleSID/spfile$OracleSID.ora" > $ORACLE_HOME/dbs/init$OracleSID.ora
chown oracle:oinstall $ORACLE_HOME/dbs/init$OracleSID.ora
su - oracle -c "echo startup|sqlplus / as sysdba" | tee -a $LOGFILE
else
su - oracle -c "echo startup|sqlplus / as sysdba" | tee -a $LOGFILE
fi

####################裸设备方式-修改spfile位置#################
#if [[ "$DATATYPE"x == "raw"x -a "$DIFFCOUNT"x != "0 $DIFFFILE"x ]]; then


#fi
######################显示安装成功####################
echo -e "\nINFO:===`date`===Oracle has installed OK...\n" | tee -a $LOGFILE
