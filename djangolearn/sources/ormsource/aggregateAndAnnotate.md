##简介:
**aggregate**和**annotate**操作都是对应着sql中的聚合操作:

其区别可能在于:

* aggregate是对一个查询集合中聚合,比如有一个表为book,我们可以针对书的价钱,数量做SUM,COUNT,AVG等聚合操作(价钱,数量是book表中的字段)
* annotate是为查询集的每一项生成聚合(因为生成的聚合并不是原来表原有的字段,"注解"就是给表的每一个对象生成一个汇总值,).如book表与author表对应(假如是多对多关系),我们想知道每一本书有多少个作者的时候,就是一个annotate操作,给给图书添加作者数量的注解.


##一、aggregate

其函数调用栈可能是:

* django.db.models.query.py/class Query/method aggregate(self, \*args, \*\*kwargs)
* django.db.models.sql.query.py/class Query/method add_annotation(self, annotation, alias, is_summary=False):
* django.db.models.aggregates.py/class Aggregate/method resolve_expression(self, query=None, allow_joins=True, reuse=None, summarize=False, for_save=False)

* django.db.models.expressions.py/class Func /method resolve_expression(self, query=None, allow_joins=True, reuse=None, summarize=False, for_save=False)

* django.db.models.sql.query.py/class Query/method get_aggregation(self, using, added_aggregate_names)



###一.1:aggregate
manager的调用方法:

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

        ##检查字典传入value是否为resolve_expression,如果是,则raise错误
        self._validate_values_are_expressions(args + tuple(kwargs.values()), method_name='aggregate')
        #合并所有参数到字典kwargs
        for arg in args:
            # The default_alias property raises TypeError if default_alias
            # can't be set automatically or AttributeError if it isn't an
            # attribute.
            try:
                # 没有指定别名的用默认别名
                arg.default_alias
                #aggregate类的default_alias方法,查看该arg是否有alia(model别名),没有就会抛出错误
            except (AttributeError, TypeError):
                raise TypeError("Complex aggregates require an alias")
            kwargs[arg.default_alias] = arg

        query = self.query.chain()
        #value为聚合表达式,调用sql.query中的add_annotation,类似"Count('alias')"
        for (alias, aggregate_expr) in kwargs.items():
            query.add_annotation(aggregate_expr, alias, is_summary=True)
            if not query.annotations[alias].contains_aggregate:
                raise TypeError("%s is not an aggregate expression" % alias)
        return query.get_aggregation(self.db, kwargs)

```

该方法主要检查参数正确性,然后合并\*arg,\*\*kwargs到字典\*\*kwargs中.
然后调用query.add_annotation,依次添加annotate表达式,调用get_aggregation得到返回结果.

###一.2:add_annotation
函数功能:给query增加注解表达式

```python
    def add_annotation(self, annotation, alias, is_summary=False):
        """Add a single annotation expression to the Query."""
        #依次分解子表达式
        annotation = annotation.resolve_expression(self, allow_joins=True, reuse=None,
                                                   summarize=is_summary)
        #增加掩码(作用是select中不再选择该项)
        self.append_annotation_mask([alias])
        self.annotations[alias] = annotation
```

该函数主要执行的过程是:

* 分解annotation表达式
* 给annotation表达式中的alias增加掩码

###一.3:resolve_expression
分解子表达式:

```python
#Func.resolve_expression()

    def resolve_expression(self, query=None, allow_joins=True, reuse=None, summarize=False, for_save=False):
        #复制一个Func对象
        c = self.copy()
        c.is_summary = summarize
        #将每一个表达式存储字典中,返回Func对象
        for pos, arg in enumerate(c.source_expressions):
            c.source_expressions[pos] = arg.resolve_expression(query, allow_joins, reuse, summarize, for_save)
        return c
```

Func的子类:Aggregate中的resolve_expression

```python
    def resolve_expression(self, query=None, allow_joins=True, reuse=None, summarize=False, for_save=False):
        # Aggregates are not allowed in UPDATE queries, so ignore for_save
        #调用父类Func的resolve_expression,分解单个表达式到字典中
        c = super().resolve_expression(query, allow_joins, reuse, summarize)
        c.filter = c.filter and c.filter.resolve_expression(query, allow_joins, reuse, summarize)
        if not summarize:
            # Call Aggregate.get_source_expressions() to avoid
            # returning self.filter and including that in this loop.
            expressions = super(Aggregate, c).get_source_expressions()
            for index, expr in enumerate(expressions):
                if expr.contains_aggregate:
                    before_resolved = self.get_source_expressions()[index]
                    name = before_resolved.name if hasattr(before_resolved, 'name') else repr(before_resolved)
                    raise FieldError("Cannot compute %s('%s'): '%s' is an aggregate" % (c.name, name, name))
        return c
