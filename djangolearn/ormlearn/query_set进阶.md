

#Model设计:

```python
from django.db import models
from django.utils.encoding import python_2_unicode_compatible
 
 
@python_2_unicode_compatible
class Author(models.Model):
    name = models.CharField(max_length=50)
    qq = models.CharField(max_length=10)
    addr = models.TextField()
    email = models.EmailField()
 
    def __str__(self):
        return self.name
 
 
@python_2_unicode_compatible
class Article(models.Model):
    title = models.CharField(max_length=50)
    author = models.ForeignKey(Author,on_delete=models.CASCADE)
    content = models.TextField()
    score = models.IntegerField()  # 文章的打分
    tags = models.ManyToManyField('Tag')
 
    def __str__(self):
        return self.title
 
 
@python_2_unicode_compatible
class Tag(models.Model):
    name = models.CharField(max_length=50)
 
    def __str__(self):
        return self.name
```



#ORM操作:

##(1)values_list的形式获取某些列:

* 获取作者的name跟qq

```python
In [7]: authors = Author.objects.values_list('name', 'qq')

In [8]: authors
Out[8]: <QuerySet [('WeizhongTu', '801501875'), ('twz915', '235220597'), ('dachui', '713957371'), ('zhe', '443867715'), ('zhen', '084356527')]>
```

指定一个字段,使用flat=True参数

```python
In [10]: Author.objects.values_list('name', flat=True)
Out[10]: <QuerySet ['WeizhongTu', 'twz915', 'dachui', 'zhe', 'zhen']>
```

##(2)values获取字典形式的结果:

* 获取作者的name和qq:

```python
In [12]: Author.objects.values('name','qq')
Out[12]: <QuerySet [{'name': 'WeizhongTu', 'qq': '801501875'}, {'name': 'twz915', 'qq': '235220597'}, {'name': 'dachui', 'qq': '713957371'}, {'name': 'zhe', 'qq': '443867715'}, {'name': 'zhen', 'qq': '084356527'}]>

```

注意: django使用的orm策略是一个**lazy evaluation**策略:通俗地讲 ,就是用的时候才真正去数据库查找

比如我们查找的返回都是一个queryset对象,等需要去查找queryset中的某一行的结果的时候,才会去数据库中查找.

##(3)extra实行别名

```python
In [17]: list(Tag.objects.all().extra(select={'tag_name':'name'}))
Out[17]: [<Tag: Django>, <Tag: Python>, <Tag: HTML>]
```

实现了将tag_name转化为name


##(4)annotate实现聚合,计数,求和,平均数

* 计算每个作者的文章数:

```python
In [26]: Article.objects.values('author_id').annotate(count=Count('author'))
Out[26]: <QuerySet [{'author_id': 1, 'count': 40}, {'author_id': 5, 'count': 20}]>

```

* 跨表查询的时候:
比如我们要查找每个作者名字跟文章数的时候:

```python
In [7]: Article.objects.all().values('author__name').annotate(count=Count('author'))
Out[7]: (0.000) SELECT "models_author"."name", COUNT("models_article"."author_id") AS "count" FROM "models_article" INNER JOIN "models_author" ON ("models_article"."author_id" = "models_author"."id") GROUP BY "models_author"."name" LIMIT 21; args=()
<QuerySet [{'author__name': 'WeizhongTu', 'count': 40}, {'author__name': 'zhen', 'count': 20}]>
```

它使用的sql语句将一个article **inner join**连接到 author表id相同的时候;

* 求和与平均值
求一个作者的所有文章的平均得分(score)

其django实现思路是:先用value函数将(author_id)一样的做一个聚合(group by),然后再在该聚合的基础上求avg

```python
In [15]: Article.objects.values('author_id').annotate(avg_score=Avg('score')).values('author_id','avg_score')
Out[15]: (0.000) SELECT "models_article"."author_id", AVG("models_article"."score") AS "avg_score" FROM "models_article" GROUP BY "models_article"."author_id" LIMIT 21; args=()
<QuerySet [{'author_id': 1, 'avg_score': 85.4}, {'author_id': 5, 'avg_score': 88.15}]>
```

* 求和

```python
In [14]: Article.objects.values('author_id').annotate(sum_score=Sum('score')).values('author_id','sum_score')
Out[14]: (0.000) SELECT "models_article"."author_id", SUM("models_article"."score") AS "sum_score" FROM "models_article" GROUP BY "models_article"."author_id" LIMIT 21; args=()
<QuerySet [{'author_id': 1, 'sum_score': 3416}, {'author_id': 5, 'sum_score': 1763}]>
```



##(5) 用select_related优化一对一,多对一查询


当我们需要查找是某篇文章的作者名字的时候:

```python
In [20]: Article.objects.all()[0].author.name
(0.000) SELECT "models_article"."id", "models_article"."title", "models_article"."author_id", "models_article"."content", "models_article"."score" FROM "models_article" LIMIT 1; args=()
(0.000) SELECT "models_author"."id", "models_author"."name", "models_author"."qq", "models_author"."addr", "models_author"."email" FROM "models_author" WHERE "models_author"."id" = 1; args=(1,)
Out[20]: 'WeizhongTu'

```

