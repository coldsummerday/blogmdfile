# sql.query类:

```python
    def __str__(self):
        """
        Return the query as a string of SQL with the parameter values
        substituted in (use sql_with_params() to see the unsubstituted string).

        Parameter values won't necessarily be quoted correctly, since that is
        done by the database interface at execution time.
        """
        sql, params = self.sql_with_params()
        return sql % params
```


* aggregation

```python
    def rewrite_cols(self, annotation, col_cnt):
        # We must make sure the inner query has the referred columns in it.
        # If we are aggregating over an annotation, then Django uses Ref()
        # instances to note this. However, if we are annotating over a column
        # of a related model, then it might be that column isn't part of the
        # SELECT clause of the inner query, and we must manually make sure
        # the column is selected. An example case is:
        #    .aggregate(Sum('author__awards'))
        # Resolving this expression results in a join to author, but there
        # is no guarantee the awards column of author is in the select clause
        # of the query. Thus we must manually add the column to the inner
        # query.

        ##当一个aggregating over an annotation操作的时候,联系多张表,
        # 如.aggregate(Sum('author__awards')),需要在query中添加awards列保证query中选择了awards
        orig_exprs = annotation.get_source_expressions()
        new_exprs = []
        for expr in orig_exprs:
            # FIXME: These conditions are fairly arbitrary. Identify a better
            # method of having expressions decide which code path they should
            # take.

            #分别判断expr是什么对象,如果是WhereNode,LookUp,则需要重新拆解
            if isinstance(expr, Ref):
                # Its already a Ref to subquery (see resolve_ref() for
                # details)
                new_exprs.append(expr)
            elif isinstance(expr, (WhereNode, Lookup)):
                # Decompose the subexpressions further. The code here is
                # copied from the else clause, but this condition must appear
                # before the contains_aggregate/is_summary condition below.
                new_expr, col_cnt = self.rewrite_cols(expr, col_cnt)
                new_exprs.append(new_expr)
            elif isinstance(expr, Col) or (expr.contains_aggregate and not expr.is_summary):
                # Reference to column. Make sure the referenced column
                # is selected.
                col_cnt += 1
                col_alias = '__col%d' % col_cnt
                self.annotations[col_alias] = expr
                self.append_annotation_mask([col_alias])
                new_exprs.append(Ref(col_alias, expr))
            else:
                # Some other expression not referencing database values
                # directly. Its subexpression might contain Cols.
                new_expr, col_cnt = self.rewrite_cols(expr, col_cnt)
                new_exprs.append(new_expr)
        annotation.set_source_expressions(new_exprs)
        return annotation, col_cnt

    def get_aggregation(self, using, added_aggregate_names):
        """
        Return the dictionary with the values of the existing aggregations.
        """

        if not self.annotation_select:
            return {}
        #界限与是否存在的值
        has_limit = self.low_mark != 0 or self.high_mark is not None
        has_existing_annotations = any(
            annotation for alias, annotation
            in self.annotations.items()
            if alias not in added_aggregate_names
        )
        # Decide if we need to use a subquery.
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
        #子查询  使用group_by
        if (isinstance(self.group_by, tuple) or has_limit or has_existing_annotations or
                self.distinct or self.combinator):
            #引用sql .subqueries的AggregateQuery进行aggregarion
            from django.db.models.sql.subqueries import AggregateQuery
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
                    #用expression类把联系的表达式写进query中的annotation中
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

* get_count 方法

此方法中,将__count传入get_aggregation中,获取返回结果字典:

```python
    def get_count(self, using):
        """
        Perform a COUNT() query using the current filter constraints.
        """
        obj = self.clone()
        #使用annotaions的Count(*),get_aggregation获取结果
        obj.add_annotation(Count('*'), alias='__count', is_summary=True)
        number = obj.get_aggregation(using, ['__count'])['__count']
        if number is None:
            number = 0
        return number
```

* 





#注:
* sql.query中  alias_map是一个orderdDic类对象,记录的是加入query的什么 和他们的类型:
key为table的alias,value是 Join-like对象
* where 对象为 一个Where类,记录了where语句,select是一个Select类