```

基类BaseExpression中:


```python

    def resolve_expression(self, query=None, allow_joins=True, reuse=None, summarize=False, for_save=False):
        #复制一个Func对象
        c = self.copy()
        c.is_summary = summarize
        #将每一个表达式存储字典中,返回Func对象
        for pos, arg in enumerate(c.source_expressions):
            c.source_expressions[pos] = arg.resolve_expression(query, allow_joins, reuse, summarize, for_save)
        return c
```


```python

    def _parse_expressions(self, *expressions):
        #解析表达式,如果不是'resolve_expression',,arg不是str的时候,value(arg),是str的话F(str)转化为数值
        return [
            arg if hasattr(arg, 'resolve_expression') else (
                F(arg) if isinstance(arg, str) else Value(arg)
            ) for arg in expressions
        ]
```

###一.4:get_aggregation

传入的是一个字典,key:聚合后的值的别名
,value:聚合表达式如(Count('author'))

函数功能,根据聚合表达式跟查询,调用sql执行,得到结果并返回字典;

```python
    #获取聚合值,参数added_aggregate_names传入的是一个字典,[alias]=expressions
    def get_aggregation(self, using, added_aggregate_names):
        """
        Return the dictionary with the values of the existing aggregations.
        """

        if not self.annotation_select:
            return {}
        #界限与是否存在已经聚合的值的值
        has_limit = self.low_mark != 0 or self.high_mark is not None
        has_existing_annotations = any(
            annotation for alias, annotation
            in self.annotations.items()
            if alias not in added_aggregate_names
        )
        # Decide if we need to use a subquery.(子查询)
        #
        # Existing annotations would cause incorrect results as get_aggregation()
        # must produce just one result and thus must not use GROUP BY. But we
        # aren't smart enough to remove the existing annotations from the
        # query, so those would force us to use GROUP BY.
        #
        # If the query has limit or distinct, or uses set operations, then
        # those operations must be done in a subquery so that the query
        # aggregates on the limit and/or distinct results instead of applying
        # the distinct and limit after the aggregation.

        #如果存在group_by或者limit或者已存在是注解聚合,都需要进行重新连接查询
        if (isinstance(self.group_by, tuple) or has_limit or has_existing_annotations or
                self.distinct or self.combinator):
            #引用sql .subqueries的AggregateQuery进行aggregarion
            from django.db.models.sql.subqueries import AggregateQuery
            #新建一个聚合query
            outer_query = AggregateQuery(self.model)
            inner_query = self.clone()
            inner_query.select_for_update = False
            inner_query.select_related = False

            if not has_limit and not self.distinct_fields:
                # Queries with distinct_fields need ordering and when a limit
                # is applied we must take the slice from the ordered query.
                # Otherwise no need for ordering.
                inner_query.clear_ordering(True)
            if not inner_query.distinct:
                # If the inner query uses default select and it has some
                # aggregate annotations, then we must make sure the inner
                # query is grouped by the main model's primary key. However,
                # clearing the select clause can alter results if distinct is
                # used.
                if inner_query.default_cols and has_existing_annotations:
                    inner_query.group_by = (self.model._meta.pk.get_col(inner_query.get_initial_alias()),)
                inner_query.default_cols = False

            #联系表
            relabels = {t: 'subquery' for t in inner_query.alias_map}
            relabels[None] = 'subquery'
            # Remove any aggregates marked for reduction from the subquery
            # and move them to the outer AggregateQuery.
            col_cnt = 0
            for alias, expression in list(inner_query.annotation_select.items()):
                if expression.is_summary:
                    expression, col_cnt = inner_query.rewrite_cols(expression, col_cnt)
                    #用expression类把联系的表达式写进新建的query中的annotation中
                    outer_query.annotations[alias] = expression.relabeled_clone(relabels)
                    del inner_query.annotations[alias]
                # Make sure the annotation_select wont use cached results.
                #给已经选择的annotation增加掩码,防止结果中使用cache的结果
                inner_query.set_annotation_mask(inner_query.annotation_select_mask)
            if inner_query.select == () and not inner_query.default_cols and not inner_query.annotation_select_mask:
                # In case of Model.objects[0:3].count(), there would be no
                # field selected in the inner query, yet we must use a subquery.
                # So, make sure at least one field is selected.
                inner_query.select = (self.model._meta.pk.get_col(inner_query.get_initial_alias()),)
            try:
                ##使用add_subquery ,将外查询跟内查询联系起来
                outer_query.add_subquery(inner_query, using)
            except EmptyResultSet:
                return {
                    alias: None
                    for alias in outer_query.annotation_select
                }

        #如果没有,证明是aggregate操作,聚合查找集合
        else:
            outer_query = self
            self.select = ()
            self.default_cols = False
            self._extra = {}

        outer_query.clear_ordering(True)
        outer_query.clear_limits()
        outer_query.select_for_update = False
        outer_query.select_related = False
        #设置好查询表参数,调用get_compiler来获取sql语句
        compiler = outer_query.get_compiler(using)
        result = compiler.execute_sql(SINGLE)
        if result is None:
            result = [None] * len(outer_query.annotation_select)

        converters = compiler.get_converters(outer_query.annotation_select.values())
        result = next(compiler.apply_converters((result,), converters))
        #返回结果集
        return dict(zip(outer_query.annotation_select, result))