我们看到生成了两条查询语句:
先是查到了文章的author_id,再拿着id去查author_name..


我们为何不能把两个表的所有field拼接在一起呢,有请**select_related**!

```python
In [21]: articles = Article.objects.all().select_related('author')[:10]

In [22]: articles[0].author.name
(0.000) SELECT "models_article"."id", "models_article"."title", "models_article"."author_id", "models_article"."content", "models_article"."score", "models_author"."id", "models_author"."name", "models_author"."qq", "models_author"."addr", "models_author"."email" FROM "models_article" INNER JOIN "models_author" ON ("models_article"."author_id" = "models_author"."id") LIMIT 1; args=()
Out[22]: 'WeizhongTu'
```

一篇文章只能有一个作者,所以我们用了select_related  (多对一,多的model使用select_related)

注:select_related 是使用 SQL JOIN 一次性取出相关的内容,最多只能联系5张表格()


##(6)prefetch_related 优化一对多,多对多查询



prefetch_related 用于 一对多，多对多 的情况，这时 select_related 用不了，因为当前一条有好几条与之相关的内容。

**prefetch_related是通过再执行一条额外的SQL语句，然后用 Python 把两次SQL查询的内容关联（joining)到一起**

比如:查询文章的同时,查询文章对应的标签:(文章与标签是多对多关系)

```python
In [27]: articles = Article.objects.all().prefetch_related('tags')[:10]

In [28]: articles
Out[28]: (0.000) SELECT "models_article"."id", "models_article"."title", "models_article"."author_id", "models_article"."content", "models_article"."score" FROM "models_article" LIMIT 10; args=()
(0.000) SELECT ("models_article_tags"."article_id") AS "_prefetch_related_val_article_id", "models_tag"."id", "models_tag"."name" FROM "models_tag" INNER JOIN "models_article_tags" ON ("models_tag"."id" = "models_article_tags"."tag_id") WHERE "models_article_tags"."article_id" IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10); args=(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
<QuerySet [<Article: Django 教程_1>, <Article: Django 教程_2>, <Article: Django 教程_3>, <Article: Django 教程_4>, <Article: Django 教程_5>, <Article: Django 教程_6>, <Article: Django 教程_7>, <Article: Django 教程_8>, <Article: Django 教程_9>, <Article: Django 教程_10>]>
```

第二条sql语句将属于每一个文章的tag查询出来



##(7)defer排除不需要的fields

在复杂的情况下，表中可能有些字段内容非常多，取出来转化成 Python 对象会占用大量的资源。

比如在list中,并不需要文章内容:

```python
In [33]: Article.objects.all().defer('content')
Out[33]: (0.000) SELECT "models_article"."id", "models_article"."title", "models_article"."author_id", "models_article"."score" FROM "models_article" LIMIT 21; args=()
<QuerySet [<Article: Django 教程_1>, <Article: Django 教程_2>, <Article: Django 教程_3>, <Article: Django 教程_4>, <Article: Django 教程_5>, <Article: Django 教程_6>, <Article: Django 教程_7>, <Article: Django 教程_8>, <Article: Django 教程_9>, <Article: Django 教程_10>, <Article: Django 教程_11>, <Article: Django 教程_12>, <Article: Django 教程_13>, <Article: Django 教程_14>, <Article: Django 教程_15>, <Article: Django 教程_16>, <Article: Django 教程_17>, <Article: Django 教程_18>, <Article: Django 教程_19>, <Article: Django 教程_20>, '...(remaining elements truncated)...']>

In [34]: Article.objects.all()
Out[34]: (0.000) SELECT "models_article"."id", "models_article"."title", "models_article"."author_id", "models_article"."content", "models_article"."score" FROM "models_article" LIMIT 21; args=()
<QuerySet [<Article: Django 教程_1>, <Article: Django 教程_2>, <Article: Django 教程_3>, <Article: Django 教程_4>, <Article: Django 教程_5>, <Article: Django 教程_6>, <Article: Django 教程_7>, <Article: Django 教程_8>, <Article: Django 教程_9>, <Article: Django 教程_10>, <Article: Django 教程_11>, <Article: Django 教程_12>, <Article: Django 教程_13>, <Article: Django 教程_14>, <Article: Django 教程_15>, <Article: Django 教程_16>, <Article: Django 教程_17>, <Article: Django 教程_18>, <Article: Django 教程_19>, <Article: Django 教程_20>, '...(remaining elements truncated)...']>


```

##(8)only 仅选择需要的字段:

```python
In [35]: Author.objects.all().only('name')
Out[35]: (0.000) SELECT "models_author"."id", "models_author"."name" FROM "models_author" LIMIT 21; args=()
<QuerySet [<Author: WeizhongTu>, <Author: twz915>, <Author: dachui>, <Author: zhe>, <Author: zhen>]>
```

注:queryset查询中不允许缺少自增主键id














