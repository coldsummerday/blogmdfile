
新建一个表:

```
from django.db import models

# Create your models here.

class person(models.Model):
    first_name = models.CharField(max_length=30)
    last_name = models.CharField(max_length=30)
```

以上代码会在数据库中构建一个person表:
结构如下:

```
CREATE TABLE appname_person (
    "id" serial NOT NULL PRIMARY KEY,
    "first_name" varchar(30) NOT NULL,
    "last_name" varchar(30) NOT NULL
);
```

在填写后:需要在setting.py中添加你的app:

```
INSTALLED_APPS = [
    #...
    'myapp',
    #...
]
```

然后运行:

```
python manage.py migrate
python manage.py makemigrations
```

完成从model到数据库表的创立

外键的创立:

```
from django.db import models



##创建一个Musician表,方便外键联系
class Musician(models.Model):
    first_name = models.CharField(max_length=50)
    last_name = models.CharField(max_length=50)
    instrument = models.CharField(max_length=100)

class Album(models.Model):
##外键创建API,传入参数为引用的表,级联删除
    artist = models.ForeignKey(Musician, on_delete=models.CASCADE)
    name = models.CharField(max_length=100)
    ##日期字段
    release_date = models.DateField()
    #Int类型字段
    num_stars = models.IntegerField()
```


Field options:

Charfield参数:

* max_length varchar的最大长度
* null  是否为Null, 默认flase
* blank 是否允许为空,墨粉flase
* choices 选择项:

选择项实例:

```
from django.db import models

class Person(models.Model):
    SHIRT_SIZES = (
        ('S', 'Small'),
        ('M', 'Medium'),
        ('L', 'Large'),
    )
    name = models.CharField(max_length=60)
    shirt_size = models.CharField(max_length=1, choices=SHIRT_SIZES)
```

```
>>> p = Person(name="Fred Flintstone", shirt_size="L")
>>> p.save()
>>> p.shirt_size
'L'
>>> p.get_shirt_size_display()
'Large'
```

* default 默认值
* help_text 
* primary_key 是否为主键 (True or False)
* unique  是否唯一值


```
first_name = models.CharField("person's first name", max_length=30)


在数据库中,存储的列名是属性(下划线替换成空格)
```

一对一与多对多:

```
sites = models.ManyToManyField(Site, verbose_name="list of sites")
place = models.OneToOneField(
    Place,
    on_delete=models.CASCADE,
    verbose_name="related place",
)
```


多对一的关系,使用$django.db.models.Foreignkey$
外键来声明一个一对多关系

```
from django.db import models

class Manufacturer(models.Model):
    # ...
    pass

class Car(models.Model):
    manufacturer = models.ForeignKey(Manufacturer, on_delete=models.CASCADE)
    # ...
```

多对多关系:$ManyToManyField $
如果一个披萨有多个配料,那么,配料与披萨之间属于一个多对多关系代码:

```
from django.db import models

class Topping(models.Model):
    # ...
    pass

class Pizza(models.Model):
    # ...
    toppings = models.ManyToManyField(Topping)
```

在多对多关系中,如果我们只用两个属性值来描述两张表之间的关系,有时候是远远不够的.
比如: 
 * 音乐家 与 乐团之间属于多对多关系,可以根据他们的名字形成多对多关系
但是,我们需要更加详细的记录,它们之间的细节,比如假如 加入的时间,邀请加入的理由等

此时,我们可以采用ManyToManyField类的through属性值来声明中间联系表:

```
from django.db import models

class Person(models.Model):
    name = models.CharField(max_length=128)

    def __str__(self):
        return self.name

class Group(models.Model):
    name = models.CharField(max_length=128)
    members = models.ManyToManyField(Person, through='Membership')

    def __str__(self):
        return self.name

class Membership(models.Model):
    person = models.ForeignKey(Person, on_delete=models.CASCADE)
    group = models.ForeignKey(Group, on_delete=models.CASCADE)
    date_joined = models.DateField()
    invite_reason = models.CharField(max_length=64)
```

注意:
中间模型只包含一个源模型的外键:例子 中为:group

ManyToManyField.through_fields作为关系的外键。如果您有多个外键，并且没有指定through_fields，则会引发验证错误。类似的限制适用于目标模型的外键（在我们的例子中这将是Person）



Meta options:元类(元数据)
内嵌的元类,用来描述metadata

```
from django.db import models

class Ox(models.Model):
    horn_length = models.IntegerField()

    class Meta:
        ordering = ["horn_length"]
        verbose_name_plural = "oxen"
```

注意:元数据不是字段,只是用来描述类(并不会储存到表的,只是表的附带信息)

##Model attributes
* objects  :该属性向django 提供数据库查询接口,用于 从数据库中检索实例.

##Model methods


在model中添加自定义方法:

```
from django.db import models

class Person(models.Model):
    first_name = models.CharField(max_length=50)
    last_name = models.CharField(max_length=50)
    birth_date = models.DateField()

    def baby_boomer_status(self):
        #"Returns the person's baby-boomer status."
        import datetime
        if self.birth_date < datetime.date(1945, 8, 1):
            return "Pre-boomer"
        elif self.birth_date < datetime.date(1965, 1, 1):
            return "Baby boomer"
        else:
            return "Post-boomer"

    @property
    def full_name(self):
        #"Returns the person's full name."
        return '%s %s' % (self.first_name, self.last_name)
```

自带方法:

```
__str__()

get_absolute_url()
```

改写方法:比如修改自带的save方法():


```
from django.db import models

class Blog(models.Model):
    name = models.CharField(max_length=100)
    tagline = models.TextField()

    def save(self, *args, **kwargs):
        do_something()
        super().save(*args, **kwargs)  # Call the "real" save() method.
        do_something_else()
```

请注意，在使用QuerySet批量删除对象或级联删除的结果时，不必调用对象的delete（）方法。 为了确保自定义的删除逻辑得到执行，可以使用pre_delete和/或post_delete信号。


###抽象基类:

当多个表需要有部分共同的属性时候,可以采用抽象基类:
方法:在内嵌元类中定义abstract属性为True

```
from django.db import models

class CommonInfo(models.Model):
    name = models.CharField(max_length=100)
    age = models.PositiveIntegerField()

    class Meta:
        abstract = True

class Student(CommonInfo):
    home_group = models.CharField(max_length=5)
```


##Proxy models(代理模型)

如果你想为一个已经定义Model新方法:使用代理.
这是代理模型继承的用途：为原始模型创建一个代理。您可以创建，删除和更新代理模型的实例，并将所有数据保存为您使用原始（非代理）模型。不同之处在于，您可以在代理中更改默认模型顺序或默认管理器之类的内容，而无需更改原始内容。 

代理模型被声明为正常模型。通过将Meta类的proxy属性设置为True，可以告诉Django它是一个代理模型。

例如，假设您想要将一个方法添加到Person模型中。你可以这样做：:

```
from django.db import models

class Person(models.Model):
    first_name = models.CharField(max_length=30)
    last_name = models.CharField(max_length=30)

class MyPerson(Person):
    class Meta:
        proxy = True

    def do_something(self):
        # ...
        pass
```