```

###一.5总结:

整个aggregate执行过程可以总结为:

* 检查aggregate表达式的合法性
* 给query增加annotation(注解),以形成聚合条件,并形成掩码
* 检查是否需要连接外表(当存在group_by,limit,唯一值等情况),copy一个Aggregate的Query,与自身query联系起来.
* 最后进行sql查询,得到结果,调用compiler的转化,并返回结果字典;

##二、annotate
annotate因为是对查询集合的每一项进行聚合,所以需要得到查询集结果后再一次调用sql去联系外表聚合,所以它不像aggregate一样马上得到结果,而是惰性查询

调用栈:
* Django.db.models.query.py/class Query/annotate
* django.db.models.sql.query.py/class Query/add_filtered_relation or add_annotation
* 返回query,等到真正取值的时候执行compiler


###二.1:annotate

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
        #将args跟**kwargs中的参数合并到annoations
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
                #如果注解表达式是一个查询条件对象
                clone.query.add_filtered_relation(annotation, alias)
            else:
                #增加注解表达式
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

* 检查参数合法性
* 合并所有参数到一个OrdereDict()中(可根据插入顺序排列的字典)
* 查询本model的fields,聚合本Model中的字段则报错
* 根据annotation的不同调用add_filtered_relation or add_annotation
* 设置group_by
* 返回一个queryset对象


###add_filtered_relation

```python

    def add_filtered_relation(self, filtered_relation, alias):
        filtered_relation.alias = alias
        #获取lookup表达式

        lookups = dict(get_children_from_q(filtered_relation.condition))
        #chain的作用是连接起来(filtered_relation.relation_name,), lookups,作为迭代器
        for lookup in chain((filtered_relation.relation_name,), lookups):
            lookup_parts, field_parts, _ = self.solve_lookup_type(lookup)
            shift = 2 if not lookup_parts else 1
            if len(field_parts) > (shift + len(lookup_parts)):
                raise ValueError(
                    "FilteredRelation's condition doesn't support nested "
                    "relations (got %r)." % lookup
                )
        #增加条件表达到_filtered_relations字典中,等待sql语句的生成时生效
        self._filtered_relations[filtered_relation.alias] = filtered_relation
```



##额外收获:

* ORM中的聚合类在db.models.aggregates.py中定义

其每个类中都有其name跟template,用于sql的使用,如下代码展示了一个聚合函数从模板到生成sql语句的过程:

```python
class Avg(Aggregate):
    function = 'AVG'
    name = 'Avg'
    def as_mysql(self, compiler, connection):
        sql, params = super().as_sql(compiler, connection)
        if self.output_field.get_internal_type() == 'DurationField':
            sql = 'CAST(%s as SIGNED)' % sql
        return sql, params
        
        
class Aggregate(Func):
    contains_aggregate = True
    name = None
    filter_template = '%s FILTER (WHERE %%(filter)s)'
    window_compatible = True

class Func(SQLiteNumericMixin, Expression):
    """An SQL function call."""
    function = None
    template = '%(function)s(%(expressions)s)'
    arg_joiner = ', '
    arity = None  # The number of arguments the function accepts.

    def as_sql(self, compiler, connection, function=None, template=None, arg_joiner=None, **extra_context):
        connection.ops.check_expression_support(self)
        sql_parts = []
        params = []
        for arg in self.source_expressions:
            arg_sql, arg_params = compiler.compile(arg)
            sql_parts.append(arg_sql)
            params.extend(arg_params)
        data = {**self.extra, **extra_context}
        # Use the first supplied value in this order: the parameter to this
        # method, a value supplied in __init__()'s **extra (the value in
        # `data`), or the value defined on the class.
        if function is not None:
            data['function'] = function
        else:
            data.setdefault('function', self.function)
        template = template or data.get('template', self.template)
        arg_joiner = arg_joiner or data.get('arg_joiner', self.arg_joiner)
        data['expressions'] = data['field'] = arg_joiner.join(sql_parts)
        return template % data, params
```





















