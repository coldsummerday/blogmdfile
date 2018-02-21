
##Func()表达式:
Func() 表达式是所有表达式的基础类型，包括数据库函数如 COALESCE 和 LOWER, 或者 SUM聚合.用下面方式可以直接使用:

```python
from django.db.models import Func, F

queryset.annotate(field_lower=Func(F('field'), function='LOWER'))

```



##Func ApI
class Func(\*expressions, \*\*extra)
* function , 描述生成的函数的类属性,函数即将被插入模板中的函数占位符.默认无(函数为sql自带函数)
* template ,类属性,作为格式化字符串,生成函数的sql,默认为:
**'%s (function) s(%(expressions)s)'**
* arg_joiner 类属性,表示用于连接表达式列表的字符,默认为', ';



