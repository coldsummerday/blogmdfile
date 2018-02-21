
##一、文件组织
django orm部分代码位于:**django.db**,其源代码组织形式为:

Django.db

> ---backends 各种数据库后端的实现
>
>>----dummy哑后端,定义空方法
>>
>>----mysql 连接mysql的实现
>>
>>----oracle oracle数据库的实现

>---models,backends 中各种数据库都基于此实现
>>----fields 数据库表字段的实现
>>
>>----sql 语句,记录sql语句的各种选项,where等,左后生成sql语句,连接数据库得到结果.
>>
>>----aggregates.py 聚合相关
>>----base.py 定义 Model 类
>>----constants.py 一些常量
>>----deletion.py 数据库表项的删除实现
>>----expressions.py 表达式类, where 会出现表达式
>>----manager.py ORM 的管理器
>>----options.py 数据库表选项, 譬如主键等
>>----query.py 数据库查询集类
>>----query_utils.py 小工具
>>----related.py 与`表关联`相关
>>----signals.py 信号相关如`post-save`等信号函数
>>----__init__.py


##二、Model.Object(manager)
所有的model增删改都要model.object管理类去实现,其是一个代理模式.



manager 类,,每个model manager实例创建时候创建一个计数器用来,跟踪顺序..

我们需要把预设值的方法 比如get,filter,update 等,进行元类操作(把方法跟属性copy到是用户自定义的model类中),使用 basemanager类中的方法:

db.models.manager.py/ class BaseManager

```python
      ##从queryset_clss 类中复制方法到cls中
    @classmethod
    def _get_queryset_methods(cls, queryset_class):
        #赋值类的方法,并将方法的name,doc复制
        def create_method(name, method):
            def manager_method(self, *args, **kwargs):
                return getattr(self.get_queryset(), name)(*args, **kwargs)
            manager_method.__name__ = method.__name__
            manager_method.__doc__ = method.__doc__
            return manager_method

        new_methods = {}
        ##inspect.getmembers 用于自省,即知道queryset_class类中有哪些方法
        ##queryset_only标明queryset_only的方法不复制
        for name, method in inspect.getmembers(queryset_class, predicate=inspect.isfunction):
            # Only copy missing methods.
            if hasattr(cls, name):
                continue
            # Only copy public methods or methods with the attribute `queryset_only=False`.
            queryset_only = getattr(method, 'queryset_only', None)
            if queryset_only or (queryset_only is None and name.startswith('_')):
                continue
            # Copy the method onto the manager.
            new_methods[name] = create_method(name, method)
        return new_methods


    ##从query中复制方法到cls,即用户设定的model类中
    @classmethod
    def from_queryset(cls, queryset_class, class_name=None):
        if class_name is None:
            class_name = '%sFrom%s' % (cls.__name__, queryset_class.__name__)
        return type(class_name, (cls,), {
            '_queryset_class': queryset_class,
            **cls._get_queryset_methods(queryset_class),
        })

    def contribute_to_class(self, model, name):
        self.name = self.name or name
        self.model = model

        setattr(model, name, ManagerDescriptor(self))

        model._meta.add_manager(self)

    def _set_creation_counter(self):
        """
        Set the creation counter value for this instance and increment the
        class-level copy.

        实例创建计数器
        """
        self.creation_counter = BaseManager.creation_counter
        BaseManager.creation_counter += 1
```


由此我们知道,manager操作的各种方法的预定义来自于 query set,我们要去query_set中探寻秘密.


db.models.query.py/ class QuerySet

```python

    #从queryset转化为manager
    def as_manager(cls):
        # Address the circular dependency between `Queryset` and `Manager`.
        from django.db.models.manager import Manager
        manager = Manager.from_queryset(cls)()
        manager._built_with_as_manager = True
        return manager
    as_manager.queryset_only = True
    as_manager = classmethod(as_manager)
    
    
```


由于query是一个可迭代对象,所以内部必须实现__iter__,__getitem__方法:

