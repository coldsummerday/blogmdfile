##F对象的使用


class F 代表了模型字段的值,也就是对于一些特殊字段的操作,不需要用python把数据先取到内存中,然后操作,在存储db中.

Django 支持对F() 对象使用加法、减法、乘法、除法、取模以及幂计算等算术操作，两个操作数可以都是常数和其它F() 对象


###字段+1(加减乘除运算都可以)

比如我们需要统计点击量的字段,每次更新操作就是把字段的值加1,按照原来的做法我们需要把django中取出model对象并在内存中操作加一再save~:

```python
In [2]: from blog.models import *

In [3]: from django.db.models import F

In [4]: article = Article.objects.get(pk=25)
(0.001) SELECT "blog_article"."id", "blog_article"."title", "blog_article"."desc", "blog_article"."content", "blog_article"."click_count", "blog_article"."is_recommend", "blog_article"."date_publish", "blog_article"."user_id", "blog_article"."category_id" FROM "blog_article" WHERE "blog_article"."id" = 25; args=(25,)

In [5]: article.click_count+=1

In [6]: article.save(update_fields=['click_count'])
(0.000) BEGIN; args=None
(0.001) UPDATE "blog_article" SET "click_count" = 8 WHERE "blog_article"."id" = 25; args=(8, 25)

```

两条sql语句少不了;


用F对象:

```python
In [7]: Article.objects.filter(pk=25).update(click_count=F('click_count')+1)
(0.000) BEGIN; args=None
(0.001) UPDATE "blog_article" SET "click_count" = ("blog_article"."click_count" + 1) WHERE "blog_article"."id" = 25; args=(1, 25)
Out[7]: 1

```

一条sql语句解决的问题;

注:
 update 方法只有在filter()方法返回的对象中才存在,get()方法返回的对象不存在;
 
 
###组合对象的使用:

F()函数可以在创建模型时根据已知的N个字段组合出另外的字段数据，看下面的例子：

```python
company = Company.objects.annotate(
    chairs_needed=F('num_employees') - F('num_chairs'))
```

###F对象的总结:

F()的用法可以把它类似于sql语句中对 field操作的一个具体值,而不需要把sql 行load进python的内存中进行操作后再返回sql 用一条update语句去解决.


##Q对象(django.db.models.Q):


Q对象用于实现(OR,and,Not)等复杂where条件查询:

###AND查询

将多个Q对象作为非关键参数或者使用**&**连接可实现AND查询

```python
In [12]: Article.objects.filter(Q(title__contains='网络')&Q(title__contains='机器学习'))
Out[12]: (0.000) SELECT "blog_article"."id", "blog_article"."title", "blog_article"."desc", "blog_article"."content", "blog_article"."click_count", "blog_article"."is_recommend", "blog_article"."date_publish", "blog_article"."user_id", "blog_article"."category_id" FROM "blog_article" WHERE ("blog_article"."title" LIKE '%网络%' ESCAPE '\' AND "blog_article"."title" LIKE '%机器学习%' ESCAPE '\') ORDER BY "blog_article"."date_publish" DESC LIMIT 21; args=('%网络%', '%机器学习%')
<QuerySet [<Article: 笨方法学机器学习(三):卷积神经网络>, <Article: 笨方法学机器学习(二):全连接神经网络>]>
```

我们看到在django生成的sql语句中将两个Q对象的查询条件**"blog_article"."title" LIKE '%网络%' ESCAPE '\'**
跟**"blog_article"."title" LIKE '%机器学习%' ESCAPE '\'**用**AND**关键字连接了 起来:


###OR查询

```python
In [15]: Article.objects.filter(Q(title__contains='网络')|Q(title__icontains='django'))
Out[15]: (0.000) SELECT "blog_article"."id", "blog_article"."title", "blog_article"."desc", "blog_article"."content", "blog_article"."click_count", "blog_article"."is_recommend", "blog_article"."date_publish", "blog_article"."user_id", "blog_article"."category_id" FROM "blog_article" WHERE ("blog_article"."title" LIKE '%网络%' ESCAPE '\' OR "blog_article"."title" LIKE '%django%' ESCAPE '\') ORDER BY "blog_article"."date_publish" DESC LIMIT 21; args=('%网络%', '%django%')
<QuerySet [<Article: 笨方法学机器学习(三):卷积神经网络>, <Article: 笨方法学机器学习(二):全连接神经网络>, <Article: Django +Apache部署在ubantu服务器上>, <Article: Django项目部署到pythonanywhere>]>
```


###NOT操作

只需要用**~**取反符号,将Q对象取反即可

```python
In [16]: Article.objects.filter(Q(title__contains='网络')|~Q(title__icontains='django')
    ...: )
Out[16]: (0.001) SELECT "blog_article"."id", "blog_article"."title", "blog_article"."desc", "blog_article"."content", "blog_article"."click_count", "blog_article"."is_recommend", "blog_article"."date_publish", "blog_article"."user_id", "blog_article"."category_id" FROM "blog_article" WHERE ("blog_article"."title" LIKE '%网络%' ESCAPE '\' OR NOT ("blog_article"."title" LIKE '%django%' ESCAPE '\')) ORDER BY "blog_article"."date_publish" DESC LIMIT 21; args=('%网络%', '%django%')
<QuerySet [<Article: 笨方法学机器学习(三):卷积神经网络>, <Article: 笨方法学机器学习(一):聚类>, <Article: git服务器搭建>, <Article: 笨方法学机器学习(二):全连接神经网络>, <Article: 哈工大操作系统实验（六）内存管理>, <Article: 哈工大操作系统实验（五）I/O设备管理>, <Article: 哈工大操作系统实验（四）进程同步>, <Article: 哈工大操作系统实验(三)进程管理>, <Article: 哈工大操作系统实验(二)系统调用>, <Article: 哈工大操作系统实验（一）系统引导>, <Article: python 源码阅读(一)listObject>, <Article: 一周一个Python语法糖：（三） 元类>, <Article: 一周一个Python语法糖：（二）迭代器与生成器>, <Article: 寒假碎碎念>, <Article: MySql学习（一）:安装mysql>, <Article: Linux小命令备忘录（不定时更新）>, <Article: 一周一个Python语法糖：（一）装饰器>]>

```


 
 






