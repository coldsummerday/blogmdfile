



##概述:
pyc文件py存储字节码的文件.But,pyc并不是一个二进制可执行文件(只不过是python把module序列化了保存在文件中,避免每次导入都需要编译的烦恼),运行的时候读入pyc中的字节码,恢复为python中的对象,然后正常运行.


##深入了解:

其实pyc中是一个个PyCodeObject的对象(~.~python万物皆对象).

源码部分:

```c
typedef struct {
    PyObject_HEAD
    int co_argcount;            /* #arguments, except *args */
    int co_kwonlyargcount;      /* #keyword only arguments */
    int co_nlocals;             /* #local variables */
    int co_stacksize;           /* #entries needed for evaluation stack */
    int co_flags;               /* CO_..., see below */
    int co_firstlineno;         /* first source line number */
    PyObject *co_code;          /* instruction opcodes */
    PyObject *co_consts;        /* list (constants used) */
    PyObject *co_names;         /* list of strings (names used) */
    PyObject *co_varnames;      /* tuple of strings (local variable names) */
    PyObject *co_freevars;      /* tuple of strings (free variable names) */
    PyObject *co_cellvars;      /* tuple of strings (cell variable names) */
    /* The rest aren't used in either hash or comparisons, except for co_name,
       used in both. This is done to preserve the name and line number
       for tracebacks and debuggers; otherwise, constant de-duplication
       would collapse identical functions/lambdas defined on different lines.
    */
    Py_ssize_t *co_cell2arg;    /* Maps cell vars which are arguments. */
    PyObject *co_filename;      /* unicode (where it was loaded from) */
    PyObject *co_name;          /* unicode (name, for reference) */
    PyObject *co_lnotab;        /* string (encoding addr<->lineno mapping) See
                                   Objects/lnotab_notes.txt for details. */
    void *co_zombieframe;       /* for optimization only (see frameobject.c) */
    PyObject *co_weakreflist;   /* to support weakrefs to code objects */
    /* Scratch space for extra data relating to the code object.
       Type is a void* to keep the format private in codeobject.c to force
       people to go through the proper APIs. */
    void *co_extra;
} PyCodeObject;

```

Field|Content
---|---
co_argcount|CodeBlock位置参数的个数
co_nlocals|Code Block中局部变量的个数,包括位置参数
co_kwonlyargcount|传入key-value值参数的个数
co_stacksize|栈大小
co_flags|N\A
\*co_code|Code Block编译所得字节码,用PyBytesObject存储
\*co_consts|常量数目
\*co_names|符号名
co_lnotab|字节码指令与源文件中行号对应关系



##新建与更新:
###新建:
Python的import机制会触发pyc文件的生成，如果碰到import abx ，则回去设定好的path寻找abc.pyc文件,如果只发现了abc.py,则编译生成pycodeobject,然后创建pyc,将对象写入pyc.

###更新
pyc文件何时更新,在写入pyc的时候会写入一个当前时间.运行的时候检查pyc的时间与.py文件的最后修改时间,如果pyc时间早于.py最后修改时间,则证明源文件修改过,需要重新编译.








###写入:
marshal.c文件中,存储了
**将Python对象写入文件并读取。
这主要用于编写和读取已编译的Python代码**的有关操作:

WFILE结构体,

```c
typedef struct {
    FILE *fp;
    int error;  /* see WFERR_* values */
    //depth代表了block的深度,比如模块内的函数内,则是depth=2
    int depth;
    PyObject *str;
    char *ptr;
    char *end;
    char *buf;
    _Py_hashtable_t *hashtable;
    int version;
} WFILE;
```

w_object方法,将PyCodeObject对象写入pyc文件中.

```c
static void
w_object(PyObject *v, WFILE *p)
{
    char flag = '\0';
    
    //在当前深度加一,表示进入了一个命名空间
    p->depth++;

    if (p->depth > MAX_MARSHAL_STACK_DEPTH) {
        p->error = WFERR_NESTEDTOODEEP;
    }
    //写入不同对象
    else if (v == NULL) {
        w_byte(TYPE_NULL, p);
    }
    else if (v == Py_None) {
        w_byte(TYPE_NONE, p);
    }
    else if (v == PyExc_StopIteration) {
        w_byte(TYPE_STOPITER, p);
    }
    else if (v == Py_Ellipsis) {
        w_byte(TYPE_ELLIPSIS, p);
    }
    else if (v == Py_False) {
        w_byte(TYPE_FALSE, p);
    }
    else if (v == Py_True) {
        w_byte(TYPE_TRUE, p);
    }
    else if (!w_ref(v, &flag, p))
        w_complex_object(v, flag, p);

    p->depth--;
}

```


在不同的对象写入中,都有W_TYPE,写入该对象的标志(一个数值),以便再次加载的时候复原对象;

marshal.c文件中,定义了这些对象类型写入pyc文件时候的符号:

![](http://orh99zlhi.bkt.clouddn.com/2018-03-13,11:08:13.jpg)

