

uwsgi与nginx的作用:

* uwsgi作为django的启动服务,用于正确处理各种http 请求 ,返回相应的页面

* nginx作为反向代理服务,用于将http requst 正确地传入到uwsgi,同时,当请求为静态文件的时候直接返回,提高网站效率

所以三者的关系:

```
the web client <->  nginx <->the socket <-> uwsgi <-> Django
```

在本教程中,默认域名**example.com**,端口使用8000.

##一、安装与测试uwsgi

```
pip install uwsgi
```



在你的django项目目录下:运行

```
python manage.py runserver 0.0.0.0:8000
```



打开浏览器,访问你的example.com:8000,若正常访问,则证明你django 项目是正常访问的.
(记得把example.com加入到你的项目setting.py的ALLOWED_HOSTS中)

```bash
uwsgi --http :8000 --module projectname.wsgi
```

* http代表了使用http协议的8000 端口
* module 指定加载的wsgi模块(一般django建立项目的时候已经建立,在django项目的根目录下,名字为项目名字.wsgi)

访问example.com,如果网页正常访问,则证明 uwsgi与django项目能正常地连起来.


##二、安装与使用nginx

停止刚才的uwsgi进程

```bash
sudo apt-get install nginx
sudo service nginx start
```

访问example.com,如果能访问到nginx的默认页面,则证明nginx安装成功


```bash
sudo remove /etc/nginx/site-enabled/default
```

删除掉nginx默认的配置文件,防止它占用掉80端口导致我们的项目无法访问.

在你的django项目的根目录下新建**uwsgi_params**文件,内容为:

```
uwsgi_param  QUERY_STRING       $query_string;
uwsgi_param  REQUEST_METHOD     $request_method;
uwsgi_param  CONTENT_TYPE       $content_type;
uwsgi_param  CONTENT_LENGTH     $content_length;

uwsgi_param  REQUEST_URI        $request_uri;
uwsgi_param  PATH_INFO          $document_uri;
uwsgi_param  DOCUMENT_ROOT      $document_root;
uwsgi_param  SERVER_PROTOCOL    $server_protocol;
uwsgi_param  REQUEST_SCHEME     $scheme;
uwsgi_param  HTTPS              $https if_not_empty;

uwsgi_param  REMOTE_ADDR        $remote_addr;
uwsgi_param  REMOTE_PORT        $remote_port;
uwsgi_param  SERVER_PORT        $server_port;
uwsgi_param  SERVER_NAME        $server_name;
```

在/etc/nginx/sites-available/  目录下新建你的nginx配置文件,比如我的为:blog_nginx.conf

```
# mysite_nginx.conf

# the upstream component nginx needs to connect to
upstream django {
    # server unix:///path/to/your/mysite/mysite.sock; # for a file socket
    server 127.0.0.1:8001; # for a web port socket (we'll use this first)
}

# configuration of the server
server {
    # the port your site will be served on
    listen      8000;
    # the domain name it will serve for
    server_name .example.com; # substitute your machine's IP address or FQDN
    charset     utf-8;

    # max upload size
    client_max_body_size 75M;   # adjust to taste

    # Django media
    location /media  {
        alias /path/to/your/mysite/media;  # your Django project's media files - amend as required
    }

    location /static {
        alias /path/to/your/mysite/static; # your Django project's static files - amend as required
    }

    # Finally, send all non-media requests to the Django server.
    location / {
        uwsgi_pass  django;
        include     /path/to/your/mysite/uwsgi_params; # the uwsgi_params file you installed
    }
}
```

这个配置文件告诉nginx提供来自文件系统的媒体和静态文件，以及处理那些需要Django干预的请求。
然后将该文件cp到/etc/nginx/sites-enabled/下.

重启nginx服务:

```
sudo service nginx resart
```

在你的django的static目录下新建一个1.txt文件,并往里面写入某些内容:

在浏览器中访问example.com/media/1.txt,若浏览器显示的为你刚才写入的东西,则证明nginx已经正常工作;


在django项目根目录运行:

```python
uwsgi --http :8001 --module projectname.wsgi
```

这代表使用内部的8001端口,Nginx将http 请求从80 端口反向代理到8001端口给uwsgi进行处理:

访问example.com,如果正常,则证明uwsgi 与Nginx 已经能正常工作了;


##三、利用sock文件的形式:

目前，我们使用了一个TCP端口socket，因为它简单些，但事实上，使用Unix socket会比端口更好 - 开销更少

将/etc/nginx/site-enabled/目录下你的配置文件中的:


```
server unix:///path/to/your/mysite/mysite.sock; # for a file socket
# server 127.0.0.1:8001; # for a web port socket (we'll use this first)
```


uwsgi 的启动命令改为:

```
uwsgi --socket mysite.sock --module projectname.wsgi
```

```
#另开终端,将mysite.sock 文件的权限改为777
sudo chmod 777 mysite.sock
```


访问example.com,正常的话,则ngxin 与 uwsgi 通过sock文件的显示建立联系了.



配置uwsgi的ini文件,以配置文件的形式启动uwsgi:

创建一个名为 `mysite_uwsgi.ini` 的文件:

```
# mysite_uwsgi.ini file
[uwsgi]

# Django-related settings
# the base directory (full path)
chdir           = /path/to/your/project
# Django's wsgi file
module          = project.wsgi
# the virtualenv (full path)
home            = /path/to/virtualenv

# process-related settings
# master
master          = true
# maximum number of worker processes
processes       = 10
# the socket (use the full path to be safe
socket          = /path/to/your/project/mysite.sock
# ... with appropriate permissions - may be needed
# chmod-socket    = 664
# clear environment on exit
vacuum          = true
```


```
uswgi --ini mysite_uwsgi.ini
```


我项目中的 nginx配置文件内容为:

```
# mysite_nginx.conf
# the upstream component nginx needs to connect to
upstream django{
    server unix:///home/zhou/django-blog/python_blog.sock;
   #server 127.0.0.1:8001;
}
# configuration of the server
server {
    # the port your site will be served on
    listen      80;
    # the domain name it will serve for
    server_name *.haibin.online; # substitute your machine's IP address or FQDN
    charset     utf-8;

    # max upload size
    client_max_body_size 75M;   # adjust to taste

    # Django media
    location /media  {
        alias /home/zhou/django-blog/media;  # your Django project's media files - amend as required
    }

    location /static {
        alias /home/zhou/django-blog/static; # your Django project's static files - amend as required
    }

    # Finally, send all non-media requests to the Django server.
    location / {
    uwsgi_pass django;
    include /home/zhou/django-blog/uwsgi_params;
    }
}
```

```
[uwsgi]

# Django-related settings
# the base directory (full path)
chdir           = /home/zhou/django-blog/
# Django's wsgi file
module          = python_blog.wsgi


# process-related settings
# master
master          = true
# maximum number of worker processes
processes       = 10
# the socket (use the full path to be safe
socket          = /home/zhou/django-blog/python_blog.sock
# ... with appropriate permissions - may be needed
chmod-socket    = 777
# clear environment on exit
vacuum          = true
buffer-size	= 32768 
```









