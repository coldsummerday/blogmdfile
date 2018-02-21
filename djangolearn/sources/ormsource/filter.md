#objects.filter()方法追寻:

* Queryset.filter(self, \*args, \*\*kwargs)
* Queryset._filter_or_exclude(self, negate, \*args, \*\*kwargs)
(negate=False)

* sql/query.py/class Query: add_q(Q(\*args, \*\*kwargs))
* sql/query.py/class Query: _add_q()
* demote_joins()



##1.models.query.py

在执行filter方法的时候()

其直接调用的是_filter_or_exclude方法

```python
    def filter(self, *args, **kwargs):
        """
        Return a new QuerySet instance with the args ANDed to the existing
        set.
        """
        return self._filter_or_exclude(False, *args, **kwargs)
```

```python
    def _filter_or_exclude(self, negate, *args, **kwargs):
        if args or kwargs:
            assert self.query.can_filter(), \
                "Cannot filter a query once a slice has been taken."
        #得到克隆对象
        
        clone = self._chain()
        
        if negate:
            clone.query.add_q(~Q(*args, **kwargs))
        #filter的时候调用add_q 方法,传入Q class
        else:
            clone.query.add_q(Q(*args, **kwargs))
        return clone
```


##2.sql/query.py/class  Query

###2.1  add_q

```python
    def add_q(self, q_object):
        """
        A preprocessor for the internal _add_q(). Responsible for doing final
        join promotion.
        """
        # For join promotion this case is doing an AND for the added q_object
        # and existing conditions. So, any existing inner join forces the join
        # type to remain inner. Existing outer joins can however be demoted.
        # (Consider case where rel_a is LOUTER and rel_a__col=1 is added - if
        # rel_a doesn't produce any rows, then the whole condition must fail.
        # So, demotion is OK.

        #从alias_map中取出已存在的inner join的表格,需要做连接操作
        existing_inner = {a for a in self.alias_map if self.alias_map[a].join_type == INNER}
        #添加当前的q对象到已存在的filter中等待执行sql的编译
        clause, _ = self._add_q(q_object, self.used_aliases)
        #将返回的where对象插入到当前类的where中,且用and连接表示(之前的where对象跟加入的q对象条件关系为and)
        if clause:
            self.where.add(clause, AND)
        #降级 joins 加入已存在的内连接表
        self.demote_joins(existing_inner)
```

###2.2  \_add\_q方法

(该方法为增加一个Q对象到filter中):

```python
    def _add_q(self, q_object, used_aliases, branch_negated=False,
               current_negated=False, allow_joins=True, split_subq=True):
        """Add a Q-object to the current filter."""
        ##该方法为增加一个Q对象到filter中
        connector = q_object.connector
        #是否非否定
        current_negated = current_negated ^ q_object.negated
        branch_negated = branch_negated or q_object.negated
        #新建一个where对象
        target_clause = self.where_class(connector=connector,
                                         negated=q_object.negated)
        joinpromoter = JoinPromoter(q_object.connector, len(q_object.children), current_negated)
        for child in q_object.children:
            if isinstance(child, Node):
                #因为q是一个tree.node类型,需要把q的孩子也加入到filter中
                child_clause, needed_inner = self._add_q(
                    child, used_aliases, branch_negated,
                    current_negated, allow_joins, split_subq)
                #增加需要内部连接inner_join的次数 (vote为一个counter对象,用于计数)
                joinpromoter.add_votes(needed_inner)
            else:
                #建立一个filter对象,
                child_clause, needed_inner = self.build_filter(
                    child, can_reuse=used_aliases, branch_negated=branch_negated,
                    current_negated=current_negated, allow_joins=allow_joins,
                    split_subq=split_subq,
                )
                joinpromoter.add_votes(needed_inner)
            if child_clause:
                #将连接的q对象表达式放入where对象中
                target_clause.add(child_clause, connector)
        needed_inner = joinpromoter.update_join_types(self)
        return target_clause, needed_inner
```

###2.3 build_filter()方法:
filter传入的q对象孩子不为一个node的时候,证明该q对象只有一个节点,此时整个filter为空,需要新增而不是加入

