##目录的备份:


需要备份的目录:

/etc,包含所有核心配置文件
/var 
/home
/root
/opt

备份命令:

tar

-c创建文档
-x解压文档
-t 列出内容


辅助选项:
-g gzip压缩
-j bzip2压缩
-v 显示文件
--exclude FILE,在压缩过程,不要FILE打包

