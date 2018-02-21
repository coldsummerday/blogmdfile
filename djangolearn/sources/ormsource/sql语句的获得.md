


##一、执行sql的起点:

db/models/query.py/class ModelIterable \_\_iter\_\_()

```python
        compiler = queryset.query.get_compiler(using=db)
        # Execute the query. This will also fill compiler.select, klass_info,
        # and annotations.
        results = compiler.execute_sql(chunked_fetch=self.chunked_fetch, chunk_size=self.chunk_size)
```


##二、compiler类

compiler类位于db.models.sql.compiler.py

###二.1 execute_sql方法

方法原型:

```
execute_sql(self, result_type=MULTI, chunked_fetch=False, chunk_size=GET_ITERATOR_CHUNK_SIZE):
```



```python
    def execute_sql(self, result_type=MULTI, chunked_fetch=False, chunk_size=GET_ITERATOR_CHUNK_SIZE):


        #对数据库运行查询并返回结果(s),结果是一个的话直接返回,多个结果集就迭代
        result_type = result_type or NO_RESULTS
        try:
            #获取sql语句
            sql, params = self.as_sql()
            if not sql:
                raise EmptyResultSet
        except EmptyResultSet:
            if result_type == MULTI:
                return iter([])
            else:
                return
        #游标的获取,是直接获取还是分块游标(可能需要多个数据库的时候操作)
        if chunked_fetch:
            cursor = self.connection.chunked_cursor()
        else:
            cursor = self.connection.cursor()
        try:
            #执行sql语句
            cursor.execute(sql, params)
        except Exception:
            # Might fail for server-side cursors (e.g. connection closed)
            cursor.close()
            raise
        #返回游标还是一行数据
        if result_type == CURSOR:
            # Give the caller the cursor to process and close.
            return cursor
        if result_type == SINGLE:
            try:
                val = cursor.fetchone()
                if val:
                    return val[0:self.col_count]
                return val
            #最终记得关闭游标
            finally:
                # done with the cursor
                cursor.close()
        if result_type == NO_RESULTS:
            cursor.close()
            return
        #返回多行数据
        result = cursor_iter(
            cursor, self.connection.features.empty_fetchmany_value,
            self.col_count if self.has_extra_select else None,
            chunk_size,
        )
        if not chunked_fetch and not self.connection.features.can_use_chunked_reads:
            try:
                # If we are using non-chunked reads, we return the same data
                # structure as normally, but ensure it is all read into memory
                # before going any further. Use chunked_fetch if requested.
                return list(result)
            finally:
                # done with the cursor
                cursor.close()
        return result

```


此方法:

* 通过self.as_sql()拿到sql语句跟参数
* 获取cursor游标
* 执行sql并得到结果
* 然后根据传入的result_type来从游标中返回正确的结果集

###二.2 as_sql()方法

