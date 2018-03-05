python中 list的实现
---
python中的LIST非常强大,它既有数组的下标查询优势,
又有链表这样动态增减的高速率;

列表对象的C语言结构体:

```c
#define PyObject_VAR_HEAD      PyVarObject ob_base;
typedef struct {
    PyObject ob_base;
    //ob_size为每个列表元素的大小
    Py_ssize_t ob_size; 
    } PyVarObject;
    
    
    
    typedef struct {
    PyObject_VAR_HEAD
    /* Vector of pointers to list elements.  list[0] is ob_item[0], etc. */
    //ob_item是一个指针数组,[i]代表了每个对象
    PyObject **ob_item;

    /* ob_item contains space for 'allocated' elements.  The number
     * currently in use is ob_size.
     * Invariants:
     *     0 <= ob_size <= allocated
     *     len(list) == ob_size
     *     ob_item == NULL implies ob_size == allocated == 0
     * list.sort() temporarily sets allocated to -1 to detect mutations.
     *
     * Items must normally not be NULL, except during construction when
     * the list is not yet visible outside the function that builds it.
     */
    Py_ssize_t allocated;
} PyListObject;
```


满足条件:

1.  0 <= ob_size <= allocated
2.  len(list) == ob_size
3.  ob_item == NULL 时 ob_size == allocated == 0

注意:allocated是申请的总内存的大小



ref_count,ob_size,allocated, ob_item   ->  list[] 
列表对象的创建:

```c
// 列表缓冲池, PyList_MAXFREELIST为80
static PyListObject *free_list[PyList_MAXFREELIST];
//缓冲池当前大小
static int numfree = 0;

PyObject *
PyList_New(Py_ssize_t size)
{
    PyListObject *op;
#ifdef SHOW_ALLOC_COUNT
    static int initialized = 0;
    if (!initialized) {
        Py_AtExit(show_alloc);
        initialized = 1;
    }
#endif

    if (size < 0) {
        PyErr_BadInternalCall();
        return NULL;
    }

    //缓冲池是否有空余的List对象,直接从缓冲池获取list对象
    if (numfree) {
        numfree--;
        op = free_list[numfree];
        //改变引用计数
        _Py_NewReference((PyObject *)op);
#ifdef SHOW_ALLOC_COUNT
        count_reuse++;
#endif
    } else {
        //从内存申请一块给list
        op = PyObject_GC_New(PyListObject, &PyList_Type);
        if (op == NULL)
            return NULL;
#ifdef SHOW_ALLOC_COUNT
        count_alloc++;
#endif
    }
    if (size <= 0)
        op->ob_item = NULL;
    else {
        //再申请size大小的内存给ob_item
        op->ob_item = (PyObject **) PyMem_Calloc(size, sizeof(PyObject *));
        if (op->ob_item == NULL) {
            Py_DECREF(op);
            return PyErr_NoMemory();
        }
    }
    Py_SIZE(op) = size;
    op->allocated = size;
    _PyObject_GC_TRACK(op);
    return (PyObject *) op;
}
```

创建的过程:
1. 检查size参数是否有效，如果小于0，直接返回NULL，创建失败
2. 检查size参数是否超出Python所能接受的大小，如果大于PY_SIZE_MAX（64位机器为8字节，在32位机器为4字节），内存溢出。
3. 检查缓冲池free_list是否有可用的对象，有则直接从缓冲池中使用，没有则创建新的PyListObject，分配内存。
4. 初始化ob_item中的元素的值为Null
5. 设置PyListObject的allocated和ob_size。

list_dealloc函数,用来销毁列表返回内存给缓冲池:

