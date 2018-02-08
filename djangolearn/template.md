

```
{{name}}
//name代表一个变量
需要用一个字典来给"name"赋值,如:

>>> from django import template
>>> t = template.Template('My name is {{ name }}.')
>>> c = template.Context({'name': 'Nige'})
>>> print (t.render(c))
My name is Nige.
```

##{% %}
一个模板标签,代表告诉模板系统该做什么,相当于 你要在这段html代码中嵌入自己的代码


如:

```
{% if   something  %}
dosomething
{% else %}
dosomething

{% endif %}
```

##过滤器:
类似于*nix系统下的管道('|')
将前一个输出变后一个输入 过滤后输出:

```
{{ ship_date|date:"F j, Y" }}
```
将ship_date时间 按照规定格式输出





###1

需要一个模板需要渲染多次的时候:

```
# Bad
for name in ('John', 'Julie', 'Pat'):
    t = Template('Hello, {{ name }}')
    print (t.render(Context({'name': name})))

# Good
t = Template('Hello, {{ name }}')
for name in ('John', 'Julie', 'Pat'):
    print (t.render(Context({'name': name})))

```

###上下文变量

当一次需要传入多个变量进行模板渲染的时候:

 * 一个方法可以将多个变量放到同一个字典中:key为变量名,value为渲染的变量的值
 * 另一个方法,就是直接把需要渲染的变量部分抽象成一个类,,类的属性与需要渲染的属性名一致.
 
 
 方法一:
 
 ```
 >>> from django.template import Template, Context
>>> person = {'name': 'Sally', 'age': '43'}
>>> t = Template('{{ person.name }} is {{ person.age }} years old.')
>>> c = Context({'person': person})
>>> t.render(c)
'Sally is 43 years old.'
 ```
 
 方法二:
 
 ```
 >>> from django.template import Template, Context
>>> class Person(object):
...     def __init__(self, first_name, last_name):
...         self.first_name, self.last_name = first_name, last_name
>>> t = Template('Hello, {{ person.first_name }} {{ person.last_name }}.')
>>> c = Context({'person': Person('John', 'Smith')})
>>> t.render(c)
'Hello, John Smith.'
 ```
 
 列表值渲染:
 
 ```
 >>> from django.template import Template, Context
>>> t = Template('Item 2 is {{ items.2 }}.')
>>> c = Context({'items': ['apples', 'bananas', 'carrots']})
>>> t.render(c)
'Item 2 is carrots.'
 ```
 
 
 
 
 
###django模板标签:

 
* if 

```
{% if today_is_weekend %}
    <p>Welcome to the weekend!</p>
{% endif %}
```

* if/else

```
{% if today_is_weekend %}
    <p>Welcome to the weekend!</p>
{% else %}
    <p>Get back to work.</p>
{% endif %}
```

* if/elif/elif/else/endif

```
{% if athlete_list %}
    <p>Number of athletes: {{ athlete_list|length }}</p>
{% elif athlete_in_locker_room_list %}
    <p>Athletes should be out of the locker room soon!</p>
{% elif ...
...
{% else %}
    <p>No athletes.</p>
{% endif %}
```

* if 表达式语句中采用逻辑关系:

```
{% if athlete_list and coach_list or cheerleader_list %}
```

在代码中相当于:

```
if (athlete_list and coach_list) or cheerleader_list

```

* for语句:

```
<ul>
    {% for athlete in athlete_list %}
    <li>{{ athlete.name }}</li>
    {% endfor %}
</ul>
```

也可以嵌套for

当你的list为一个二元组的是时候,可以这样:

```
{% for x, y in points %}
    <p>There is a point at {{ x }},{{ y }}</p>
{% endfor %}
```

for 的循环体为一个字典的时候:

```
{% for key, value in data.items %}
    {{ key }}: {{ value }}
{% endfor %}
```
* 注释:

```
This is a {# this is not
a comment #}
test.
```

多行注释:

```
{% comment %}
This is a
multi-line comment.
{% endcomment %}
```