```python
   def as_sql(self, with_limits=True, with_col_aliases=False):
        """
        Create the SQL for this query. Return the SQL string and list of
        parameters.

        If 'with_limits' is False, any limit/offset information is not included
        in the query.
        """

        #联系表的计数参数,key为table的alias,value为被记录了几次
        refcounts_before = self.query.alias_refcount.copy()
        try:
            #sql前处理,获取select,order_by,group_by等sql语句的部分
            extra_select, order_by, group_by = self.pre_sql_setup()
            for_update_part = None
            # Is a LIMIT/OFFSET clause needed?
            with_limit_offset = with_limits and (self.query.high_mark is not None or self.query.low_mark)
            combinator = self.query.combinator
            features = self.connection.features
            if combinator:
                if not getattr(features, 'supports_select_{}'.format(combinator)):
                    raise NotSupportedError('{} is not supported on this database backend.'.format(combinator))
                result, params = self.get_combinator_sql(combinator, self.query.combinator_all)
            else:
                #获取distinct_field
                distinct_fields = self.get_distinct()
                # This must come after 'select', 'ordering', and 'distinct'
                # (see docstring of get_from_clause() for details).
                from_, f_params = self.get_from_clause()
                where, w_params = self.compile(self.where) if self.where is not None else ("", [])
                having, h_params = self.compile(self.having) if self.having is not None else ("", [])
                #result就是一个list,一个个装载sql语句不同的部分
                result = ['SELECT']
                params = []

                if self.query.distinct:
                    result.append(self.connection.ops.distinct_sql(distinct_fields))

                out_cols = []
                col_idx = 1
                for _, (s_sql, s_params), alias in self.select + extra_select:
                    if alias:
                        #改名字
                        s_sql = '%s AS %s' % (s_sql, self.connection.ops.quote_name(alias))
                    elif with_col_aliases:
                        s_sql = '%s AS %s' % (s_sql, 'Col%d' % col_idx)
                        col_idx += 1
                    params.extend(s_params)
                    out_cols.append(s_sql)
                #result sql list 获取完select  from部分
                result += [', '.join(out_cols), 'FROM', *from_]
                params.extend(f_params)

                if self.query.select_for_update and self.connection.features.has_select_for_update:
                    if self.connection.get_autocommit():
                        raise TransactionManagementError('select_for_update cannot be used outside of a transaction.')

                    if with_limit_offset and not self.connection.features.supports_select_for_update_with_limit:
                        raise NotSupportedError(
                            'LIMIT/OFFSET is not supported with '
                            'select_for_update on this database backend.'
                        )
                    nowait = self.query.select_for_update_nowait
                    skip_locked = self.query.select_for_update_skip_locked
                    of = self.query.select_for_update_of
                    # If it's a NOWAIT/SKIP LOCKED/OF query but the backend
                    # doesn't support it, raise NotSupportedError to prevent a
                    # possible deadlock.
                    if nowait and not self.connection.features.has_select_for_update_nowait:
                        raise NotSupportedError('NOWAIT is not supported on this database backend.')
                    elif skip_locked and not self.connection.features.has_select_for_update_skip_locked:
                        raise NotSupportedError('SKIP LOCKED is not supported on this database backend.')
                    elif of and not self.connection.features.has_select_for_update_of:
                        raise NotSupportedError('FOR UPDATE OF is not supported on this database backend.')
                    for_update_part = self.connection.ops.for_update_sql(
                        nowait=nowait,
                        skip_locked=skip_locked,
                        of=self.get_select_for_update_of_arguments(),
                    )

                if for_update_part and self.connection.features.for_update_after_from:
                    result.append(for_update_part)

                #条件部分
                if where:
                    result.append('WHERE %s' % where)
                    params.extend(w_params)

                grouping = []
                for g_sql, g_params in group_by:
                    grouping.append(g_sql)
                    params.extend(g_params)
                if grouping:
                    if distinct_fields:
                        raise NotImplementedError('annotate() + distinct(fields) is not implemented.')
                    order_by = order_by or self.connection.ops.force_no_ordering()
                    result.append('GROUP BY %s' % ', '.join(grouping))

                if having:
                    result.append('HAVING %s' % having)
                    params.extend(h_params)

            if order_by:
                ordering = []
                for _, (o_sql, o_params, _) in order_by:
                    ordering.append(o_sql)
                    params.extend(o_params)
                result.append('ORDER BY %s' % ', '.join(ordering))

            if with_limit_offset:
                result.append(self.connection.ops.limit_offset_sql(self.query.low_mark, self.query.high_mark))

            if for_update_part and not self.connection.features.for_update_after_from:
                result.append(for_update_part)

            if self.query.subquery and extra_select:
                # If the query is used as a subquery, the extra selects would
                # result in more columns than the left-hand side expression is
                # expecting. This can happen when a subquery uses a combination
                # of order_by() and distinct(), forcing the ordering expressions
                # to be selected as well. Wrap the query in another subquery
                # to exclude extraneous selects.
                sub_selects = []
                sub_params = []
                for select, _, alias in self.select:
                    if alias:
                        sub_selects.append("%s.%s" % (
                            self.connection.ops.quote_name('subquery'),
                            self.connection.ops.quote_name(alias),
                        ))
                    else:
                        select_clone = select.relabeled_clone({select.alias: 'subquery'})
                        subselect, subparams = select_clone.as_sql(self, self.connection)
                        sub_selects.append(subselect)
                        sub_params.extend(subparams)
                return 'SELECT %s FROM (%s) subquery' % (
                    ', '.join(sub_selects),
                    ' '.join(result),
                ), sub_params + params
            #拼接成sql语句
            return ' '.join(result), tuple(params)
        finally:
            # Finally do cleanup - get rid of the joins we created above.
            #清除建立的连接
            self.query.reset_refcounts(refcounts_before)

```


如果我们忽略掉这过程中的许多细节如:

* 怎么获取select,where,order_by等sql部分
* 怎么对上面各部分各个连接啊,参数等合法检验

我们会发现,其实as_sql的实现方式不外乎就是:
**用list一次存储各个部分,然后"".join方式连接这个list成一个字符串**

当然,各部分包括(但不限于):

* select部分
* distinct
* where表达式
* group表达式
* having表达式
* 是否加入limit or offset


注意:以上的表达式都是基于tree.node(方便定义嵌套的条件表达式)的类,在类中定义了as_sql方法


##:一些源码阅读过程中的记录

###(1)sql 中LIMIT 与Offset:


语法规则:$SELECT * FROM table  LIMIT [offset,]$

比如

```
SELECT * FROM table LIMIT 5,10;  // 检索记录行 6-15
```

当从 6 -最后的时候:offset 用-1代替

###(2)字符串拼接的方式


Django 对sql语句的拼接方式是:

* 建立一个list,需要拼接的部分依次放入list中
* 最后用" ".join(list)的形式拼接字符串

比直接+拼接的好处:

**+**操作每次申请一个新的字符串内存,然后把两个拼接部分 放入这块内存中,频繁申请内存..

用list,append的方式添加后面部分:

因为python中的list固定大小都是一个曲线上升的形势,,只要新加入的部分超过了原来设定的大小,才需要重新申请一整块比原来大的内存,依次copy过去.(原理请看我的python源码阅读博客:[list实现](http://www.haibin.online/articles/15))



