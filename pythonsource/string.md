##简介:


在python3中,所有的string都用byte和unicode去管理


所以关于字符串部分的代码位于bytesobject,unicodeobject.

##byteobject
###一.结构体与声明
关于pybytesObject的定义:

```c
typedef struct {
    PyObject_VAR_HEAD
    Py_hash_t ob_shash;
    char ob_sval[1];

    /* Invariants:
     *     ob_sval contains space for 'ob_size+1' elements.
     *     ob_sval[ob_size] == 0.
     *     ob_shash is the hash of the string or -1 if not computed yet.
     */
} PyBytesObject;
```


* 其中PyObject_VAR_HEAD代表了一个PyVarObject对象,中间存储了ob_size对象中维护的可变长度内存的大小.

* ob_sval是一个字符的字符数组,实际上是作为一个字符指针指向一段内存的,这段内存保存了这个字符串对象维护的实际字符串;
* ob_sval指向的是ob_size+1个字节的内存,而且必须满足ob_sval[ob_size]=='\0'
* ob_hash为哈希值,如果没被计算,则为-1


```c
PyTypeObject PyBytes_Type = {
    PyVarObject_HEAD_INIT(&PyType_Type, 0)
    "bytes",
    PyBytesObject_SIZE,
    sizeof(char),
    bytes_dealloc,                      /* tp_dealloc */
    0,                                          /* tp_print */
    0,                                          /* tp_getattr */
    0,                                          /* tp_setattr */
    0,                                          /* tp_reserved */
    (reprfunc)bytes_repr,                       /* tp_repr */
    &bytes_as_number,                           /* tp_as_number */
    &bytes_as_sequence,                         /* tp_as_sequence */
    &bytes_as_mapping,                          /* tp_as_mapping */
    (hashfunc)bytes_hash,                       /* tp_hash */
    0,                                          /* tp_call */
    bytes_str,                                  /* tp_str */
    PyObject_GenericGetAttr,                    /* tp_getattro */
    0,                                          /* tp_setattro */
    &bytes_as_buffer,                           /* tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE |
        Py_TPFLAGS_BYTES_SUBCLASS,              /* tp_flags */
    bytes_doc,                                  /* tp_doc */
    0,                                          /* tp_traverse */
    0,                                          /* tp_clear */
    (richcmpfunc)bytes_richcompare,             /* tp_richcompare */
    0,                                          /* tp_weaklistoffset */
    bytes_iter,                                 /* tp_iter */
    0,                                          /* tp_iternext */
    bytes_methods,                              /* tp_methods */
    0,                                          /* tp_members */
    0,                                          /* tp_getset */
    &PyBaseObject_Type,                         /* tp_base */
    0,                                          /* tp_dict */
    0,                                          /* tp_descr_get */
    0,                                          /* tp_descr_set */
    0,                                          /* tp_dictoffset */
    0,                                          /* tp_init */
    0,                                          /* tp_alloc */
    bytes_new,                                  /* tp_new */
    PyObject_Del,                               /* tp_free */
};

```

整个bytes对象大小为:ob_sval的大小加一(巧妙的运用了offsetof宏)

```c
//offsetof是用来判断结构体中成员的偏移位置
#define PyBytesObject_SIZE (offsetof(PyBytesObject, ob_sval) + 1)
```

而单个byte的大小为:sizeof(char),即一个c语言中 char的大小.

在python3中,任意一个变长对象,tp_itemsize都必须设置,指明了由变长对象保存的元素(item)的单位长度


###二、创建:


####二.1 PyBytes_FromString

该方法从一个c语言的str中创建一个bytes对象:

