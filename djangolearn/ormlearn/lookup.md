# 查找api(fieldname__lookup)中的lookup选项




两部分:
* RegisterLookupMixin类,用于注册查找
* Query Expression APi,方法集,实现它才能成为一个LookUp



Django 两个类:

* Lookup(查找一个字段)
* Transform(转换一个字段)


Query Expression 分为三部分:

1. 字段部分
2. 转换部分(可以省略),比如(__lower)
3. 查找部分(__icontains)



##Query Expression API


(1)as_sql

负责从表达式中产生查询字符串和参数。compiler是一个SQLCompiler对象，它拥有可以编译其它表达式的compile()方法。connection是用于执行查询的连接。

(2)as_vendorname

获取后端名字

(3)get_lookup(lookup_name)
获取lookup_name的 lookup对象

(4)get_transform(transform_name)

(5)output_field

定义get_lookup()方法返回的类的类型,必须是Field的实例


##Transform类

Transform是用于实现字段转换的通用类。一个显然的例子是__year会把DateField转换为IntegerField。



##Lookup类参考:

在表达式中lookup的标记为:<lhs>__<lookup_name>==<rhs>

* process_lhs(compiler, connection[, lhs=None])


返回元组(lhs_string, lhs_params)，和compiler.compile(lhs)所返回的一样。这个方法可以被覆写，来调整lhs的处理方式。

* process_rhs(compiler, connection)

右边


