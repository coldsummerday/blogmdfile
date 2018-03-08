#简介

/dev 
目录下放设备信息
##字符设备:
每次与系统传输一个字符的设备

在实现的时候,大多数不使用缓存器,直接从设备读取/写入一个字符(键盘)

##块设备:


用块与系统交互,如(CD)








/dev/null 黑洞设备,
用来丢弃无用的输出流



dd 命令,设备到设备, 复制, if =输入,,,of =输出  count=1024(写1024次) bs=1024 (1024个字节)


/dev/full常满设备,再向其写入的时候返回设备无剩余空间

测试程序在遇到磁盘无剩余空间的错误时候的行为




##设备驱动

每个设备都有每个设备的是(csr控制状态寄存器),设备由内核统一管理

* 内核代码
* 为内核提供统一接口
* 动态可加载
* 可配置



设备有主设备号跟从设备号



###例子,网卡驱动的升级:


需要内核c header编译 (需要安装:kernel-devel)


* rpm -qa|grep kernel-devel查看是否安装了这个包
* rpm -V kernel-devel检验文件是否完整
* 若丢失,则rpm -ivh --force kernel-devel-XXXX
* 查看网卡模块名字:#cat /etc/modprode.conf(输出bnx2)
* 检查当前是否已经加载网卡驱动模块bnx2: #lsmod |grep bnx2
* modinfo bnx2(查看版本号)
* 默认从网站下载了某个包.tar.gz文件(网卡驱动文件)
* 解压,进入源码目录,找到.rpm目录
* rpm -ivh name.rpm 安装编译网卡资源
* 编译驱动:rpmbuild -bb 包名.spec
* 安装已经编译好的网卡驱动:rpm -ivh rpms/i386/*.rpm 编译好的二进制文件


###scsi设备

小型计算机系统接口



U盘访问之前,mount 设备名 挂载点, #mount /dev/sda /mnt


