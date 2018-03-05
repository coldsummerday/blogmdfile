##简介:
在Django中,sql语句的不同部分,又不同的类来负责拼接,比如:

* select部分
* where部分
* group_by部分
* having部分
等.


我们来探寻下**where**这个类,到底在Django orm系统中充当了怎样的螺丝钉作用.



##一、Tree.Node类
Tree.Node部分代码位于django.utils.tree.py中,该类类似于树的节点,用于创建各种表达式的嵌套,比如where表达式.

其初始化代码为:

```python
    def __init__(self, children=None, connector=None, negated=False):
        """Construct a new Node. If no connector is given, use the default."""
        self.children = children[:] if children else []
        self.connector = connector or self.default
        self.negated = negated
```


其children为子节点列表,connector是用于连接各个子表达式的连接词,在where类中为 'AND' 和 'OR'.negated变量表示当前表达式是否用否定.




###一、1.:add方法:


给node增加一个孩子是Tree.Node类的一个重要方法:

```python
    def add(self, data, conn_type, squash=True):
      
        if data in self.children:
            return data
        #参数squash为false的时候,代表了data可以直接加入到孩子中,无需处理
        if not squash:
            self.children.append(data)
            return data
        if self.connector == conn_type:
            # We can reuse self.children to append or squash the node other.
            #如果孩子是一个Node,且两者的connector相同的时候,直接加入到孩子列表中
            if (isinstance(data, Node) and not data.negated and
                    (data.connector == conn_type or len(data) == 1)):
                # We can squash the other node's children directly into this
                # node. We are just doing (AB)(CD) == (ABCD) here, with the
                # addition that if the length of the other node is 1 the
                # connector doesn't matter. However, for the len(self) == 1
                # case we don't want to do the squashing, as it would alter
                # self.connector.
                self.children.extend(data.children)
                return self
            else:
                # We could use perhaps additional logic here to see if some
                # children could be used for pushdown here.
                self.children.append(data)
                return data
        else:
            #否则的话,新建本类实例,并将该实例与data合并作为自己的孩子
            obj = self._new_instance(self.children, self.connector,
                                     self.negated)
            self.connector = conn_type
            self.children = [obj, data]
            return data

```

判断连接方式,数据根据连接方式的不同增添到node的孩子节点中;
注:
    如果当前需要加入的不是一个node,需要把当前类克隆一遍,然后把data跟克隆的类实例一起放入到孩子列表中(可能后续为了方便确定父子关系,列表第一个就为后续的父亲节点)    
    ##一、2 其他magic方法:

    ```python
        def _new_instance(cls, children=None, connector=None, negated=False):
        """
        Create a new instance of this class when new Nodes (or subclasses) are
        needed in the internal code in this class. Normally, it just shadows
        __init__(). However, subclasses with an __init__ signature that aren't
        an extension of Node.__init__ might need to implement this method to
        allow a Node to create a new instance of them (if they have any extra
        setting up to do).
        """
        #根据子类重新创建一个实例(Node)
        obj = Node(children, connector, negated)
        obj.__class__ = cls
        return obj

    #一个node的字符串形式表示为(%s:%s),如果否定的话,加not,,,,connector: children
    def __str__(self):
        template = '(NOT (%s: %s))' if self.negated else '(%s: %s)'
        return template % (self.connector, ', '.join(str(c) for c in self.children))

    #输出的时候为repr
    def __repr__(self):
        return "<%s: %s>" % (self.__class__.__name__, self)

    def __deepcopy__(self, memodict):
        obj = Node(connector=self.connector, negated=self.negated)
        obj.__class__ = self.__class__
        obj.children = copy.deepcopy(self.children, memodict)
        return obj

    def __len__(self):
        """Return the the number of children this node has."""
        return len(self.children)

    def __bool__(self):
        """Return whether or not this node has children."""
        return bool(self.children)

    def __contains__(self, other):
        """Return True if 'other' is a direct child of this instance."""
        return other in self.children

    def __eq__(self, other):
        return (
            self.__class__ == other.__class__ and
            (self.connector, self.negated) == (other.connector, other.negated) and
            self.children == other.children
        )

    def __hash__(self):
        return hash((self.__class__, self.connector, self.negated) + tuple(self.children))

    ```
    
    
##二、where对象:

该部分源代码位于:django.db.models.sql.where.py
    
    
where类继承于tree.Node类,主要实现将查询条件 经过sql.Query类的参数检查后,正确拼接成一个sql语句.


###二.1: split_having方法:

在where表达式中,我们需要知道该查询表达式,是否含有having对象(有的话需要join其他表格进行查询),所以理所应当我们需要将where对象中需要having对象的子节点;