```python
 def build_filter(self, filter_expr, branch_negated=False, current_negated=False,
                     can_reuse=None, allow_joins=True, split_subq=True,
                     reuse_with_filtered_relation=False):


        #“branch_negated”告诉我们当前分支是否包含任何分支。是否需要子查询
        #“current_negated”用于确定当前过滤器是否为空
        #current_negated和branch_negated之间的区别是:current_negated被设置成每个都否定,
        #branch_negated是第一个否定
        if isinstance(filter_expr, dict):
            raise FieldError("Cannot parse keyword query as dict")
        arg, value = filter_expr
        ##filter以一个(arg,value)的形式存在,多个filter_expr 用List存储
        if not arg:
            raise FieldError("Cannot parse keyword query %r" % arg)
        ##arg 的形式是一个  field__parts__lookup的形式,reffed_expression为false,当用filter的时候
        lookups, parts, reffed_expression = self.solve_lookup_type(arg)
        ##lookups为__'icontains'这种,parts为model的field 合理字段
        if not getattr(reffed_expression, 'filterable', True):
            raise NotSupportedError(
                reffed_expression.__class__.__name__ + ' is disallowed in '
                'the filter clause.'
            )
        #字段不允许joins
        if not allow_joins and len(parts) > 1:
            raise FieldError("Joined field references are not permitted in this query")

        #pre_joins为一个字典,代表了需要join的table
        pre_joins = self.alias_refcount.copy()
        #解析lookup后面的值
        value = self.resolve_lookup_value(value, can_reuse, allow_joins)
        #如果有需要join的table的话,加入uesd_joins中
        used_joins = {k for k, v in self.alias_refcount.items() if v > pre_joins.get(k, 0)}
        #在where对象进行加入join
        clause = self.where_class()
        #filter时,reffed_expression为false
        if reffed_expression:
            condition = self.build_lookup(lookups, reffed_expression, value)
            clause.add(condition, AND)
            return clause, []

        opts = self.get_meta()
        alias = self.get_initial_alias()
        allow_many = not branch_negated or not split_subq

        try:
            #初始化一个join操作
            join_info = self.setup_joins(
                parts, opts, alias, can_reuse=can_reuse, allow_many=allow_many,
                reuse_with_filtered_relation=reuse_with_filtered_relation,
            )

            # Prevent iterator from being consumed by check_related_objects()
            if isinstance(value, Iterator):
                value = list(value)
            #检查关联表连接的正确性
            self.check_related_objects(join_info.final_field, value, join_info.opts)

            # split_exclude() needs to know which joins were generated for the
            # lookup parts
            self._lookup_joins = join_info.joins
        except MultiJoin as e:
            return self.split_exclude(filter_expr, LOOKUP_SEP.join(parts[:e.level]),
                                      can_reuse, e.names_with_path)

        # Update used_joins before trimming since they are reused to determine
        # which joins could be later promoted to INNER.
        used_joins.update(join_info.joins)

        targets, alias, join_list = self.trim_joins(join_info.targets, join_info.joins, join_info.path)
        if can_reuse is not None:
            #复用连接的参数增加 joins 新加的join表
            can_reuse.update(join_list)

        if join_info.final_field.is_relation:
            #col为获取最后一个连接的字段
            # No support for transforms for relational fields
            num_lookups = len(lookups)
            if num_lookups > 1:
                raise FieldError('Related Field got invalid lookup: {}'.format(lookups[0]))
            if len(targets) == 1:
                col = targets[0].get_col(alias, join_info.final_field)
            else:
                col = MultiColSource(alias, targets, join_info.targets, join_info.final_field)
        else:
            col = targets[0].get_col(alias, join_info.final_field)

        condition = self.build_lookup(lookups, col, value)
        lookup_type = condition.lookup_name
        #where类中用and连接lookup
        clause.add(condition, AND)

        require_outer = lookup_type == 'isnull' and condition.rhs is True and not current_negated
        if current_negated and (lookup_type != 'isnull' or condition.rhs is False):
            #当前查询器为空,且需要新增查询的时候
            require_outer = True
            if (lookup_type != 'isnull' and (
                    self.is_nullable(targets[0]) or
                    self.alias_map[join_list[-1]].join_type == LOUTER)):
                # The condition added here will be SQL like this:
                # NOT (col IS NOT NULL), where the first NOT is added in
                # upper layers of code. The reason for addition is that if col
                # is null, then col != someval will result in SQL "unknown"
                # which isn't the same as in Python. The Python None handling
                # is wanted, and it can be gotten by
                # (col IS NULL OR col != someval)
                #   <=>
                # NOT (col IS NOT NULL AND col = someval).
                lookup_class = targets[0].get_lookup('isnull')
                clause.add(lookup_class(targets[0].get_col(alias, join_info.targets[0]), False), AND)
        #返回where查询器,以及需要用到的joins
        return clause, used_joins if not require_outer else ()
```