```python
    def __iter__(self):
        """
queryset迭代器协议使用三个嵌套迭代器。
默认情况下:
1。sql.compiler.execute_sql()
-在时间上返回100行(常量. get_iterator_chunk_size)
使用cursor.fetchmany()。这部分负责。
做一些列掩蔽，并以块返回行。
2。sql.compiler.results_iter()
-每次返回一行。此时，行仍然是公正的。
元组。在某些情况下，返回值被转换为。
在此位置的Python值。
3所示。self.iterator()
-负责将行转换为模型对象。
        """
        self._fetch_all()
        return iter(self._result_cache)
        
        
```

```python
    def __getitem__(self, k):
        """Retrieve an item or slice from the set of results."""
        #k如果不是int或者一个slice的话,返回错误,无法获取正确的值
        if not isinstance(k, (int, slice)):
            raise TypeError
        assert ((not isinstance(k, slice) and (k >= 0)) or
                (isinstance(k, slice) and (k.start is None or k.start >= 0) and
                 (k.stop is None or k.stop >= 0))), \
            "Negative indexing is not supported."


        #如果缓存中有数据,则从缓存中提取数据
        if self._result_cache is not None:
            return self._result_cache[k]


        #缓存没数据,且k为切片
        if isinstance(k, slice):
            #获取到query_set的copy副本
            qs = self._chain()
            if k.start is not None:
                start = int(k.start)
            else:
                start = None
            if k.stop is not None:
                stop = int(k.stop)
            else:
                stop = None
            ##从切片中提取数据,一切操作都在models.sql中定义真正的sql语句提取数据
            qs.query.set_limits(start, stop)
            return list(qs)[::k.step] if k.step else qs
        #如果K是一个int值,提取出相应位置
        qs = self._chain()
        qs.query.set_limits(k, k + 1)
        qs._fetch_all()
        return qs._result_cache[0]

```


querySet中的database sql操作:

* count

```python
    def count(self):
        """
        执行一个SELECT COUNT()并返回记录的数量作为一个。
整数。

        如果QuerySet已经被完全缓存，则返回其长度。
缓存的结果集以避免多个SELECT COUNT(*)调用。
        """
        if self._result_cache is not None:
            return len(self._result_cache)

        return self.query.get_count(using=self.db)
```

* get

```python
    def get(self, *args, **kwargs):
        """
       给定关键字参数执行查询并返回匹配给定的单个对象。
        """

        #先通过fiter筛选得到一个quertset clone副本,
        clone = self.filter(*args, **kwargs)
        if self.query.can_filter() and not self.query.distinct_fields:
            clone = clone.order_by()
        num = len(clone)
        ##因为get只能得到一个数据,如果得到,则是第一个
        if num == 1:
            return clone._result_cache[0]
        #如果不是,则返回错误,不能返回多行sql数据
        if not num:
            raise self.model.DoesNotExist(
                "%s matching query does not exist." %
                self.model._meta.object_name
            )
        raise self.model.MultipleObjectsReturned(
            "get() returned more than one %s -- it returned %s!" %
            (self.model._meta.object_name, num)
        )

```

* create

```python
    def create(self, **kwargs):
        """
        创建一个用户定义model对象,并保存到db中
        """
        obj = self.model(**kwargs)
        self._for_write = True
        obj.save(force_insert=True, using=self.db)
        return obj
```

* bulk_create

创建多个对象的时候,需要使用**bulk_create**

