
##简介:

Django Models中每一个field字段都与数据库中的列相对应


在django.db.models.fields/init.py文件中找到


可定义的field类型:

```python
__all__ = [
    'AutoField', 'BLANK_CHOICE_DASH', 'BigAutoField', 'BigIntegerField',
    'BinaryField', 'BooleanField', 'CharField', 'CommaSeparatedIntegerField',
    'DateField', 'DateTimeField', 'DecimalField', 'DurationField',
    'EmailField', 'Empty', 'Field', 'FieldDoesNotExist', 'FilePathField',
    'FloatField', 'GenericIPAddressField', 'IPAddressField', 'IntegerField',
    'NOT_PROVIDED', 'NullBooleanField', 'PositiveIntegerField',
    'PositiveSmallIntegerField', 'SlugField', 'SmallIntegerField', 'TextField',
    'TimeField', 'URLField', 'UUIDField',
]
```


```python
class Field(RegisterLookupMixin):
    """Base class for all field types"""

    # Designates whether empty strings fundamentally are allowed at the
    # database level.
    empty_strings_allowed = True
    #EMPTY_VALUES 为 (None, '', [], (), {})
    empty_values = list(validators.EMPTY_VALUES)
    
    def __init__(self, verbose_name=None, name=None, primary_key=False,
                 max_length=None, unique=False, blank=False, null=False,
                 db_index=False, rel=None, default=NOT_PROVIDED, editable=True,
                 serialize=True, unique_for_date=None, unique_for_month=None,
                 unique_for_year=None, choices=None, help_text='', db_column=None,
                 db_tablespace=None, auto_created=False, validators=(),
                 error_messages=None):
    pass(各种赋值,这里就不贴代码了)
```


字段检查内容:


```python
    #依次检查的内容
    def check(self, **kwargs):
        return [
            *self._check_field_name(),
            *self._check_choices(),
            *self._check_db_index(),
            *self._check_null_allowed_for_primary_keys(),
            *self._check_backend_specific_checks(**kwargs),
            *self._check_validators(),
            *self._check_deprecation_details(),
        ]
    #检查字段的正确性,不能以pk为名, 中间不能含有"__",且不能以"_"结尾
    def _check_field_name(self):
        """
        Check if field name is valid, i.e. 1) does not end with an
        underscore, 2) does not contain "__" and 3) is not "pk".
        """
        if self.name.endswith('_'):
            return [
                checks.Error(
                    'Field names must not end with an underscore.',
                    obj=self,
                    id='fields.E001',
                )
            ]
        elif LOOKUP_SEP in self.name:
            return [
                checks.Error(
                    'Field names must not contain "%s".' % (LOOKUP_SEP,),
                    obj=self,
                    id='fields.E002',
                )
            ]
        elif self.name == 'pk':
            return [
                checks.Error(
                    "'pk' is a reserved word that cannot be used as a field name.",
                    obj=self,
                    id='fields.E003',
                )
            ]
        else:
            return []

    #可选字段为一个可迭代的对象(且不能为string)
    def _check_choices(self):
        if self.choices:
            if isinstance(self.choices, str) or not is_iterable(self.choices):
                return [
                    checks.Error(
                        "'choices' must be an iterable (e.g., a list or tuple).",
                        obj=self,
                        id='fields.E004',
                    )
                ]
            elif any(isinstance(choice, str) or
                     not is_iterable(choice) or len(choice) != 2
                     for choice in self.choices):
                return [
                    checks.Error(
                        "'choices' must be an iterable containing "
                        "(actual value, human readable name) tuples.",
                        obj=self,
                        id='fields.E005',
                    )
                ]
            else:
                return []
        else:
            return []
    #
    def _check_db_index(self):
        if self.db_index not in (None, True, False):
            return [
                checks.Error(
                    "'db_index' must be None, True or False.",
                    obj=self,
                    id='fields.E006',
                )
            ]
        else:
            return []
    #主键检查,可空检查
    def _check_null_allowed_for_primary_keys(self):
        if (self.primary_key and self.null and
                not connection.features.interprets_empty_strings_as_nulls):
            # We cannot reliably check this for backends like Oracle which
            # consider NULL and '' to be equal (and thus set up
            # character-based fields a little differently).
            return [
                checks.Error(
                    'Primary keys must not have null=True.',
                    hint=('Set null=False on the field, or '
                          'remove primary_key=True argument.'),
                    obj=self,
                    id='fields.E007',
                )
            ]
        else:
            return []

    def _check_backend_specific_checks(self, **kwargs):
        app_label = self.model._meta.app_label
        for db in connections:
            if router.allow_migrate(db, app_label, model_name=self.model._meta.model_name):
                return connections[db].validation.check_field(self, **kwargs)
        return []

    def _check_validators(self):
        errors = []
        for i, validator in enumerate(self.validators):
            if not callable(validator):
                errors.append(
                    checks.Error(
                        "All 'validators' must be callable.",
                        hint=(
                            "validators[{i}] ({repr}) isn't a function or "
                            "instance of a validator class.".format(
                                i=i, repr=repr(validator),
                            )
                        ),
                        obj=self,
                        id='fields.E008',
                    )
                )
        return errors

    def _check_deprecation_details(self):
        if self.system_check_removed_details is not None:
            return [
                checks.Error(
                    self.system_check_removed_details.get(
                        'msg',
                        '%s has been removed except for support in historical '
                        'migrations.' % self.__class__.__name__
                    ),
                    hint=self.system_check_removed_details.get('hint'),
                    obj=self,
                    id=self.system_check_removed_details.get('id', 'fields.EXXX'),
                )
            ]
        elif self.system_check_deprecated_details is not None:
            return [
                checks.Warning(
                    self.system_check_deprecated_details.get(
                        'msg',
                        '%s has been deprecated.' % self.__class__.__name__
                    ),
                    hint=self.system_check_deprecated_details.get('hint'),
                    obj=self,
                    id=self.system_check_deprecated_details.get('id', 'fields.WXXX'),
                )
            ]
        return []

```