```python
    # 分割成两个部分,一部分含有where ,另一部分是HAVING 语句
    def split_having(self, negated=False):
        """
        Return two possibly None nodes: one for those parts of self that
        should be included in the WHERE clause and one for those parts of
        self that must be included in the HAVING clause.
        """

        #如果没有聚合操作aggregate,证明sql语句没having,返回自身where
        if not self.contains_aggregate:
            return self, None
        in_negated = negated ^ self.negated
        # If the effective connector is OR and this node contains an aggregate,
        # then we need to push the whole branch to HAVING clause.
        #当自身否定与connector不一致的时候,需要分裂
        may_need_split = (
            (in_negated and self.connector == AND) or
            (not in_negated and self.connector == OR))
        if may_need_split and self.contains_aggregate:
            return None, self
        where_parts = []
        having_parts = []
        for c in self.children:
            #如果子节点有需要分离的having,需要将其分离
            if hasattr(c, 'split_having'):
                where_part, having_part = c.split_having(in_negated)
                if where_part is not None:
                    where_parts.append(where_part)
                if having_part is not None:
                    having_parts.append(having_part)
            #aggregate操作在sql中映射为having操作
            elif c.contains_aggregate:
                having_parts.append(c)
            else:
                where_parts.append(c)
        ##根据这些分离开的各个部分,新建不同的类
        having_node = self.__class__(having_parts, self.connector, self.negated) if having_parts else None
        where_node = self.__class__(where_parts, self.connector, self.negated) if where_parts else None
        return where_node, having_node

```

###二、2 as_sql()方法:

该方法是主要的拼接sql对象的方法:

```python
    def as_sql(self, compiler, connection):
        """
        Return the SQL version of the where clause and the value to be
        substituted in. Return '', [] if this node matches everything,
        None, [] if this node is empty, and raise EmptyResultSet if this
        node can't match anything.
        """
        result = []
        result_params = []
        if self.connector == AND:
            full_needed, empty_needed = len(self.children), 1
        else:
            full_needed, empty_needed = 1, len(self.children)

        #编译每一个子节点语句,增加到result中
        for child in self.children:
            try:
                sql, params = compiler.compile(child)
            except EmptyResultSet:
                empty_needed -= 1
            else:
                if sql:
                    result.append(sql)
                    result_params.extend(params)
                else:
                    full_needed -= 1
            # Check if this node matches nothing or everything.
            # First check the amount of full nodes and empty nodes
            # to make this node empty/full.
            # Now, check if this node is full/empty using the
            # counts.
            if empty_needed == 0:
                if self.negated:
                    return '', []
                else:
                    raise EmptyResultSet
            if full_needed == 0:
                if self.negated:
                    raise EmptyResultSet
                else:
                    return '', []
        #用and或者or连接各个where部分
        conn = ' %s ' % self.connector
        sql_string = conn.join(result)
        if sql_string:
            if self.negated:
                # Some backends (Oracle at least) need parentheses
                # around the inner SQL in the negated case, even if the
                # inner SQL contains just a single expression.
                #否定部分
                sql_string = 'NOT (%s)' % sql_string
            elif len(result) > 1 or self.resolved:
                sql_string = '(%s)' % sql_string
        return sql_string, result_params
```

* 根据自身连接符的不同(and ,or),确定该节点需要连接的次数
* 编译每一个孩子节点的sql语句(调用compiler.compile()方法)
* 用连接符连接个对象
* 最后确定是否需要否定(加"NOT")


###二、3 :其他方法:

```python
    def get_group_by_cols(self):
        #一直获取子节点的col,变为一个列表
        cols = []
        for child in self.children:
            cols.extend(child.get_group_by_cols())
        return cols

    def get_source_expressions(self):
        #获取孩子节点的表达式
        return self.children[:]

    def set_source_expressions(self, children):
        assert len(children) == len(self.children)
        self.children = children

    def relabel_aliases(self, change_map):
        """
        Relabel the alias values of any children. 'change_map' is a dictionary
        mapping old (current) alias values to the new values.
        """

        #给孩子节点创建map对应关系
        for pos, child in enumerate(self.children):
            if hasattr(child, 'relabel_aliases'):
                # For example another WhereNode
                child.relabel_aliases(change_map)
            elif hasattr(child, 'relabeled_clone'):
                #克隆一个关联表到每一个子节点中
                self.children[pos] = child.relabeled_clone(change_map)

    def clone(self):
        """
        Create a clone of the tree. Must only be called on root nodes (nodes
        with empty subtree_parents). Childs must be either (Contraint, lookup,
        value) tuples, or objects supporting .clone().
        """
        clone = self.__class__._new_instance(
            children=[], connector=self.connector, negated=self.negated)
        for child in self.children:
            if hasattr(child, 'clone'):
                clone.children.append(child.clone())
            else:
                clone.children.append(child)
        return clone

    def relabeled_clone(self, change_map):
        clone = self.clone()
        clone.relabel_aliases(change_map)
        return clone

    @classmethod
    def _contains_aggregate(cls, obj):
        if isinstance(obj, tree.Node):
            return any(cls._contains_aggregate(c) for c in obj.children)
        return obj.contains_aggregate

    @cached_property
    def contains_aggregate(self):
        return self._contains_aggregate(self)

    @classmethod
    def _contains_over_clause(cls, obj):
        if isinstance(obj, tree.Node):
            return any(cls._contains_over_clause(c) for c in obj.children)
        return obj.contains_over_clause

    @cached_property
    def contains_over_clause(self):
        return self._contains_over_clause(self)

    @property
    def is_summary(self):
        return any(child.is_summary for child in self.children)

    def resolve_expression(self, *args, **kwargs):
        clone = self.clone()
        clone.resolved = True
        return clone

```


    
    
     