```python
    def _populate_pk_values(self, objs):
        #给未设置主键自增id的 model设置pk(primary key)
        for obj in objs:
            if obj.pk is None:
                obj.pk = obj._meta.pk.get_pk_value_on_save(obj)

    def bulk_create(self, objs, batch_size=None):
        """
        Insert each of the instances into the database. Do *not* call
        save() on each of the instances, do not send any pre/post_save
        signals, and do not set the primary key attribute if it is an
        autoincrement field (except if features.can_return_ids_from_bulk_insert=True).
        Multi-table models are not supported.
        """
        # When you bulk insert you don't get the primary keys back (if it's an
        # autoincrement, except if can_return_ids_from_bulk_insert=True), so
        # you can't insert into the child tables which references this. There
        # are two workarounds:
        # 1) This could be implemented if you didn't have an autoincrement pk
        # 2) You could do it by doing O(n) normal inserts into the parent
        #    tables to get the primary keys back and then doing a single bulk
        #    insert into the childmost table.
        # We currently set the primary keys on the objects when using
        # PostgreSQL via the RETURNING ID clause. It should be possible for
        # Oracle as well, but the semantics for extracting the primary keys is
        # trickier so it's not done yet.
        assert batch_size is None or batch_size > 0
        #检查父类是否共享相同的concrete具体模型
        for parent in self.model._meta.get_parent_list():
            if parent._meta.concrete_model is not self.model._meta.concrete_model:
                raise ValueError("Can't bulk create a multi-table inherited model")
        if not objs:
            return objs
        self._for_write = True
        #获取db的连接
        connection = connections[self.db]
        #获得_meta
        fields = self.model._meta.concrete_fields
        objs = list(objs)
        #给obj加主键
        self._populate_pk_values(objs)
        with transaction.atomic(using=self.db, savepoint=False):
            objs_with_pk, objs_without_pk = partition(lambda o: o.pk is None, objs)
            if objs_with_pk:
                #主要的_batched_insert插入方法
                self._batched_insert(objs_with_pk, fields, batch_size)
            if objs_without_pk:
                fields = [f for f in fields if not isinstance(f, AutoField)]
                ids = self._batched_insert(objs_without_pk, fields, batch_size)
                if connection.features.can_return_ids_from_bulk_insert:
                    assert len(ids) == len(objs_without_pk)
                for obj_without_pk, pk in zip(objs_without_pk, ids):
                    obj_without_pk.pk = pk
                    obj_without_pk._state.adding = False
                    obj_without_pk._state.db = self.db

        return objs

```

* get_or_create

```python
        def get_or_create(self, defaults=None, **kwargs):
        """
        获取一个model,必要时候就创建一个Model并保存
        """

        ###提取出用户传入合法字段(避免传入 一些用户Model 没有的字段)
        lookup, params = self._extract_model_params(defaults, **kwargs)
        # The get() needs to be targeted at the write database in order
        # to avoid potential transaction consistency problems.
        self._for_write = True
        try:
            return self.get(**lookup), False
        except self.model.DoesNotExist:
            return self._create_object_from_params(lookup, params)

    def update_or_create(self, defaults=None, **kwargs):
        """
        Look up an object with the given kwargs, updating one with defaults
        if it exists, otherwise create a new one.
        Return a tuple (object, created), where created is a boolean
        specifying whether an object was created.
        """
        defaults = defaults or {}
        lookup, params = self._extract_model_params(defaults, **kwargs)
        self._for_write = True
        with transaction.atomic(using=self.db):
            try:
                obj = self.select_for_update().get(**lookup)
            except self.model.DoesNotExist:
                obj, created = self._create_object_from_params(lookup, params)
                if created:
                    return obj, created
            for k, v in defaults.items():
                setattr(obj, k, v() if callable(v) else v)
            obj.save(using=self.db)
        return obj, False

    def _create_object_from_params(self, lookup, params):
        """
        Try to create an object using passed params. Used by get_or_create()
        and update_or_create().
        """
        try:
            with transaction.atomic(using=self.db):
                params = {k: v() if callable(v) else v for k, v in params.items()}
                obj = self.create(**params)
            return obj, True
        except IntegrityError as e:
            try:
                return self.get(**lookup), False
            except self.model.DoesNotExist:
                pass
            raise e

    def _extract_model_params(self, defaults, **kwargs):
        """
        Prepare `lookup` (kwargs that are valid model attributes), `params`
        (for creating a model instance) based on given kwargs; for use by
        get_or_create() and update_or_create().
        """
        defaults = defaults or {}
        #copy model._meta.fields中的字段
        lookup = kwargs.copy()
        for f in self.model._meta.fields:
            if f.attname in lookup:
                lookup[f.name] = lookup.pop(f.attname)
        params = {k: v for k, v in kwargs.items() if LOOKUP_SEP not in k}
        params.update(defaults)
        property_names = self.model._meta._property_names
        invalid_params = []

        #获得正常字段,排除非法字段
        for param in params:
            try:
                self.model._meta.get_field(param)
            except exceptions.FieldDoesNotExist:
                # It's okay to use a model's property if it has a setter.
                if not (param in property_names and getattr(self.model, param).fset):
                    invalid_params.append(param)
        if invalid_params:
            raise exceptions.FieldError(
                "Invalid field name(s) for model %s: '%s'." % (
                    self.model._meta.object_name,
                    "', '".join(sorted(invalid_params)),
                ))
        return lookup, params
```

