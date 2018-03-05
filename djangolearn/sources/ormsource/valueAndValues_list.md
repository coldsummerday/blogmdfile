##Value


*   def values(self, \*fields, \*\*expressions)
*   _values
*   set_values(self, fields)
*   add_fields



values

```python

    def values(self, *fields, **expressions):
        fields += tuple(expressions)
        clone = self._values(*fields, **expressions)
        #ValuesIterable中执行 sql
        clone._iterable_class = ValuesIterable
        return clone
```

_values

```python
    def _values(self, *fields, **expressions):
        clone = self._chain()
        if expressions:
            clone = clone.annotate(**expressions)
        clone._fields = fields
        #设置需要提取的部分
        clone.query.set_values(fields)
        return clone
```

set_values

```python
    def set_values(self, fields):
        self.select_related = False
        #删除懒惰查询集合中的数据
        self.clear_deferred_loading()
        #清除已选字段
        self.clear_select_fields()


        #如果需要gourp_by ,则加入model的concrete_fields
        if self.group_by is True:
            #默认字段时候 False为allow_m2m
            self.add_fields((f.attname for f in self.model._meta.model._meta.concrete_fields), False)
            self.set_group_by()
            self.clear_select_fields()

        if fields:
            field_names = []
            extra_names = []
            annotation_names = []

            #是否需要单独进行extra与annotate操作
            if not self._extra and not self._annotations:
                # Shortcut - if there are no extra or annotations, then
                # the values() clause must be just field names.
                field_names = list(fields)
            else:
                self.default_cols = False
                for f in fields:
                    if f in self.extra_select:
                        extra_names.append(f)
                    elif f in self.annotation_select:
                        annotation_names.append(f)
                    else:
                        field_names.append(f)
            self.set_extra_mask(extra_names)
            self.set_annotation_mask(annotation_names)
        else:
            field_names = [f.attname for f in self.model._meta.concrete_fields]

        self.values_select = tuple(field_names)
        self.add_fields(field_names, True)
```

###value_list
* values_list
* _value
* 迭代class:ValuesListIterable(返回为元组的原因) 


```python
    def values_list(self, *fields, flat=False, named=False):
        if flat and named:
            raise TypeError("'flat' and 'named' can't be used together.")
        if flat and len(fields) > 1:
            raise TypeError("'flat' is not valid when values_list is called with more than one field.")
        #如果传入的fields不是一个分割表达式的话,加入field中
        field_names = {f for f in fields if not hasattr(f, 'resolve_expression')}
        _fields = []
        expressions = {}
        counter = 1
        for field in fields:
            #如果是表达式,则分解lookup
            if hasattr(field, 'resolve_expression'):
                field_id_prefix = getattr(field, 'default_alias', field.__class__.__name__.lower())
                while True:
                    field_id = field_id_prefix + str(counter)
                    counter += 1
                    if field_id not in field_names:
                        break

                expressions[field_id] = field
                _fields.append(field_id)
            else:
                _fields.append(field)
        #调用_value来统一获取的值
        clone = self._values(*_fields, **expressions)
        clone._iterable_class = (
            NamedValuesListIterable if named
            else FlatValuesListIterable if flat
            else ValuesListIterable
        )
        return clone
```