其他方法,field其实是一个父类,很多内容需要在子类中依次实现:

```python
    # 将字段的字符串值转换成python类型        
    def to_python(self, value):
        pass
    # 默认和自定义的validator处理 
    def run_validators(self, value):
        pass
    def validate(self, value, model_instance):
    # 验证字段合法性，如是否在choices中

    # 当类调用clean()或者is_valid()的时候会触发         
    def clean(self, value, model_instance):
        value = self.to_python(value)
        self.validate(value, model_instance)
        self.run_validators(value)
        return value
    # 将特殊定义语法装换成prepared语法。如“A_startswith="hello"”换成“ where `A` is like "hello%"”
    def get_db_prep_value(self, value, connection, prepared=False):
        pass
    # 获取form字段
    def formfield(self, form_class=forms.CharField, **kwargs):
        pass
```


###一些子类的部分实现方法:
(直接调用父类方法的就不贴代码了)


####BooleanField


```python
#将字符串转化为true or false
    def to_python(self, value):
        if value in (True, False):
            # if value is 1 or 0 than it's equal to True or False, but we want
            # to return a true bool for semantic reasons.
            return bool(value)
        if value in ('t', 'True', '1'):
            return True
        if value in ('f', 'False', '0'):
            return False
        raise exceptions.ValidationError(
            self.error_messages['invalid'],
            code='invalid',
            params={'value': value},
        )

```


####CharField(我们最常用的字段类型之一)


```python
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.validators.append(validators.MaxLengthValidator(self.max_length))
```

在检查字段的时候char字段需要再次检查 string的最大长度


####datetime的check

```python

class DateTimeCheckMixin:

    def check(self, **kwargs):
        return [
            *super().check(**kwargs),
            *self._check_mutually_exclusive_options(),
            *self._check_fix_default_value(),
        ]
    #datetime字段不能 有auto_now_add,auto_now,has_default只能有一个
    def _check_mutually_exclusive_options(self):
        # auto_now, auto_now_add, and default are mutually exclusive
        # options. The use of more than one of these options together
        # will trigger an Error
        mutually_exclusive_options = [self.auto_now_add, self.auto_now, self.has_default()]
        enabled_options = [option not in (None, False) for option in mutually_exclusive_options].count(True)
        if enabled_options > 1:
            return [
                checks.Error(
                    "The options auto_now, auto_now_add, and default "
                    "are mutually exclusive. Only one of these options "
                    "may be present.",
                    obj=self,
                    id='fields.E160',
                )
            ]
        else:
            return []

    def _check_fix_default_value(self):
        return []

```



```pyuthon
class DateField(DateTimeCheckMixin, Field):


    #转化为时间对象
       def to_python(self, value):
        if value is None:
            return value
        if isinstance(value, datetime.datetime):
            if settings.USE_TZ and timezone.is_aware(value):
                # Convert aware datetimes to the default time zone
                # before casting them to dates (#17742).
                default_timezone = timezone.get_default_timezone()
                value = timezone.make_naive(value, default_timezone)
            return value.date()
        if isinstance(value, datetime.date):
            return value

        try:
            parsed = parse_date(value)
            if parsed is not None:
                return parsed
        except ValueError:
            raise exceptions.ValidationError(
                self.error_messages['invalid_date'],
                code='invalid_date',
                params={'value': value},
            )

        raise exceptions.ValidationError(
            self.error_messages['invalid'],
            code='invalid',
            params={'value': value},
        )
```



####整型

```python
class IntegerField(Field):
    empty_strings_allowed = False
    default_error_messages = {
        'invalid': _("'%(value)s' value must be an integer."),
    }
    description = _("Integer")

    def check(self, **kwargs):
        return [
            *super().check(**kwargs),
            *self._check_max_length_warning(),
        ]

    def _check_max_length_warning(self):
        if self.max_length is not None:
            return [
                checks.Warning(
                    "'max_length' is ignored when used with IntegerField",
                    hint="Remove 'max_length' from field",
                    obj=self,
                    id='fields.W122',
                )
            ]
        return []

    @cached_property
    def validators(self):
        # These validators can't be added at field initialization time since
        # they're based on values retrieved from `connection`.
        validators_ = super().validators
        internal_type = self.get_internal_type()
        min_value, max_value = connection.ops.integer_field_range(internal_type)
        if (min_value is not None and not
            any(isinstance(validator, validators.MinValueValidator) and
                validator.limit_value >= min_value for validator in validators_)):
            validators_.append(validators.MinValueValidator(min_value))
        if (max_value is not None and not
            any(isinstance(validator, validators.MaxValueValidator) and
                validator.limit_value <= max_value for validator in validators_)):
            validators_.append(validators.MaxValueValidator(max_value))
        return validators_

    def get_prep_value(self, value):
        value = super().get_prep_value(value)
        if value is None:
            return None
        return int(value)

    def get_internal_type(self):
        return "IntegerField"

    def to_python(self, value):
        if value is None:
            return value
        try:
            return int(value)
        except (TypeError, ValueError):
            raise exceptions.ValidationError(
                self.error_messages['invalid'],
                code='invalid',
                params={'value': value},
            )

    def formfield(self, **kwargs):
        return super().formfield(**{
            'form_class': forms.IntegerField,
            **kwargs,
        })


```