* 顺序操作

```python
   def _earliest_or_latest(self, *fields, field_name=None):
        """
        Return the latest object, according to the model's
        'get_latest_by' option or optional given field_name.
        """
        if fields and field_name is not None:
            raise ValueError('Cannot use both positional arguments and the field_name keyword argument.')

        if field_name is not None:
            warnings.warn(
                'The field_name keyword argument to earliest() and latest() '
                'is deprecated in favor of passing positional arguments.',
                RemovedInDjango30Warning,
            )

            ##当field_name存在的时候,根据field_name排序
            order_by = (field_name,)
        elif fields:
            ##否则根据fields排序
            order_by = fields
        else:
            ##两个都没有的话就看model._meta中有无get_latest_by
            order_by = getattr(self.model._meta, 'get_latest_by')
            if order_by and not isinstance(order_by, (tuple, list)):
                order_by = (order_by,)
        if order_by is None:
            raise ValueError(
                "earliest() and latest() require either fields as positional "
                "arguments or 'get_latest_by' in the model's Meta."
            )

        assert self.query.can_filter(), \
            "Cannot change a query once a slice has been taken."
        obj = self._chain()
        obj.query.set_limits(high=1)
        obj.query.clear_ordering(force_empty=True)
        #重新排序
        obj.query.add_ordering(*order_by)
        return obj.get()


    #拿到第一个
    def earliest(self, *fields, field_name=None):
        return self._earliest_or_latest(*fields, field_name=field_name)

    #拿到最后一个
    def latest(self, *fields, field_name=None):
        return self.reverse()._earliest_or_latest(*fields, field_name=field_name)

    def first(self):
        """Return the first object of a query or None if no match is found."""
        for obj in (self if self.ordered else self.order_by('pk'))[:1]:
            return obj

    def last(self):
        """Return the last object of a query or None if no match is found."""
        for obj in (self.reverse() if self.ordered else self.order_by('-pk'))[:1]:
            return obj

```


```python
    def in_bulk(self, id_list=None, *, field_name='pk'):
        """
        Return a dictionary mapping each of the given IDs to the object with
        that ID. If `id_list` isn't provided, evaluate the entire QuerySet.
        """

        #如果给定ids,则返回id对应的model 字典形式
        assert self.query.can_filter(), \
            "Cannot use 'limit' or 'offset' with in_bulk"
        if field_name != 'pk' and not self.model._meta.get_field(field_name).unique:
            raise ValueError("in_bulk()'s field_name must be a unique field but %r isn't." % field_name)
        if id_list is not None:
            if not id_list:
                return {}
            filter_key = '{}__in'.format(field_name)
            batch_size = connections[self.db].features.max_query_params
            id_list = tuple(id_list)
            # If the database has a limit on the number of query parameters
            # (e.g. SQLite), retrieve objects in batches if necessary.
            if batch_size and batch_size < len(id_list):
                qs = ()
                for offset in range(0, len(id_list), batch_size):
                    batch = id_list[offset:offset + batch_size]
                    qs += tuple(self.filter(**{filter_key: batch}).order_by())
            else:
                #调用fiter方法,传入 **{field_name__in:id_list}的参数形成filter查询条件
                qs = self.filter(**{filter_key: id_list}).order_by()
        else:

            qs = self._chain()
        #查询结果在qs中,获取pk作为key,value是obj
        return {getattr(obj, field_name): obj for obj in qs}

```

* update