```c
static void
list_dealloc(PyListObject *op)
{
    Py_ssize_t i;
    PyObject_GC_UnTrack(op);//拆包检查
    Py_TRASHCAN_SAFE_BEGIN(op)
    if (op->ob_item != NULL) {
       //如果不是空的列表
        i = Py_SIZE(op);//获取列表长度
        while (--i >= 0) {
            Py_XDECREF(op->ob_item[i]);//列表中所有元素的引用计数减一
        }
        PyMem_FREE(op->ob_item);//释放ob_item的内存
    }
    if (numfree < PyList_MAXFREELIST && PyList_CheckExact(op))
        free_list[numfree++] = op;
        //如果当前缓冲区还有位置,将op直接放到缓冲区,免得重复申请新内存来new 一个List (为什么能直接归还,因为每个listobject不同的地方在于ob-item ,其他属性可以在从缓冲区拿出来的时候赋值变化,避免了多次malloc)
        //（此时PyListObject占用的内存并不会正真正回收给系统，下次创建PyListObject优先从缓冲池中获取PyListObject）
    else
        Py_TYPE(op)->tp_free((PyObject *)op);//没有就直接归还整个结构体的内存
    Py_TRASHCAN_SAFE_END(op)
}
}
```

当PyListObject对象被销毁的时候，首先将列表中所有元素的引用计数减一，然后释放ob_item占用的内存，只要缓冲池空间还没满，那么就把该PyListObject加入到缓冲池中（此时PyListObject占用的内存并不会正真正回收给系统，下次创建PyListObject优先从缓冲池中获取PyListObject），否则释放PyListObject对象的内存空间。



查看列表的某个下标元素值的时候:

```c
PyObject *
PyList_GetItem(PyObject *op, Py_ssize_t i)
{
    if (!PyList_Check(op)) {
        PyErr_BadInternalCall();
        return NULL;
    }
    if (i < 0 || i >= Py_SIZE(op)) {
        if (indexerr == NULL) {
            indexerr = PyString_FromString(
                "list index out of range");
            if (indexerr == NULL)
                return NULL;
        }
        PyErr_SetObject(PyExc_IndexError, indexerr);
        return NULL;
    }
    return ((PyListObject *)op) -> ob_item[i];
}
```

直接检查是否越界,没越界直接返回ob_item[i]所在元素,跟普通数组类似


list 位置调整,这段代码解释了Python 动态调整的原理

```c
static int
list_resize(PyListObject *self, Py_ssize_t newsize)
{
    PyObject **items;
    size_t new_allocated,num_allocated_bytes;
    Py_ssize_t allocated = self->allocated;

 //当 newsize  位于当前大小的一半以上时候,将list大小变为newsize
    if (allocated >= newsize && newsize >= (allocated >> 1)) {
        assert(self->ob_item != NULL || newsize == 0);
        Py_SIZE(self) = newsize;
        return 0;
    }

//需要增大列表的时候,这与列表大小成比例地分配，
//创造空间进一步增长。 过度分配是温和的.
//新增的长度 趋势是  0,4,8,16,25,35,46
    new_allocated = (newsize >> 3) + (newsize < 9 ? 3 : 6);
    /* check for integer overflow */
    if (new_allocated > PY_SIZE_MAX - newsize) {
        PyErr_NoMemory();
        return -1;
    } else {
        new_allocated += newsize;
    }

    if (newsize == 0)
        new_allocated = 0;
    num_allocated_bytes = new_allocated * sizeof(PyObject *);
    items = (PyObject **)PyMem_Realloc(self->ob_item, num_allocated_bytes);
    if (items == NULL) {
        PyErr_NoMemory();
        return -1;
    }
    self->ob_item = items;
    Py_SIZE(self) = newsize;
    self->allocated = new_allocated;
    return 0;
}
```


list_resize() 函数。**它会多申请一些内存**，避免频繁调用 list_resize() 函数。列表的增长模式为：0，4，8，16，25，35，46，58，72，88

插入:

```c
static int
app1(PyListObject *self, PyObject *v)
{
    Py_ssize_t n = PyList_GET_SIZE(self);//获取list 大小

    assert (v != NULL);
    if (n == PY_SSIZE_T_MAX) {
        PyErr_SetString(PyExc_OverflowError,
            "cannot add more objects to list");
        return -1;
    }//如果超过List 长度,则报错

    if (list_resize(self, n+1) == -1)
        return -1;
//调整list大小,增添一个空间的(实际上是得到4个新增空间)
// new_allocated = (newsize >> 3) + (newsize < 9 ? 3 : 6);
//new_allocated+=newsize
    Py_INCREF(v);
    PyList_SET_ITEM(self, n, v);
    return 0;
//增加引用,加一
}
```
append 方法  实现
```
int
PyList_Append(PyObject *op, PyObject *newitem)
{
//引用app1 然后将元素添加到最后一位
    if (PyList_Check(op) && (newitem != NULL))
        return app1((PyListObject *)op, newitem);
    PyErr_BadInternalCall();
    return -1;
}
```

现在分配了 4 个用来装列表元素的槽空间，并且第一个空间中为整数 1。如下图显示 l[0] 指向我们新添加的整数对象。虚线的方框表示已经分配但没有使用的槽空间。

列表追加元素操作的平均复杂度为 O(1)。

![image.png](http://upload-images.jianshu.io/upload_images/4824974-f081ec9152b3648a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
继续添加新的元素：l.append(2)。调用 list_resize 函数，参数为 n+1 = 2， 但是因为已经申请了 4 个槽空间，所以不需要再申请内存空间。再添加两个整数的情况也是一样的：l.append(3)，l.append(4)。下图显示了我们现在的情况:

![image.png](http://upload-images.jianshu.io/upload_images/4824974-2c22159e2fc2f927.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

插入算法:

```
static int
ins1(PyListObject *self, Py_ssize_t where, PyObject *v)
{
    Py_ssize_t i, n = Py_SIZE(self);
    PyObject **items;
    if (v == NULL) {
        PyErr_BadInternalCall();
        return -1;
    }
    if (n == PY_SSIZE_T_MAX) {
        PyErr_SetString(PyExc_OverflowError,
            "cannot add more objects to list");
        return -1;
    }

    if (list_resize(self, n+1) == -1)
        return -1;
//增加一个位置
    if (where < 0) {
        where += n;
//如果是倒数的位置,直接加长度
        if (where < 0)
            where = 0;
    }
//如果加上长度都小于0 ,证明越界了 只能变0
    if (where > n)
        where = n;
//如果是插入位置越界,只能放在最后,确定插入位置
    items = self->ob_item;
    for (i = n; --i >= where; )
        items[i+1] = items[i];
//复制列表的元素
    Py_INCREF(v);
    items[where] = v;
    return 0;
}
int
PyList_Insert(PyObject *op, Py_ssize_t where, PyObject *newitem)
{
    if (!PyList_Check(op)) {
        PyErr_BadInternalCall();
        return -1;
    }
    return ins1((PyListObject *)op, where, newitem);
}
```
插入是  ,,先确定插入位置,再新建列表保存之前的元素,新加插入元素到新的列表:

1.  resize n+1
2.  确定插入点
3.  插入点后所有元素后移
4.  执行插入


```c
remove 函数
static PyObject *
listremove(PyListObject *self, PyObject *v)
{
    Py_ssize_t i;

    for (i = 0; i < Py_SIZE(self); i++) {
        int cmp = PyObject_RichCompareBool(self->ob_item[i], v, Py_EQ);
        if (cmp > 0) {
            if (list_ass_slice(self, i, i+1,
                               (PyObject *)NULL) == 0)
                Py_RETURN_NONE;
            return NULL;
        }
        else if (cmp < 0)
            return NULL;
    }
    PyErr_SetString(PyExc_ValueError, "list.remove(x): x not in list");
    return NULL;
}

```

为了做列表的切片并且删除元素，调用了 list_ass_slice() 函数，
1. 找到要删除元素位置
2.  删除之, 后面元素前移


```
Py_INCREF(pyObject *o) 增加该变量的引用
```

