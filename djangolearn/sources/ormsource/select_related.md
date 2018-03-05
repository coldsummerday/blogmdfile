##简介:
**select_related**是django中用来优化一对一,多对一的情况,它用于 在查找某个表的时候,在sql语句中拼接上外键的表的信息,从而减数据库IO的次数.


##调用函数栈:

* db.models.query.py/class QuerySet/select_related
* db.models.sql.query.py/class Query/add_select_related



```python
    def select_related(self, *fields):
        """
        Return a new QuerySet instance that will select related objects.

        If fields are specified, they must be ForeignKey fields and only those
        related objects are included in the selection.

        If select_related(None) is called, clear the list.
        """

        #有外键关联的表格

        if self._fields is not None:
            raise TypeError("Cannot call select_related() after .values() or .values_list()")

        obj = self._chain()
        if fields == (None,):
            obj.query.select_related = False
        elif fields:
            #在query中增添field字段
            obj.query.add_select_related(fields)
        else:
            obj.query.select_related = True
        return obj
```


```python
    def add_select_related(self, fields):
        """
        Set up the select_related data structure so that we only select
        certain related models (as opposed to all models, when
        self.select_related=True).
        """
        #如果select_related还未设初值,则设字典,否则增加key:value
        if isinstance(self.select_related, bool):
            field_dict = {}
        else:
            field_dict = self.select_related
        for field in fields:
            d = field_dict
            #增加了表名字与字段名为Key,且value都为{}
            for part in field.split(LOOKUP_SEP):
                d = d.setdefault(part, {})
        self.select_related = field_dict
```



##prefetch_related 


```python
    def prefetch_related(self, *lookups):
        """
        Return a new QuerySet instance that will prefetch the specified
        Many-To-One and Many-To-Many related objects when the QuerySet is
        evaluated.

        When prefetch_related() is called more than once, append to the list of
        prefetch lookups. If prefetch_related(None) is called, clear the list.
        """
        #每调用一次prefetch_related,则把lookup加到_prefetch_related_lookups上
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