```python
    def update(self, **kwargs):
        """
        Update all elements in the current QuerySet, setting all the given
        fields to the appropriate values.
        """
        assert self.query.can_filter(), \
            "Cannot update a query once a slice has been taken."
        self._for_write = True

        #获取update的sql语句,并传入参数
        query = self.query.chain(sql.UpdateQuery)
        query.add_update_values(kwargs)
        # Clear any annotations so that they won't be present in subqueries.
        query._annotations = None

        ##更新sql
        with transaction.atomic(using=self.db, savepoint=False):
            rows = query.get_compiler(self.db).execute_sql(CURSOR)
        self._result_cache = None
        return rows
    update.alters_data = True

    def _update(self, values):
        """
        A version of update() that accepts field objects instead of field names.
        Used primarily for model saving and not intended for use by general
        code (it requires too much poking around at model internals to be
        useful at that level).
        另一种更新方式
        """
        assert self.query.can_filter(), \
            "Cannot update a query once a slice has been taken."
        query = self.query.chain(sql.UpdateQuery)
        query.add_update_fields(values)
        self._result_cache = None
        return query.get_compiler(self.db).execute_sql(CURSOR)
    _update.alters_data = True
    _update.queryset_only = False

```


* filter

```python
    def all(self):
        """
        Return a new QuerySet that is a copy of the current one. This allows a
        QuerySet to proxy for a model manager in some cases.
        """
        return self._chain()

    def filter(self, *args, **kwargs):
        """
        Return a new QuerySet instance with the args ANDed to the existing
        set.
        """
        return self._filter_or_exclude(False, *args, **kwargs)

    def exclude(self, *args, **kwargs):
        """
        Return a new QuerySet instance with NOT (args) ANDed to the existing
        set.
        """
        return self._filter_or_exclude(True, *args, **kwargs)

    def _filter_or_exclude(self, negate, *args, **kwargs):
        if args or kwargs:
            assert self.query.can_filter(), \
                "Cannot filter a query once a slice has been taken."

        clone = self._chain()
        if negate:
            clone.query.add_q(~Q(*args, **kwargs))
        else:
            clone.query.add_q(Q(*args, **kwargs))
        return clone

```

* related操作

```python
    def select_related(self, *fields):
        """
        Return a new QuerySet instance that will select related objects.

        If fields are specified, they must be ForeignKey fields and only those
        related objects are included in the selection.

        If select_related(None) is called, clear the list.
        """

        #有关联的表格操作

        if self._fields is not None:
            raise TypeError("Cannot call select_related() after .values() or .values_list()")

        #调用sql.query中的select_related进行操作
        obj = self._chain()
        if fields == (None,):
            obj.query.select_related = False
        elif fields:
            obj.query.add_select_related(fields)
        else:
            obj.query.select_related = True
        return obj

    #预处理related
    def prefetch_related(self, *lookups):
        """
        Return a new QuerySet instance that will prefetch the specified
        Many-To-One and Many-To-Many related objects when the QuerySet is
        evaluated.

        When prefetch_related() is called more than once, append to the list of
        prefetch lookups. If prefetch_related(None) is called, clear the list.
        """
        clone = self._chain()
        if lookups == (None,):
            clone._prefetch_related_lookups = ()
        else:
            for lookup in lookups:
                #如果lookup为PreFetch对象,则分割lookup,拼接到_prefetch_related_lookups上
                if isinstance(lookup, Prefetch):
                    lookup = lookup.prefetch_to
                    #LOOKUP_SEP = '__',用__分割
                lookup = lookup.split(LOOKUP_SEP, 1)[0]
                if lookup in self.query._filtered_relations:
                    raise ValueError('prefetch_related() is not supported with FilteredRelation.')
            clone._prefetch_related_lookups = clone._prefetch_related_lookups + lookups
        return clone

```

* 分组查询annotate:

```python
    def annotate(self, *args, **kwargs):
        """
        Return a query set in which the returned objects have been annotated
        with extra data or aggregations.
        """
        #检查非法参数
        self._validate_values_are_expressions(args + tuple(kwargs.values()), method_name='annotate')
        #保存order参数
        annotations = OrderedDict()  # To preserve ordering of args
        #将args跟**kwargs中的参数合并
        for arg in args:
            # The default_alias property may raise a TypeError.
            try:
                if arg.default_alias in kwargs:
                    raise ValueError("The named annotation '%s' conflicts with the "
                                     "default name for another annotation."
                                     % arg.default_alias)
            except TypeError:
                raise TypeError("Complex annotations require an alias")
            annotations[arg.default_alias] = arg
        annotations.update(kwargs)

        clone = self._chain()
        names = self._fields
        if names is None:
            #获取model中的fields值
            names = {f.name for f in self.model._meta.get_fields()}


        for alias, annotation in annotations.items():
            #分组查询中,查询返回字典中的key值不能为model中的field
            if alias in names:
                raise ValueError("The annotation '%s' conflicts with a field on "
                                 "the model." % alias)
            #调用sql.query中的add_filtered_relation与add_annotation方法进行操作annotate操作
            if isinstance(annotation, FilteredRelation):
                clone.query.add_filtered_relation(annotation, alias)
            else:
                clone.query.add_annotation(annotation, alias, is_summary=False)

        for alias, annotation in clone.query.annotations.items():
            if alias in annotations and annotation.contains_aggregate:
                if clone._fields is None:
                    clone.query.group_by = True
                else:
                    clone.query.set_group_by()
                break

        return clone

```

* order_by:

```python
    def order_by(self, *field_names):
        """Return a new QuerySet instance with the ordering changed."""
        assert self.query.can_filter(), \
            "Cannot reorder a query once a slice has been taken."
        obj = self._chain()
        #清除原来的排序顺序
        obj.query.clear_ordering(force_empty=False)
        #根据传入的field_name进行排序
        obj.query.add_ordering(*field_names)
        return obj
```

* aggregate 聚合查询:

```python
    #聚合查询
    def aggregate(self, *args, **kwargs):
        """
        Return a dictionary containing the calculations (aggregation)
        over the current queryset.

        If args is present the expression is passed as a kwarg using
        the Aggregate object's default alias.
        """
        if self.query.distinct_fields:
            raise NotImplementedError("aggregate() + distinct(fields) not implemented.")

        ##检查字典传入参数是否为resolve_expression,如果是,则raise错误
        self._validate_values_are_expressions(args + tuple(kwargs.values()), method_name='aggregate')
        for arg in args:
            # The default_alias property raises TypeError if default_alias
            # can't be set automatically or AttributeError if it isn't an
            # attribute.
            try:
                arg.default_alias
            except (AttributeError, TypeError):
                raise TypeError("Complex aggregates require an alias")
            kwargs[arg.default_alias] = arg

        query = self.query.chain()
        #value为聚合表达式,调用sql.query中的add_annotation
        for (alias, aggregate_expr) in kwargs.items():
            query.add_annotation(aggregate_expr, alias, is_summary=True)
            if not query.annotations[alias].contains_aggregate:
                raise TypeError("%s is not an aggregate expression" % alias)
        return query.get_aggregation(self.db, kwargs)

```


##向外引用:


* 删除操作时候引用了**Collector类**
* update操作使用 query类的**add_update_values方法**,所有的写sql语句时候都使用了

```python
        with transaction.atomic(using=self.db, savepoint=False):
            rows = query.get_compiler(self.db).execute_sql(CURSOR)
            
```


这个with的过程

* filter_exclude 都采用了query的add_q(Q)方法
* annotate方法中引用了sql query的add_filtered_relation与add_annotation方法进行操作annotate操作
* order_by中引用了sql.query的add_ordering方法
* aggregate引用了sql.query中的add_annotation(aggregate_expr, alias, is_summary=True),然后返回的是query.get_aggregation(self.db, kwargs)


##总结:
我们可以看到:
在manager类中定义了从queryset 类中 copy 属性跟方法 的方法;,


queryset中定义的常用的all(),filter(),order_by(),等方法,都是检查传入参数的正确性,查询在queryset的缓存中是否有缓存(有的话不需要去sql数据库中重新获取,减少IO),然后调用sql.query类中的具体实现方法来实现sql操作.

