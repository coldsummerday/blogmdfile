#AIX
##包:



AIX程序包原理:


LPP:licensed,program product
版权完整的产品

package:软件包,

Fileset:文件及,最小软件单元,提供具体软件实现功能


####软件安装方式:


* applied(新旧软件共存)
* committed(覆盖旧软件)

####安装命令:


```shell
installp -p   #预览这个LPP安装需要多大的空间等信息,没有安装
installp -c  #commit一个处于appily状态的包
installp -r #reject一个处于apply状态的软件包
installp -l #列出软件包
installp -C #清除安装失败的不完整文件或者软件
installp -u #卸载

```



###red hat

rpm

* -V 检查某一rpm包的完整性

MD5校验:将整个文件作为一个大字符串,然后加密运算后得到一个小的字符串.
* -Va 一次性检查所有的包完整性
* -qf  查看某个文件属于哪个rpm包