```c
PyObject *
PyBytes_FromString(const char *str)
{
    size_t size;
    PyBytesObject *op;

    assert(str != NULL);
    size = strlen(str);
    //字符串超过长度
    if (size > PY_SSIZE_T_MAX - PyBytesObject_SIZE) {
        PyErr_SetString(PyExc_OverflowError,
            "byte string is too long");
        return NULL;
    }
    //如果是一个空的字符串
    if (size == 0 && (op = nullstring) != NULL) {
#ifdef COUNT_ALLOCS
        null_strings++;
#endif
        Py_INCREF(op);
        return (PyObject *)op;
    }
    //处理单个字符的情况(缓存池中获取)
    if (size == 1 && (op = characters[*str & UCHAR_MAX]) != NULL) {
#ifdef COUNT_ALLOCS
        one_strings++;
#endif
        Py_INCREF(op);
        return (PyObject *)op;
    }

    //创建新的pystringObject对象,并初始化
    /* Inline PyObject_NewVar */
    op = (PyBytesObject *)PyObject_MALLOC(PyBytesObject_SIZE + size);
    if (op == NULL)
        return PyErr_NoMemory();
    (void)PyObject_INIT_VAR(op, &PyBytes_Type, size);
    op->ob_shash = -1;
    //将str拷贝到op->ob_sval上
    memcpy(op->ob_sval, str, size+1);
    //长度为0或者1的字符从缓冲池共享
    /* share short strings */
    if (size == 0) {
        nullstring = op;
        Py_INCREF(op);
    } else if (size == 1) {
        characters[*str & UCHAR_MAX] = op;
        Py_INCREF(op);
    }
    return (PyObject *) op;
}

```

我们看到0或者1的字符串是直接被python3虚拟机的内存池所缓存的.
同时,python3会维护一个叫nullstring的(pyBytesObject)指针,专门负责空的字符数组


注意,从str创建一个bytes需要传入一个结尾为'\0'的字符串;


假如我们创建一个"Python"的bytes,则内存分布如图:

![](http://orh99zlhi.bkt.clouddn.com/2018-03-02,17:55:01.jpg)


####二.2_PyBytes_FromSize


```c
static PyObject *
_PyBytes_FromSize(Py_ssize_t size, int use_calloc)
{
    //申请一块size大小的内存给byteObject
    PyBytesObject *op;
    assert(size >= 0);

    if (size == 0 && (op = nullstring) != NULL) {
#ifdef COUNT_ALLOCS
        null_strings++;
#endif
        Py_INCREF(op);
        return (PyObject *)op;
    }

    if ((size_t)size > (size_t)PY_SSIZE_T_MAX - PyBytesObject_SIZE) {
        PyErr_SetString(PyExc_OverflowError,
                        "byte string is too large");
        return NULL;
    }

    /* Inline PyObject_NewVar */
    if (use_calloc)
        //是否从内存池中提取数字
        op = (PyBytesObject *)PyObject_Calloc(1, PyBytesObject_SIZE + size);
    else
        op = (PyBytesObject *)PyObject_Malloc(PyBytesObject_SIZE + size);
    if (op == NULL)
        return PyErr_NoMemory();
    (void)PyObject_INIT_VAR(op, &PyBytes_Type, size);
    op->ob_shash = -1;
    //将字符的最后表示为'\0'代表字符串的结束
    if (!use_calloc)
        op->ob_sval[size] = '\0';
    /* empty byte string singleton */
    if (size == 0) {
        nullstring = op;
        Py_INCREF(op);
    }
    return (PyObject *) op;
}
```

该方法为申请一块size的内存给pybyteobject用


###二.2PyBytes_FromStringAndSize

该方法初始化一个string的时候,并不要求传入字符串最后为"\0",而是根据传入的size参数决定拷贝的字符串长度

```c
PyObject *
PyBytes_FromStringAndSize(const char *str, Py_ssize_t size)
{
    PyBytesObject *op;
    if (size < 0) {
        PyErr_SetString(PyExc_SystemError,
            "Negative size passed to PyBytes_FromStringAndSize");
        return NULL;
    }
    //单字符情况
    if (size == 1 && str != NULL &&
        (op = characters[*str & UCHAR_MAX]) != NULL)
    {
#ifdef COUNT_ALLOCS
        one_strings++;
#endif
        Py_INCREF(op);
        return (PyObject *)op;
    }
    //申请内存到pybyteobject对象中
    op = (PyBytesObject *)_PyBytes_FromSize(size, 0);
    if (op == NULL)
        return NULL;
    if (str == NULL)
        return (PyObject *) op;
    //拷贝str到op中
    memcpy(op->ob_sval, str, size);
    /* share short strings */
    if (size == 1) {
        characters[*str & UCHAR_MAX] = op;
        Py_INCREF(op);
    }
    return (PyObject *) op;
}
```



可能有朋友会问:python2不是对短的string实现一个叫intern机制吗?它在哪儿?


在python3中,byte对象只对长度为0,1的对象直接缓存了,0的为nullstring,1的直接放入数组characters中,存放位置为[*str & UCHAR_MAX]


而真正在unicodeobject中才实现了intern缓存机制(即创建过的短字符串直接缓存在虚拟机中).

###三.拼接:


'+' 拼接涉及了三个方法:

* PyBytes_Concat(检查前字符串是否为一次计数,是的话调整大小,然后copy字符串B到A的后面,然后调整计数,释放B内存)
* _PyBytes_Resize(调整一个bytesobject的ob_size)
* bytes_concat(直接申请一块大内存的pybytesobject对象,然后把两个拼接的字符串copy到对象上)


三个函数的源代码:

```c
static PyObject *
bytes_concat(PyObject *a, PyObject *b)
{
    /*字符串拼接
     * 就是简单的建个size=a.len+b.len的object,
     * 然后依次copy a,b到新的对象中,返回拼接好的object

     */

    Py_buffer va, vb;
    PyObject *result = NULL;

    va.len = -1;
    vb.len = -1;
    if (PyObject_GetBuffer(a, &va, PyBUF_SIMPLE) != 0 ||
        PyObject_GetBuffer(b, &vb, PyBUF_SIMPLE) != 0) {
        PyErr_Format(PyExc_TypeError, "can't concat %.100s to %.100s",
                     Py_TYPE(b)->tp_name, Py_TYPE(a)->tp_name);
        goto done;
    }

    /* Optimize end cases */
    if (va.len == 0 && PyBytes_CheckExact(b)) {
        result = b;
        Py_INCREF(result);
        goto done;
    }
    if (vb.len == 0 && PyBytes_CheckExact(a)) {
        result = a;
        Py_INCREF(result);
        goto done;
    }

    if (va.len > PY_SSIZE_T_MAX - vb.len) {
        PyErr_NoMemory();
        goto done;
    }

    result = PyBytes_FromStringAndSize(NULL, va.len + vb.len);
    if (result != NULL) {
        memcpy(PyBytes_AS_STRING(result), va.buf, va.len);
        memcpy(PyBytes_AS_STRING(result) + va.len, vb.buf, vb.len);
    }

  done:
    if (va.len != -1)
        PyBuffer_Release(&va);
    if (vb.len != -1)
        PyBuffer_Release(&vb);
    return result;
}


void
PyBytes_Concat(PyObject **pv, PyObject *w)
{
    assert(pv != NULL);
    if (*pv == NULL)
        return;
    if (w == NULL) {
        Py_CLEAR(*pv);
        return;
    }
    //要拼接的字符串引用只有一次,那么可以释放再申请大的内存,resize
    if (Py_REFCNT(*pv) == 1 && PyBytes_CheckExact(*pv)) {
        /* Only one reference, so we can resize in place */
        Py_ssize_t oldsize;
        Py_buffer wb;

        wb.len = -1;
        if (PyObject_GetBuffer(w, &wb, PyBUF_SIMPLE) != 0) {
            PyErr_Format(PyExc_TypeError, "can't concat %.100s to %.100s",
                         Py_TYPE(w)->tp_name, Py_TYPE(*pv)->tp_name);
            Py_CLEAR(*pv);
            return;
        }

        oldsize = PyBytes_GET_SIZE(*pv);
        if (oldsize > PY_SSIZE_T_MAX - wb.len) {
            PyErr_NoMemory();
            goto error;
        }
        //调整内存大小为pv原来的size+wb(要拼接的大小)
        if (_PyBytes_Resize(pv, oldsize + wb.len) < 0)
            goto error;
        //进行复制,并释放wb所占内存
        memcpy(PyBytes_AS_STRING(*pv) + oldsize, wb.buf, wb.len);
        PyBuffer_Release(&wb);
        return;

      error:
        PyBuffer_Release(&wb);
        Py_CLEAR(*pv);
        return;
    }

    else {
        /* Multiple references, need to create new object */
        PyObject *v;
        //如果不是一次引用的话,只能申请一个大的内存,然后返回v
        v = bytes_concat(*pv, w);
        Py_SETREF(*pv, v);
    }
}


int
_PyBytes_Resize(PyObject **pv, Py_ssize_t newsize)
{
    //将pv调整内存大小,实现原理:申请新的内存,再重新初始化py_bytes_object对象然后返回
    PyObject *v;
    PyBytesObject *sv;
    v = *pv;
    if (!PyBytes_Check(v) || newsize < 0) {
        goto error;
    }
    if (Py_SIZE(v) == newsize) {
        /* return early if newsize equals to v->ob_size */
        return 0;
    }
    if (Py_REFCNT(v) != 1) {
        goto error;
    }
    /* XXX UNREF/NEWREF interface should be more symmetrical */
    _Py_DEC_REFTOTAL;
    _Py_ForgetReference(v);
    *pv = (PyObject *)
        PyObject_REALLOC(v, PyBytesObject_SIZE + newsize);
    if (*pv == NULL) {
        PyObject_Del(v);
        PyErr_NoMemory();
        return -1;
    }
    _Py_NewReference(*pv);
    sv = (PyBytesObject *) *pv;
    Py_SIZE(sv) = newsize;
    sv->ob_sval[newsize] = '\0';
    sv->ob_shash = -1;          /* invalidate cached hash value */
    return 0;
error:
    *pv = 0;
    Py_DECREF(v);
    PyErr_BadInternalCall();
    return -1;
}
```



join拼接方式:

调用

```c
static PyObject *
bytes_join(PyBytesObject *self, PyObject *iterable_of_bytes)
/*[clinic end generated code: output=a046f379f626f6f8 input=7fe377b95bd549d2]*/
{
    return stringlib_bytes_join((PyObject*)self, iterable_of_bytes);
}

PyObject *
_PyBytes_Join(PyObject *sep, PyObject *x)
{
    assert(sep != NULL && PyBytes_Check(sep));
    assert(x != NULL);
    return bytes_join((PyBytesObject*)sep, x);
}
```


在cpython/Objects/stringlib/join.h中,我们找到了join方法的实现:

```c
Py_LOCAL_INLINE(PyObject *)
STRINGLIB(bytes_join)(PyObject *sep, PyObject *iterable)
{
    //获取连接部分的str
    char *sepstr = STRINGLIB_STR(sep);
    //长度
    const Py_ssize_t seplen = STRINGLIB_LEN(sep);
    PyObject *res = NULL;
    char *p;
    Py_ssize_t seqlen = 0;
    Py_ssize_t sz = 0;
    Py_ssize_t i, nbufs;
    PyObject *seq, *item;
    Py_buffer *buffers = NULL;
#define NB_STATIC_BUFFERS 10
    Py_buffer static_buffers[NB_STATIC_BUFFERS];
    //seq保存为需要连接的部分
    seq = PySequence_Fast(iterable, "can only join an iterable");
    if (seq == NULL) {
        return NULL;
    }

    seqlen = PySequence_Fast_GET_SIZE(seq);
    if (seqlen == 0) {
        Py_DECREF(seq);
        return STRINGLIB_NEW(NULL, 0);
    }
#ifndef STRINGLIB_MUTABLE
    if (seqlen == 1) {
        item = PySequence_Fast_GET_ITEM(seq, 0);
        if (STRINGLIB_CHECK_EXACT(item)) {
            Py_INCREF(item);
            Py_DECREF(seq);
            return item;
        }
    }
#endif
    if (seqlen > NB_STATIC_BUFFERS) {
        buffers = PyMem_NEW(Py_buffer, seqlen);
        if (buffers == NULL) {
            Py_DECREF(seq);
            PyErr_NoMemory();
            return NULL;
        }
    }
    else {
        buffers = static_buffers;
    }

    /* Here is the general case.  Do a pre-pass to figure out the total
     * amount of space we'll need (sz), and see whether all arguments are
     * bytes-like.
     */
    //检查iterable中每一项的类型,并计算需要申请的内存大小
    for (i = 0, nbufs = 0; i < seqlen; i++) {
        Py_ssize_t itemlen;
        item = PySequence_Fast_GET_ITEM(seq, i);
        if (PyBytes_CheckExact(item)) {
            /* Fast path. */
            Py_INCREF(item);
            buffers[i].obj = item;
            buffers[i].buf = PyBytes_AS_STRING(item);
            buffers[i].len = PyBytes_GET_SIZE(item);
        }
        else if (PyObject_GetBuffer(item, &buffers[i], PyBUF_SIMPLE) != 0) {
            PyErr_Format(PyExc_TypeError,
                         "sequence item %zd: expected a bytes-like object, "
                         "%.80s found",
                         i, Py_TYPE(item)->tp_name);
            goto error;
        }
        nbufs = i + 1;  /* for error cleanup */
        itemlen = buffers[i].len;
        if (itemlen > PY_SSIZE_T_MAX - sz) {
            PyErr_SetString(PyExc_OverflowError,
                            "join() result is too long");
            goto error;
        }
        sz += itemlen;
        if (i != 0) {
            if (seplen > PY_SSIZE_T_MAX - sz) {
                PyErr_SetString(PyExc_OverflowError,
                                "join() result is too long");
                goto error;
            }
            sz += seplen;
        }
        if (seqlen != PySequence_Fast_GET_SIZE(seq)) {
            PyErr_SetString(PyExc_RuntimeError,
                            "sequence changed size during iteration");
            goto error;
        }
    }
    //申请新的内存块
    /* Allocate result space. */
    res = STRINGLIB_NEW(NULL, sz);
    if (res == NULL)
        goto error;
    //copy到res中
    /* Catenate everything. */
    p = STRINGLIB_STR(res);
    if (!seplen) {
        /* fast path */
        for (i = 0; i < nbufs; i++) {
            Py_ssize_t n = buffers[i].len;
            char *q = buffers[i].buf;
            memcpy(p, q, n);
            p += n;
        }
        goto done;
    }
    for (i = 0; i < nbufs; i++) {
        Py_ssize_t n;
        char *q;
        if (i) {
            memcpy(p, sepstr, seplen);
            p += seplen;
        }
        n = buffers[i].len;
        q = buffers[i].buf;
        memcpy(p, q, n);
        p += n;
    }
    goto done;

error:
    res = NULL;
done:
    Py_DECREF(seq);
    for (i = 0; i < nbufs; i++)
        PyBuffer_Release(&buffers[i]);
    if (buffers != static_buffers)
        PyMem_FREE(buffers);
    return res;
}

```



执行join操作,会首先统计iterable中一共有多少个对象,每个对象的内存大小是多少,然后得到需要的内存大小,申请一块内存,一次copy到这块新内存中.(只进行了一次内存空间的申请)




##unicodeobject与intern

对于字符串的intern机制,它在python3的实现是在unicodeObject中:

cpython/Objects/unicodeobject.c


我们关注后缀为:**InternInPlace**的方法名字(因为python2就是用PyString_InternInPlace方法去实现intern机制的)

我们会发现有一个函数名叫:**PyUnicode_InternInPlace**的方法,
它在**PyUnicode_InternFromString**方法中使用:



猜想:每个字符串转unidcode的时候,短字符直接被intern缓存,以后


```c
PyObject *
PyUnicode_InternFromString(const char *cp)
{
   
    PyObject *s = PyUnicode_FromString(cp);
    if (s == NULL)
        return NULL;
    PyUnicode_InternInPlace(&s);
    return s;
}

void
PyUnicode_InternInPlace(PyObject **p)
{
    PyObject *s = *p;
    PyObject *t;
#ifdef Py_DEBUG
    assert(s != NULL);
    assert(_PyUnicode_CHECK(s));
#else
    if (s == NULL || !PyUnicode_Check(s))
        return;
#endif
    /* If it's a subclass, we don't really know what putting
       it in the interned dict might do. */
    //检查s的类型与状态
    if (!PyUnicode_CheckExact(s))
        return;
    if (PyUnicode_CHECK_INTERNED(s))
        return;
    //新建一个py字典对象interned,用来储存短字符串
    if (interned == NULL) {
        interned = PyDict_New();
        if (interned == NULL) {
            PyErr_Clear(); /* Don't leave an exception */
            return;
        }
    }
    Py_ALLOW_RECURSION
    //设置key跟value都是字符串s
    t = PyDict_SetDefault(interned, s, s);
    Py_END_ALLOW_RECURSION
    if (t == NULL) {
        PyErr_Clear();
        return;
    }
    if (t != s) {
        Py_INCREF(t);
        //转变为p,t的引用,返回
        Py_SETREF(*p, t);
        return;
    }
    /* The two references in interned are not counted by refcnt.
       The deallocator will take care of this */
    //因为设置key跟value的时候多了两次计数,但是这两次计数不应该算入正常计数,否则永远不会被释放内存
    Py_REFCNT(s) -= 2;
    //设置被缓存的s的状态为SSTATE_INTERNED_MORTAL,方便free的时候管理
    _PyUnicode_STATE(s).interned = SSTATE_INTERNED_MORTAL;
}


static void
unicode_dealloc(PyObject *unicode)
{
    switch (PyUnicode_CHECK_INTERNED(unicode)) {
    case SSTATE_NOT_INTERNED:
        break;

    case SSTATE_INTERNED_MORTAL:
        /* revive dead object temporarily for DelItem */
        //被缓存对象的处理,
        Py_REFCNT(unicode) = 3;
        if (PyDict_DelItem(interned, unicode) != 0)
            Py_FatalError(
                "deletion of interned string failed");
        break;

    case SSTATE_INTERNED_IMMORTAL:
        Py_FatalError("Immortal interned string died.");
        /* fall through */

    default:
        Py_FatalError("Inconsistent interned string state.");
    }
    //del 不同的unicode对象
    if (_PyUnicode_HAS_WSTR_MEMORY(unicode))
        PyObject_DEL(_PyUnicode_WSTR(unicode));
    if (_PyUnicode_HAS_UTF8_MEMORY(unicode))
        PyObject_DEL(_PyUnicode_UTF8(unicode));
    if (!PyUnicode_IS_COMPACT(unicode) && _PyUnicode_DATA_ANY(unicode))
        PyObject_DEL(_PyUnicode_DATA_ANY(unicode));

    Py_TYPE(unicode)->tp_free(unicode);
}

```

在新建一个"Python"字符串(Unicode)的时候,内部机制:

![](http://orh99zlhi.bkt.clouddn.com/2018-03-02,23:33:51.jpg)


新建一个"python"字符串对象,如果 intern有,则指向intern的对象中,然后销毁之前创建的"python"字符串对象;

* intern，单(空)字符缓冲池：复用不可变对象；interned为pydict，new出来一个字符串的时候先查询它


