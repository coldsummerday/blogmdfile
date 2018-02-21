#redis on django

##一:安装redis

###1.mac

```
brew install redis
#启动
redis-server
```

###2.ubunetu16.04

* sudo apt-get install redis-server

这样安装的版本是redis2:3.0.6-1,但是现在最新版已经4.0了(~.~)

####2.2源码安装

网站最新的下载地址为:
[最新下载地址](https://redis.io/download)


```bash
wget http://download.redis.io/releases/redis-4.0.8.tar.gz
cd redis-4.0.8
make
cd src
sudo make install
```

make install 会将redis的可执行文件放在 /usr/local/bin 下面

启动redis-server时候:

![](http://orh99zlhi.bkt.clouddn.com/2018-02-10,13:21:36.jpg)


会有三个warning:

解决办法:

```bash
sudo vim /etc/sysctl.conf
```

在末尾写入:

```bash
net.core.somaxconn= 1024
vm.overcommit_memory = 1
```

执行**sudo sysctl -p**

打开**/etc/rc.local**,

在exit之前写入:

```
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then  
   echo never > /sys/kernel/mm/transparent_hugepage/enabled  
fi 
```

重启服务器即可


注:每次django启动需要缓存的时候需要redis-server已经运行,所以一般用supervisor去启动redis-server


##二、redis在django中的使用:

###(1)、配置信息:

django为cache这层封装得很好,以便向下适应各种缓存系统,比如:

* redis
* Memcached

先安装django-redis

```
pip install django-redis
```

所以,我们要使得django与redis连接上,只需要在setting.py中配置相应的rediscache信息即可使用:

setting.py

```python
#redis缓存机制:
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        #本地redis默认开启IP跟端口
        'LOCATION': '127.0.0.1:6379',
        "OPTIONS": {
            "CLIENT_CLASS": "django_redis.client.DefaultClient",
        },
    },
}
```

###(2)测试缓存:


测试连接是否正常:

1. 启动redis后台服务
2. 进入django后台模式:

```python
python manage.py shell
```

```python
from django.core.cache import cache #引入缓存模块
cache.set('k', '12314', 30*60)      #写入key为k，值为12314的缓存，有效期30分钟
cache.has_key('k') #判断key为k是否存在
cache.get('k')     #获取key为k的缓存
```

若正常,打印出12314,则证明连接正常.


###(3)使用缓存

正如(2)中代码看到,在django中使用cache,只需要引入:**from django.core.cache import cache**

```python
cache.get(key)
cache.set(key,value)
```

然而,我们需要考虑两个问题:

* 写入redis的数据是什么形式
* 缓存时效多长

redis支持字符串,列表,集合,字典等数据结构.经测试，可将Python的字典和列表直接存储。你也可以用json模块对字典和列表转化成字符串再存储。

**此外,还可以将django中类直接存储(相当于一个字典,属性名字为key,属性值为value),所以使用自定义类的时候无需专门转化为其他数据结构,拿出来的时候也是同样的类(也许是django封装得太好吧)**

```python
#coding:utf-8
from django.core.cache import cache
import time
 
def get_readed_cache():
    #判断键是否存在
    key = 'readed'
    if cache.has_key(key):
        data = cache.get(key)
    else:
        #不存在，则获取数据，并写入缓存,get_readed_data为获取数据的方法
        data = get_readed_data()
 
        #写入缓存
        cache.set(key, data, 3600-int(time.time() % 3600))
    return data
```

或许这样写不太**优雅**,那岂不是我们存入一种数据就要写一个cache的方法..


###(4)写个cache装饰器

我们可以将获取缓存的数据写一个带参数的装饰器,将键值跟超时时间作为参数:

```python
from django.core.cache import cache
 
#获取redis缓存的装饰器
def redis_cache(key, timeout):
    def redis_cache_inner(func):
        def warpper(*args, **kw):
            #判断缓存是否存在
            if cache.has_key(key):
                data = cache.get(key)
            else:
                #若不存在则执行获取数据的方法
                #注意返回数据的类型(字符串，数字，字典，列表均可)
                data = func(*args, **kw)
                cache.set(key, data, timeout)
            return data
        return warpper
    return redis_cache_inner
```


使用:

```python
#键值为test，超时时间为60秒
@redis_cache('test', 60)
def get_test_data():
    # 获取Article模型随机排序前3条数据
    # (Article模型是我自己的模型，具体代码根据自己需求获取数据)
    # values执行结果，将返回一个字典。字典可以直接存入redis
    data = Blog.objects.values('id', 'title').order_by('?')[:3]
    return data
```

####(5)写个cache通用类
我们期望有一个类,能实现获取该cache的值,能更新cache的值(在内部实现get,set,方法),而且其是一个传入key值,data获取方法的类,当我们需要更新cache的时候,调用内部的cache.set_cache方法就好了.


注:在redis中,对同一个key 赋值,会覆盖掉前一个值,所以更新cache的时候可以直接set(key,newValue).

```python
# 获取和设置缓存的类
class RedisCache():
#第三个参数为更新data的方法,用于包装内部的set_cache
    def __init__(self, key, timeout, get_data_method, args=None, kw=None):
        self.key = key
        self.timeout = timeout
        self.get_data_method = get_data_method
        self.args = [] if args is None else args
        self.kw = {} if kw is None else kw

    def get_cache(self):
        try:
            # 判断缓存是否存在
            if cache.has_key(self.key):
                data = cache.get(self.key)
            else:
                data = self.set_cache()
        except Exception as e:
            # 使用缓存出错，可能是没开启redis
            data = self.get_data_method(*self.args, **self.kw)
        finally:
            return data

    def set_cache(self):
        data = self.get_data_method(*self.args, **self.kw)
        cache.set(self.key, data, self.timeout)
        return data
```


使用的时候:

```python
def get_caches():
    #所需缓存的数据类
    categoryToTagCache = RedisCache('categoryToTagList',60*60*24,getTags)
    categoryList = RedisCache('categoryList',60*60*24,getCategory)
    #将所有需要缓存的数据放入一个字典,key为缓存中的key,然后用这个全局变量来获取key值
    caches = {}
    caches[categoryToTagCache.key] = categoryToTagCache
    caches[categoryList.key] = categoryList

    return caches
    
caches = get_caches()
```

在view.py中使用cache:

```python
from .utils import caches
#utils.py为我定义全局cache变量跟redis_cache类的py文件


#获取cache中的值
    categoryList = caches['categoryList'].get_cache()
    categoryToTagList = caches['categoryToTagList'].get_cache()
```

更新cache:

```
def update_caches():
    for cache in caches.values():
        cache.set_cache()
```



##三、利用django的sinal机制更新缓存

由于我使用cache的场景是:有一个tag与category的一对多关系, 但是我要根据每个tag确定它属于哪个category.这个数据用于博客首页分栏展示且更新频率不大.


所以我放弃了用**Celery**去定时更新cache的形式,而是选择了当有新tag添加的时候,去更新cache

这时候就需要知道tag这个model 在save之前发一个信号给更新函数去更新cache了




django自带一套信号机制来帮助我们在框架的不同位置之间传递信息。也就是说，当某一事件发生时，信号系统可以允许一个或多个发送者（senders）将通知或信号（signals）发送给一组接受者（receivers）。

信号系统包含以下三要素：
>
>发送者－信号的发出方
>
>信号－信号本身

>接收者－信号的接受者



Django内置了一整套信号，下面是一些比较常用的：

>* 在ORM模型的save()方法调用之前或之后发送信号

>```python
django.db.models.signals.pre_save & django.db.models.signals.post_save
```

>* 在ORM模型或查询集的delete()方法调用之前或之后发送信号。

>```python
django.db.models.signals.pre_delete & django.db.models.signals.post_delete
```


>* 当多对多字段被修改时发送信号。

>```python
django.db.models.signals.m2m_changed
```

>* 当接收和关闭HTTP请求时发送信号。

>```python
django.core.signals.request_started & django.core.signals.request_finished
```

显然需求是 接收Tag的post_add或者post_delete信号,并回调用更新cache方法:

###(1)注册信息接受者:
要接收信号，请使用Signal.connect()方法注册一个接收器。当信号发送后，会调用这个接收器。

```python
Signal.connect(receiver, sender=None, weak=True, dispatch_uid=None)[source]

```

* receiver ：当前信号连接的回调函数，也就是处理信号的函数。 
* sender ：指定从哪个发送方接收信号。 
* weak ： 是否弱引用
* dispatch_uid ：信号接收器的唯一标识符，以防信号多次发送。

```python

def my_callback(sender, **kwargs):
    print("Request finished!")
from django.core.signals import request_finished
##手动l连接接收器
request_finished.connect(my_callback)

from django.core.signals import request_finished
from django.dispatch import receiver

#装饰器d 方式连接接收器
@receiver(request_finished)
def my_callback(sender, **kwargs):
    print("Request finished!")
```

###(2)指定信号与信号发出model

```python
from django.db.models.signals import pre_save
from django.dispatch import receiver
from myapp.models import MyModel


@receiver(pre_save, sender=MyModel)
def my_handler(sender, **kwargs):
    ...
```


当一个回调函数想接收多个信号的时候:

```python
@receiver([post_save,post_delete],sender=Category)
def categoryUpdate(sender,**kwargs):
    global caches
    #在tag更新后 更新cache
    caches['categoryToTagList'].set_cache()
```