该方法首先检查了lookup表达式中各个值的正确性(期间递归地调用了solve_lookup_type,names_to_path,resolve_lookup_value)

新建WHERE对象,

如果有join需要连接多张表的话,通过连接的最后一个字段,新建一个joinInfo对象,并将该join用AND加入到WHERE对象中.

用AND语句在where对象中新加进lookup中的条件,返回该WHERE对象和用到的Join,等待使用或者合并WHERE.


####2.3.1 solve_lookup_type

在新增Filter的过程中,需要对lookup进行检查:

```python
    def solve_lookup_type(self, lookup):
        """
        Solve the lookup type from the lookup (e.g.: 'foobar__id__icontains').
        """
        #处理一个lookip,'foobar__id__icontains'
        #LOOKUP_SEP : "__"
        #返回的时候filter的字段跟查询函数lookup部分
        lookup_splitted = lookup.split(LOOKUP_SEP)
        #当组合查询annotations存在的时候,解析expression
        if self._annotations:
            expression, expression_lookups = refs_expression(lookup_splitted, self.annotations)
            if expression:
                return expression_lookups, (), expression
        #非annotation的时候,调用names_to_path,传入分开的lookup
        #返回最后一个lookupname的field(即是需要filter的字段),跟lookup条件表达式中最后的部分,比如__'contains'
        _, field, _, lookup_parts = self.names_to_path(lookup_splitted, self.get_meta())
        #获取需要field的字段
        field_parts = lookup_splitted[0:len(lookup_splitted) - len(lookup_parts)]
        if len(lookup_parts) > 1 and not field_parts:
            raise FieldError(
                'Invalid lookup "%s" for model %s".' %
                (lookup, self.get_meta().model.__name__)
            )
        return lookup_parts, field_parts, False
```

该方法用"__"分割lookup,并检查非最后一个(最后一个为查询的条件如:contains),是否在model的字段中,返回的查询条件list,跟查询字段list
中途调用了names_to_path来获取model的正确字段


####2.3.2names_to_path方法

方法作用:lookup中的字段与model中的field对应起来,并检查是否需要连接

```python
    def names_to_path(self, names, opts, allow_many=True, fail_on_missing=False):

        #names为lookup中解析的filter的字段,opts为model._meta用于获取model的fields
        #将lookup中的字段与model中的field对应起来
        path, names_with_path = [], []
        for pos, name in enumerate(names):
            cur_names_with_path = (name, [])
            if name == 'pk':
                name = opts.pk.name

            field = None
            filtered_relation = None
            try:
                field = opts.get_field(name)
            except FieldDoesNotExist:
                #如果是annotations的话,将name则是用户自定义的作为返回字典的key
                if name in self.annotation_select:
                    field = self.annotation_select[name].output_field
                #如果不是annotations,则是需要连接的另外一张table的name,保证位于第一个
                elif name in self._filtered_relations and pos == 0:
                    filtered_relation = self._filtered_relations[name]
                    field = opts.get_field(filtered_relation.relation_name)
            #field正确返回了
            if field is not None:
                # Fields that contain one-to-many relations with a generic
                # model (like a GenericForeignKey) cannot generate reverse
                # relations and therefore cannot be used for reverse querying.
                if field.is_relation and not field.related_model:
                    raise FieldError(
                        "Field %r does not generate an automatic reverse "
                        "relation and therefore cannot be used for reverse "
                        "querying. If it is a GenericForeignKey, consider "
                        "adding a GenericRelation." % name
                    )
                try:
                    model = field.model._meta.concrete_model
                except AttributeError:
                    # QuerySet.annotate() may introduce fields that aren't
                    # attached to a model.
                    #注意annations操作可能联系多张表,并非自身的concrete_model
                    model = None
            else:
                # We didn't find the current field, so move position back
                # one step.
                #没能找到正确的field,返回一步
                pos -= 1
                if pos == -1 or fail_on_missing:
                    field_names = list(get_field_names_from_opts(opts))
                    available = sorted(
                        field_names + list(self.annotation_select) +
                        list(self._filtered_relations)
                    )
                    #一直没找到,返回错误,并显示正确的可选field
                    raise FieldError("Cannot resolve keyword '%s' into field. "
                                     "Choices are: %s" % (name, ", ".join(available)))
                break
            # Check if we need any joins for concrete inheritance cases (the
            # field lives in parent, but we are currently in one of its
            # children)
            #如果是annotation操作,需要联系表,获取父亲表的model
            if model is not opts.model:
                path_to_parent = opts.get_path_to_parent(model)
                if path_to_parent:
                    path.extend(path_to_parent)
                    cur_names_with_path[1].extend(path_to_parent)
                    opts = path_to_parent[-1].to_opts
            if hasattr(field, 'get_path_info'):
                pathinfos = field.get_path_info(filtered_relation)
                if not allow_many:
                    for inner_pos, p in enumerate(pathinfos):
                        #path的多对多情况
                        if p.m2m:
                            cur_names_with_path[1].extend(pathinfos[0:inner_pos + 1])
                            names_with_path.append(cur_names_with_path)
                            raise MultiJoin(pos + 1, names_with_path)
                last = pathinfos[-1]
                path.extend(pathinfos)
                final_field = last.join_field
                opts = last.to_opts
                targets = last.target_fields
                cur_names_with_path[1].extend(pathinfos)
                names_with_path.append(cur_names_with_path)
            else:
                # Local non-relational field.
                final_field = field
                targets = (field,)
                if fail_on_missing and pos + 1 != len(names):
                    raise FieldError(
                        "Cannot resolve keyword %r into field. Join on '%s'"
                        " not permitted." % (names[pos + 1], name))
                break
        return path, final_field, targets, names[pos + 1:]
```

