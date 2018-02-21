##在查询集上生成聚合:

此方法适用于整张表的统计,适用于统计统一表格的field

```python
>>> from django.db.models import Avg
>>> Book.objects.aggregate(Avg('price'))
{'price__avg': 34.35}
```

当指定键的时候:

```python
>>> Book.objects.aggregate(average_price=Avg('price'))
{'average_price': 34.35}
```

* 不止一个聚合的时候:

```python
>>> from django.db.models import Avg, Max, Min
>>> Book.objects.aggregate(Avg('price'), Max('price'), Min('price'))
{'price__avg': 34.35, 'price__max': Decimal('81.20'), 'price__min': Decimal('12.99')}
```


##为查询集的每一项生成聚合

比如，如果你在检索一列图书，你可能想知道每一本书有多少作者参与。每本书和作者是多对多的关系。我们想要汇总QuerySet.中每本书里的这种关系

逐个对象的汇总结果可以由annotate()子句生成。当annotate()子句被指定之后，QuerySet中的每个对象都会被注上特定的值。


比如查询每个tag有多少篇文章(tag与Article属于多对多关系)

```python
In [6]: q = Tag.objects.annotate(tag_count=Count('article'))

In [7]: q[0].tag_count
(0.001) SELECT "blog_tag"."id", "blog_tag"."name", COUNT("blog_article_tag"."article_id") AS "tag_count" FROM "blog_tag" LEFT OUTER JOIN "blog_article_tag" ON ("blog_tag"."id" = "blog_article_tag"."tag_id") GROUP BY "blog_tag"."id", "blog_tag"."name" LIMIT 1; args=()
Out[7]: 2

In [8]: q[3].tag_count
(0.000) SELECT "blog_tag"."id", "blog_tag"."name", COUNT("blog_article_tag"."article_id") AS "tag_count" FROM "blog_tag" LEFT OUTER JOIN "blog_article_tag" ON ("blog_tag"."id" = "blog_article_tag"."tag_id") GROUP BY "blog_tag"."id", "blog_tag"."name" LIMIT 1 OFFSET 3; args=()
Out[8]: 3
```


##连接与聚合:

比如想查每个商店提供的图书的价格范围:
需要连接商店与图书两个表


用__双下划线表示关联关系

```python
>>> from django.db.models import Max, Min
>>> Store.objects.annotate(min_price=Min('books__price'), max_price=Max('books__price'))
```

这段代码告诉 Django 获取书店模型，并连接(通过多对多关系)图书模型，然后对每本书的价格进行聚合，得出最小值和最大值。

