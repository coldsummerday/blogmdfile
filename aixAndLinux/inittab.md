


##inittab简介:






k\*,s\*连接文件,链接到启动的服务到目录下/etc/rc.d/init.d/*,

当启动命令为:


```
/etc/rc.d/rc 5
```

启动程序或者命令的为:

```shell
/etc/rc.d/rc5.d/
```

目录下可执行程序


##常见的守护进程:

name|描述
----|---
apmd|高级电源管理守护进程
autofs|自动挂载管理进程automount
crond|Linux下的计划任务的守护进程
named|DNS服务器
netfs|安装NFS,Samba和NetWare网络文件系统
sendmail|邮件服务器
smb|Samba文件共享/打印服务
syslog|一个让系统引导启动syslog和klogd等系统守护进程的脚本


###建立终端:

rc执行完毕后,返回Init,系统环境跟守护进程都设置并启动了.init接下来会打开6个终端:


```shell
1:2345respawn:/sbin/mingetty tty1
2:2345respawn:/sbin/mingetty tty2
3:2345respawn:/sbin/mingetty tty3
4:2345respawn:/sbin/mingetty tty4
5:2345respawn:/sbin/mingetty tty5
6:2345respawn:/sbin/mingetty tty6
```

终端以rc 2,3,4,5启动的时候执行,终端会启动

respawn代表了进程被守护(kill掉也会被重启)



##关机命令:

shutdown 超级用户才能执行


执行后 以广播的命令通知在用的其他用户.

```shell
shutdown [-fFhknc]
```

* -t <秒数>
* -h 时间   (某一时间关机)
* -r 重启

用init命令关机重启:
init 0关机
init 6重启