####2.3.3 resolve_lookup_value方法
检查lookup条件查询表达式中的值是否合法


```python
    def resolve_lookup_value(self, value, can_reuse, allow_joins):
        #主要看value是不是一个表达式,如果是的话需要单独调用resolve_expression去解析,
        #如果list or tuple 中有 resolve_expression,也需要单独解析,不是的话直接返回原值比如(=1),返回1
        if hasattr(value, 'resolve_expression'):
            value = value.resolve_expression(self, reuse=can_reuse, allow_joins=allow_joins)
        elif isinstance(value, (list, tuple)):
            # The items of the iterable may be expressions and therefore need
            # to be resolved independently.
            for sub_value in value:
                if hasattr(sub_value, 'resolve_expression'):
                    sub_value.resolve_expression(self, reuse=can_reuse, allow_joins=allow_joins)
        return value
```

###2.4 demote_joins方法:

```python
    def demote_joins(self, aliases):
        """
        Change join type from LOUTER to INNER for all joins in aliases.

        Similarly to promote_joins(), this method must ensure no join chains
        containing first an outer, then an inner join are generated. If we
        are demoting b->c join in chain a LOUTER b LOUTER c then we must
        demote a->b automatically, or otherwise the demotion of b->c doesn't
        actually change anything in the query results. .
        """
        aliases = list(aliases)
        while aliases:
            alias = aliases.pop(0)
            #if table 类型为LOUTER( maybe left join,maybe right join),将该table降级
            if self.alias_map[alias].join_type == LOUTER:
                self.alias_map[alias] = self.alias_map[alias].demote()
                parent_alias = self.alias_map[alias].parent_alias
                #inner join增加LOUTER join的父亲表(如果它是inner join的话)
                if self.alias_map[parent_alias].join_type == INNER:

                    aliases.append(parent_alias)

```



##总结:
filter方法中,主要把传入的查询条件当一个Q对象,然后 新建filter,检查lookup,新建where对象并插入lookup条件查询表达式,如果有多表连接的话,需要把join也加入到where中,但是由于django的惰性查询关系,做完这一系列操作,并没有马上执行sql,而是等待需要用的Queryset的__iter__的时候,才去真正的根据QuerySet 已经设置好的各种查询条件,去编译sql语句,执行并返回结果.


##涉及到的python标准库


* Counter()
用于计数,

```python
from collections import Counter
data = ['a','2',2,4,5,'2','b',4,7,'a',5,'d','a','z']
c = Counter(data)
print c
Counter({'a': 3, 4: 2, 5: 2, '2': 2, 2: 1, 'b': 1, 7: 1, 'z': 1, 'd': 1})

c.update("aaaa")
print c
Counter({'a': 7, 4: 2, 5: 2, '2': 2, 2: 1, 'b': 1, 7: 1, 'd': 1, 'z': 1})
```
增加了4次


