##DictObect的概述:

python3.8的cpython版本中,dict涉及的文件:
Include/dictobject.h
Objects/dict-common.h

Objects/dictobject.c


在python3中,dict的哈希表冲突解决方式采用的是开放定址法,同时与python2相比,内存上key与value分开管理,存在两种形式的字典:划分表与组合表;


PyDictObject的管理方式:

```c
+---------------+   
| ma_used       |   
|ma_version_tag |   
| *ma_keys      |   
| **ma_values   |   
+---------------+
```
used是dict中item的数量,
my_key对应下面的_dictkeysobject,
ma_values则是字典为spilt-table时存储的value.


_dictkeysobject的管理方式:

```c
+---------------+   
| dk_refcnt     |   
| dk_size       |   
| dk_lookup     |   
| dk_usable     |   
| dk_nentries   |   
+---------------+   
| dk_indices    |   
|               |   
+---------------+   
| dk_entries    |   
|               |
+---------------+
```
dk_indices和dk_entries是两个数组, 它们包含在连续的内存空间内, 并且它们两个的大小是可变的,dk_indices包含了存在于当前dict的索引, 或者表示当前这个entrie是DKIX_EMPTY(-1)或者DKIX_DUMMY(-2)

##散列与开放定地址法:

散列表基本思想:通过一定的函数将需要搜索的键值映射为一个整数,将这个整数视为索引值去访问某片连续的内存区域.

解决哈希冲突的时候,Python 中所采用的是另一种方法，即开放定址 法。

当产生散列冲突时，Python 会通过一个再次探测函数，计算下一个候选位置， 如果这个位置可用，则可将待插入元素放到这个位置;如果这个位置不可用，则 Python 会再次通过探测函数，获得下一个候选位置，如此不断探测，总会找到一 个可用的位置.

这样，沿着探测函数，从一个位置出发可以依次到达多个位置，这些位置形成了一个探测链

所以，在采用开放定址的冲突解决策略的散列表中，删除某条探测链上的元 素时不能真正地删除，而是进行一种“伪删除”操作，必须要让该元素还存在于 探测链上，担当承前启后的重任。



###头文件定义

```c
typedef struct {
    PyObject_HEAD

    /* Number of items in the dictionary */
    Py_ssize_t ma_used;

    /* Dictionary version: globally unique, value change each time
       the dictionary is modified */
    uint64_t ma_version_tag;

    PyDictKeysObject *ma_keys;

    /* If ma_values is NULL, the table is "combined": keys and values
       are stored in ma_keys.

       If ma_values is not NULL, the table is splitted:
       keys are stored in ma_keys and values are stored in ma_values */
    PyObject **ma_values;
} PyDictObject;
```


* ma_used 字典中有几个元素
* ma_version_tag 字典的版本
* \*ma_keys key
* \*ma_values  value(划分表中对应的value,组合表的value存储在entry中)


```c
typedef struct _dictkeysobject PyDictKeysObject;


//dict_common.h


struct _dictkeysobject {
    Py_ssize_t dk_refcnt;

    /* Size of the hash table (dk_indices). It must be a power of 2. */
    Py_ssize_t dk_size;

    /* Function to lookup in the hash table (dk_indices):

       - lookdict(): general-purpose, and may return DKIX_ERROR if (and
         only if) a comparison raises an exception.

       - lookdict_unicode(): specialized to Unicode string keys, comparison of
         which can never raise an exception; that function can never return
         DKIX_ERROR.

       - lookdict_unicode_nodummy(): similar to lookdict_unicode() but further
         specialized for Unicode string keys that cannot be the <dummy> value.

       - lookdict_split(): Version of lookdict() for split tables. */
    dict_lookup_func dk_lookup;

    /* Number of usable entries in dk_entries. */
    Py_ssize_t dk_usable;

    /* Number of used entries in dk_entries. */
    Py_ssize_t dk_nentries;

    /* Actual hash table of dk_size entries. It holds indices in dk_entries,
       or DKIX_EMPTY(-1) or DKIX_DUMMY(-2).

       Indices must be: 0 <= indice < USABLE_FRACTION(dk_size).

       The size in bytes of an indice depends on dk_size:

       - 1 byte if dk_size <= 0xff (char*)
       - 2 bytes if dk_size <= 0xffff (int16_t*)
       - 4 bytes if dk_size <= 0xffffffff (int32_t*)
       - 8 bytes otherwise (int64_t*)

       Dynamically sized, 8 is minimum. */
    union {
        int8_t as_1[8];
        int16_t as_2[4];
        int32_t as_4[2];
#if SIZEOF_VOID_P > 4
        int64_t as_8[1];
#endif
    } dk_indices;

    /* "PyDictKeyEntry dk_entries[dk_usable];" array follows:
       see the DK_ENTRIES() macro */
};



```

* dk_size 哈希表的大小
* dk_indices 哈希表(也就是这个key在字典中存储的值)(数组大小保证是64位)
* dk_lookup 用来得到哈希值的方法:
    * lookdict()常用的
    * lookdict_unicode()专门用于unicode字符的,不会返回错误
    * lookdict_unicode_nodummy()不设置虚拟值
    * lookdict_split():分割表的lookdict()版本
* dk_usable dk_entry中可用数目(关联容器中的一个(键，值)元素对称为一个 entry)
* dk_nentries dk_entry中已用数目,动态调整,8是最小值

```c
typedef struct {
    /* Cached hash code of me_key. */
    Py_hash_t me_hash;
    PyObject *me_key;
    PyObject *me_value; /* This field is only meaningful for combined tables */
} PyDictKeyEntry;
```

实体entry的定义:存储了哈希值,key与value


###散列index的四种状态:

```c
#define DKIX_EMPTY (-1)
#define DKIX_DUMMY (-2)  /* Used internally */
#define DKIX_ERROR (-3)
```

dk_entries(keys)[index]

* Unused 状态,当index==DKIX_EMPTY(每个槽的基本状态,没有激活键值对)
* Active 当indez>=0,me_key!=Null,me_value!=NULL
* Dummy(虚假的),entry 进入 Dummy 态。这是一种惰性删除技巧，是为了保证冲突的探 测序列不会在这里被中断.(伪删除)
* pending index>=0,且key!=NULL,Value==NULL.(表示还没有插入分割表)



###dict的两种形式:

我们来看下注释:

```c
/* The ma_values pointer is NULL for a combined table
 * or points to an array of PyObject* for a split table
 */
```
ma_values是决定dict的关键

* 结合表:
    ma_values\=\=NULL,dk_refcnt\=\=1,值存储在PyDictKeysObject的me_value中
    
* 分割表:

ma_values!=NULL,dk_refcnt>=1,值存储在ma_values中,只允许使用字符串(unicode)键。
所有共享同一密钥的命令必须具有相同的插槽,主要用在优化对象存储属性的tp_dict上


大小:#define PyDict_MINSIZE 8

PyDict_MINSIZE是任何新命令的开始

8  运行   不超过5个的活跃状态的dict entry存在(这个值被认为是通过大量的实验得出 的最佳值。既不会太浪费内存空间，又能很好地满足 Python 中大量使用 PyDictObject 的环境的需求)



为了避免在接近满的表上减慢查找速度，我们调整了表的大小。
这是USABLE_FRACTION(目前三分之二)满。


###python哈希设计思想:
一般的哈希都在寻找一个足够"随机"的散列来保证冲突,但是python并没有这么做,在python的使用中,最重要的哈希函数对于(int)来说很常见:

如果将大的哈希值映射到序列中:

将哈希值与序列大小-1的二进制数做一个与运算

如:



```
>>>[hash(i) for i in range(4)]
[0,1,2,3]
```




冲突避免机制
####乘个数求余数


在一张2\*\*i的表中,用低阶i作为索引非常快.
当发生冲突的时候,取哈希码的最后一位i
首先,第一个策略为:

```
j = ((j*5+1)mod(2**i))
```

不用线性探索的策略是因为在连续的散列值下面,线性探索很糟糕.

2\*\*3的哈希table情况下:

该方法的探索链为:

```
 0 -> 1 -> 6 -> 7 -> 4 -> 5 -> 2 -> 3 -> 0 
```

####采用惊动位
另一半是获取散列码的其他位
进场;

```c

#define PERTURB_SHIFT 5
左移5位,除以2**5
    perturb >>= PERTURB_SHIFT;
    j = (5*j) + 1 + perturb;
    use j % 2**i as the next table index;
```

perturb >>= PERTURB_SHIFT;
j = (5*j) + 1 + perturb;

加一个除以32的数,来保证数大的时候产生避免刚好在(5*j)+1 求余时候冲突
    
    
    

###dict的日常操作:

####新建

```c

//先新建key对象,然后传入一个null的value对象新建dict
PyObject *
PyDict_New(void)
{
    PyDictKeysObject *keys = new_keys_object(PyDict_MINSIZE);
    if (keys == NULL)
        return NULL;
    return new_dict(keys, NULL);
}

static PyDictKeysObject *new_keys_object(Py_ssize_t size)
{
    PyDictKeysObject *dk;
    Py_ssize_t es, usable;

    assert(size >= PyDict_MINSIZE);
    assert(IS_POWER_OF_2(size));

    usable = USABLE_FRACTION(size);

    //8位,一个B存储
    if (size <= 0xff) {
        es = 1;
    }
        //16位
    else if (size <= 0xffff) {
        es = 2;
    }
        //32位
#if SIZEOF_VOID_P > 4
    else if (size <= 0xffffffff) {
        es = 4;
    }
#endif
    else {
        es = sizeof(Py_ssize_t);
    }
//如果是新建一个keyobject,且缓冲池内有空余的,从缓冲池中拿
    if (size == PyDict_MINSIZE && numfreekeys > 0) {
        dk = keys_free_list[--numfreekeys];
    }
        //否则,申请内存
    else {
        dk = PyObject_MALLOC(sizeof(PyDictKeysObject)
                             - Py_MEMBER_SIZE(PyDictKeysObject, dk_indices)
                             + es * size
                             + sizeof(PyDictKeyEntry) * usable);
        if (dk == NULL) {
            PyErr_NoMemory();
            return NULL;
        }
    }
    DK_DEBUG_INCREF dk->dk_refcnt = 1;
    //hashtable的大小
    dk->dk_size = size;
    dk->dk_usable = usable;
    dk->dk_lookup = lookdict_unicode_nodummy;
    dk->dk_nentries = 0;
    memset(&dk->dk_indices.as_1[0], 0xff, es * size);
    memset(DK_ENTRIES(dk), 0, sizeof(PyDictKeyEntry) * usable);
    return dk;
}

static PyObject *
new_dict(PyDictKeysObject *keys, PyObject **values)
{
    PyDictObject *mp;
    assert(keys != NULL);
    if (numfree) {
        //缓冲池中获取dict对象
        mp = free_list[--numfree];
        assert (mp != NULL);
        assert (Py_TYPE(mp) == &PyDict_Type);
        _Py_NewReference((PyObject *)mp);
    }
    else {
        //从python内存池中new一个dictob对象
        mp = PyObject_GC_New(PyDictObject, &PyDict_Type);
        if (mp == NULL) {
            //如果无法申请,则减少keys的引用次数,
            DK_DECREF(keys);
            //PyMem_FREE(values)
            free_values(values);
            return NULL;
        }
    }
    mp->ma_keys = keys;
    mp->ma_values = values;
    mp->ma_used = 0;
    //全局计数器,每次新建dict加一
    mp->ma_version_tag = DICT_NEXT_VERSION();
    assert(_PyDict_CheckConsistency(mp));
    return (PyObject *)mp;
}
```


* 新建PykeyObject对象
* 新建dict对象

(其中key跟dict都使用了缓冲池技术)



####key的搜索:

我们看到在新建key的时候,指定的lookup搜索方法为:

```c

    dk->dk_lookup = lookdict_unicode_nodummy;
```

但这里提供了三种搜索函数:

* lookdict 通用的方法,
* lookdict_unicode 用于unicode字符串
* lookdict_unicode_nodummy 进一步用于string keys that cannot be
the <dummy> value.


这里只贴lookdict方法,因为其他两个方法实现类似,只不过加了类型检查:

```c
static Py_ssize_t _Py_HOT_FUNCTION
lookdict(PyDictObject *mp, PyObject *key,
         Py_hash_t hash, PyObject **value_addr)
{
    size_t i, mask, perturb;
    PyDictKeysObject *dk;
    PyDictKeyEntry *ep0;

top:
    dk = mp->ma_keys;
    //ep0为hashtable
    ep0 = DK_ENTRIES(dk);
    //hashtable的大小
    mask = DK_MASK(dk);
    perturb = hash;

    //dict内存储的entry数量比key的hash 小很多,直接与操作,则落在entry范围之内,
    //根据 hash 值获得 entry 的序号。
    //[1]
    i = (size_t)hash & mask;

    for (;;) {
        //ix为dk-实际哈希表中的存储的索引  dk-dk_indices为实际哈希表的索引值
        Py_ssize_t ix = dk_get_index(dk, i);
        //[2]
        //如果索引没被使用,证明搜索的Key不存在
        if (ix == DKIX_EMPTY) {
            *value_addr = NULL;
            return ix;
        }
        //ix小于0证明该索引不一定存有值
        if (ix >= 0) {
            //[3]
            //如果索引大于0,则去存储key,value地址的enrty表 ep0中去取值
            PyDictKeyEntry *ep = &ep0[ix];
            assert(ep->me_key != NULL);
            //如果该key是要搜索的key,将value的地址赋给value_addr,返回
            if (ep->me_key == key) {
                *value_addr = ep->me_value;
                return ix;
            }
            //[4]
            //如果不是这个key,证明该key产生冲突了,搜索剩余的key
            if (ep->me_hash == hash) {
                PyObject *startkey = ep->me_key;
                Py_INCREF(startkey);
                int cmp = PyObject_RichCompareBool(startkey, key, Py_EQ);
                //cmp=1,两个相等,cmp=0,不等于,<0比较中发生了错误
                Py_DECREF(startkey);
                //在开始key之前,只能证明没有结果了(冲突了一般在冲突链的后面)
                if (cmp < 0) {
                    *value_addr = NULL;
                    return DKIX_ERROR;
                }
                if (dk == mp->ma_keys && ep->me_key == startkey) {
            //如果是mp的key链跟startkey链都在第一次而且key值相等,则证明在探索链的第一次找到了,
            // 返回结果,否则,key不相等的时候,进入探索链的下一次值
            //
                    if (cmp > 0) {

                        *value_addr = ep->me_value;
                        return ix;
                    }
                }
                else {
                    /* The dict was mutated, restart */
                    goto top;
                }
            }
        }
        //[5]
        //如果哈希值不相等,则取得下一个索引值(),根据python哈希冲突计算方法
        perturb >>= PERTURB_SHIFT;
        i = (i*5 + perturb + 1) & mask;
    }
    Py_UNREACHABLE();
}
```

下面是 lookdict 中进行第一次检查时需要注意的动作

* [1] 根据哈希值得到entry的索引值
* [2] 索引值如果没使用证明搜索的key值不存在
* [3] 根据索引值找到真正的key-value实体
* [4] 当冲突的时候(hash相等的时候),检查当前检索key与当前mp的key是否一样,不一样重新来过,一样的话判断key值相等的话,返回取得的结果
* [5]哈希值不相等,取下一个索引值判断


而其他两个版本是针对unicode做的优化:

Python源码分析
 
>Python自身用了大量的dict来维护”命名空间中变量名和值的对应关系, 或是用来在为函数传递参数时维护参数名与参数值的对应关系”, 所以实现unicode版本可以提升Python整体的效率.

####插入




```c
static int
insertdict(PyDictObject *mp, PyObject *key, Py_hash_t hash, PyObject *value)
{
    PyObject *old_value;
    PyDictKeyEntry *ep;

    Py_INCREF(key);
    Py_INCREF(value);
    if (mp->ma_values != NULL && !PyUnicode_CheckExact(key)) {
        //如果原来dict的value存在,需要对value进行调整大小
        if (insertion_resize(mp) < 0)
            goto Fail;
    }
    //搜索该key是否有value
    Py_ssize_t ix = mp->ma_keys->dk_lookup(mp, key, hash, &old_value);
    if (ix == DKIX_ERROR)
        goto Fail;

    assert(PyUnicode_CheckExact(key) || mp->ma_keys->dk_lookup == lookdict);
    MAINTAIN_TRACKING(mp, key, value);

    /* When insertion order is different from shared key, we can't share
     * the key anymore.  Convert this instance to combine table.
     */

    //当含有分割表的时候,
    if (_PyDict_HasSplitTable(mp) &&
        ((ix >= 0 && old_value == NULL && mp->ma_used != ix) ||
         (ix == DKIX_EMPTY && mp->ma_used != mp->ma_keys->dk_nentries))) {
        if (insertion_resize(mp) < 0)
            goto Fail;
        //该索引值没有被引用的情况,应该将索引值设为未引用
        ix = DKIX_EMPTY;
    }
    //该索引未引用,直接调整value大小插入值
    if (ix == DKIX_EMPTY) {
        /* Insert into new slot. */
        assert(old_value == NULL);
        if (mp->ma_keys->dk_usable <= 0) {
            /* Need to resize. */
            if (insertion_resize(mp) < 0)
                goto Fail;
        }
        //找到一个插入的空槽(哈希表中的index)
        Py_ssize_t hashpos = find_empty_slot(mp->ma_keys, hash);
        //获取到dk中的entries
        ep = &DK_ENTRIES(mp->ma_keys)[mp->ma_keys->dk_nentries];
        //将刚才找到index,插入到keys中
        dk_set_index(mp->ma_keys, hashpos, mp->ma_keys->dk_nentries);
        //设置entry值
        ep->me_key = key;
        ep->me_hash = hash;
        if (mp->ma_values) {
            assert (mp->ma_values[mp->ma_keys->dk_nentries] == NULL);
            mp->ma_values[mp->ma_keys->dk_nentries] = value;
        }
        else {
            ep->me_value = value;
        }
        //dict中已用的项加一
        mp->ma_used++;
        mp->ma_version_tag = DICT_NEXT_VERSION();
        mp->ma_keys->dk_usable--;
        mp->ma_keys->dk_nentries++;
        assert(mp->ma_keys->dk_usable >= 0);
        assert(_PyDict_CheckConsistency(mp));
        return 0;
    }

    if (_PyDict_HasSplitTable(mp)) {
        //这个dict是一个分隔表,则插入到ma_values中
        mp->ma_values[ix] = value;
        if (old_value == NULL) {
            /* pending state */
            assert(ix == mp->ma_used);
            mp->ma_used++;
        }
    }
    else {
        assert(old_value != NULL);
        DK_ENTRIES(mp->ma_keys)[ix].me_value = value;
    }

    mp->ma_version_tag = DICT_NEXT_VERSION();
    Py_XDECREF(old_value); /* which **CAN** re-enter (see issue #22653) */
    assert(_PyDict_CheckConsistency(mp));
    Py_DECREF(key);
    return 0;

Fail:
    Py_DECREF(value);
    Py_DECREF(key);
    return -1;
}
#define GROWTH_RATE(d) (((d)->ma_used*2)+((d)->ma_keys->dk_size>>1))


```


插入过程详解:

* [1]增加key跟object的引用次数
* [2] 搜索key是否有值,有值的话错误返回
* [3]调整dict大小,增长率为:已用*2 + 容量/2.(调整过程如果是拆分表需要转化为组合表)
* [4] 根据hash值找到 keys的空槽(hashpos)(index,插入位置)
* [5] 将hashpos占位,同时赋值一个pydictentry对象,key,value,hash,将这个entry对象,更改dict中已用个数等信息,返回
* [4-2]处理划分表的情况,value直接赋值到ma_values[ix]中





引用部分:

1. PyDict_SetItem(dictobject,key,value)
是调用了hash = PyObject_Hash(key)后 再调用insertdict来设置字典的值




#####插入涉及的函数:

(1)寻找空槽的函数:
 perturb >>= PERTURB_SHIFT;
i = (i*5 + perturb + 1) & mask;

冲突避免算法:
 perturb >>= PERTURB_SHIFT;
i = (i*5 + perturb + 1) & mask;
找到一个空槽,等待插入


key的hash值转化为keys中的空槽:

```c
static Py_ssize_t
find_empty_slot(PyDictKeysObject *keys, Py_hash_t hash)
{
    assert(keys != NULL);

    const size_t mask = DK_MASK(keys);
    size_t i = hash & mask;
    Py_ssize_t ix = dk_get_index(keys, i);
    for (size_t perturb = hash; ix >= 0;) {
        perturb >>= PERTURB_SHIFT;
        i = (i*5 + perturb + 1) & mask;
        ix = dk_get_index(keys, i);
    }
    //利用哈希冲突算法,找到一个空槽
    return i;
}
```



调整dict大小的函数:增长率为:已用*2 + 容量/2(每次新的大小为这个)

```c
static int
dictresize(PyDictObject *mp, Py_ssize_t minsize)
{
    Py_ssize_t newsize, numentries;
    PyDictKeysObject *oldkeys;
    PyObject **oldvalues;
    PyDictKeyEntry *oldentries, *newentries;


    //每次乘2直到大于需要调整的大小
    /* Find the smallest table size > minused. */
    for (newsize = PyDict_MINSIZE;
         newsize < minsize && newsize > 0;
         newsize <<= 1)
        ;
    if (newsize <= 0) {
        PyErr_NoMemory();
        return -1;
    }

    oldkeys = mp->ma_keys;

    /* NOTE: Current odict checks mp->ma_keys to detect resize happen.
     * So we can't reuse oldkeys even if oldkeys->dk_size == newsize.
     * TODO: Try reusing oldkeys when reimplement odict.
     */

    /* Allocate a new table. */
    //申请新的keyobject table
    mp->ma_keys = new_keys_object(newsize);
    if (mp->ma_keys == NULL) {
        mp->ma_keys = oldkeys;
        return -1;
    }
    // New table must be large enough.
    assert(mp->ma_keys->dk_usable >= mp->ma_used);
    if (oldkeys->dk_lookup == lookdict)
        mp->ma_keys->dk_lookup = lookdict;
    //copy键跟值到新的key中,
    numentries = mp->ma_used;
    oldentries = DK_ENTRIES(oldkeys);
    newentries = DK_ENTRIES(mp->ma_keys);
    oldvalues = mp->ma_values;
    //如果ma_values不为NULl,则证明原来的表是拆分表,需要将其合并为组合表,copy value跟key到entry中
    if (oldvalues != NULL) {
        /* Convert split table into new combined table.
         * We must incref keys; we can transfer values.
         * Note that values of split table is always dense.
         */

        //将拆分表转化为组合表,增加建
        for (Py_ssize_t i = 0; i < numentries; i++) {
            assert(oldvalues[i] != NULL);
            PyDictKeyEntry *ep = &oldentries[i];
            PyObject *key = ep->me_key;
            Py_INCREF(key);
            newentries[i].me_key = key;
            newentries[i].me_hash = ep->me_hash;
            newentries[i].me_value = oldvalues[i];
        }

        DK_DECREF(oldkeys);
        mp->ma_values = NULL;
        if (oldvalues != empty_values) {
            free_values(oldvalues);
        }
    }
    else {  // combined table.
        if (oldkeys->dk_nentries == numentries) {
            memcpy(newentries, oldentries, numentries * sizeof(PyDictKeyEntry));
        }
        else {
            PyDictKeyEntry *ep = oldentries;
            for (Py_ssize_t i = 0; i < numentries; i++) {
                while (ep->me_value == NULL)
                    ep++;
                newentries[i] = *ep++;
            }
        }

        assert(oldkeys->dk_lookup != lookdict_split);
        assert(oldkeys->dk_refcnt == 1);
        if (oldkeys->dk_size == PyDict_MINSIZE &&
            numfreekeys < PyDict_MAXFREELIST) {
            DK_DEBUG_DECREF keys_free_list[numfreekeys++] = oldkeys;
        }
        else {
            DK_DEBUG_DECREF PyObject_FREE(oldkeys);
        }
    }

    build_indices(mp->ma_keys, newentries, numentries);
    mp->ma_keys->dk_usable -= numentries;
    mp->ma_keys->dk_nentries = numentries;
    return 0;
}

```


####删除:


删除比插入简单

```c
static int
delitem_common(PyDictObject *mp, Py_hash_t hash, Py_ssize_t ix,
               PyObject *old_value)
{
    PyObject *old_key;
    PyDictKeyEntry *ep;

    //得到该key的空槽位置
    Py_ssize_t hashpos = lookdict_index(mp->ma_keys, hash, ix);
    assert(hashpos >= 0);

    //引用减少
    mp->ma_used--;
    mp->ma_version_tag = DICT_NEXT_VERSION();
    ep = &DK_ENTRIES(mp->ma_keys)[ix];
    //将该空槽位置设为虚假删除状态(因为要保持链的完整)
    dk_set_index(mp->ma_keys, hashpos, DKIX_DUMMY);
    ENSURE_ALLOWS_DELETIONS(mp);
    old_key = ep->me_key;
    //entry指空,回收
    ep->me_key = NULL;
    ep->me_value = NULL;
    Py_DECREF(old_key);
    Py_DECREF(old_value);

    assert(_PyDict_CheckConsistency(mp));
    return 0;
}

```

* [1]找到该key对应的槽index
* 获取entry对象,并指空等待缓冲池回收
* 槽index设置为虚假删除状态DUMMY(保持探索链的完整)

而PyDict_DelItem(PyObject \*op, PyObject \*key)方法只不过是 先计算了key值的hash跟 ix(槽值)再调用delitem_common方法;




###缓冲池技术:

```c
#define PyDict_MAXFREELIST 80
static PyDictObject *free_list[PyDict_MAXFREELIST];
static int numfree = 0;
static PyDictKeysObject *keys_free_list[PyDict_MAXFREELIST];
static int numfreekeys = 0;
```

实际上 PyDictObject 中使用的这个缓冲池机制与 PyListObject 中使用的缓冲 池机制是一样的。开始时，这个缓冲池里什么都没有，直到有第一个 PyDictObject 被销毁时，这个缓冲池才开始接纳被缓冲的 PyDictObject 对象;

最多缓存80个dict对象.

```c
static void
dict_dealloc(PyDictObject *mp)
{
    PyObject **values = mp->ma_values;
    PyDictKeysObject *keys = mp->ma_keys;
    Py_ssize_t i, n;

    /* bpo-31095: UnTrack is needed before calling any callbacks */
    PyObject_GC_UnTrack(mp);
    Py_TRASHCAN_SAFE_BEGIN(mp)
    if (values != NULL) {
        if (values != empty_values) {
            for (i = 0, n = mp->ma_keys->dk_nentries; i < n; i++) {
                Py_XDECREF(values[i]);
            }
            free_values(values);
        }
        DK_DECREF(keys);
    }
    else if (keys != NULL) {
        assert(keys->dk_refcnt == 1);
        DK_DECREF(keys);
    }
    //如果缓冲池还有位置且mp为dict对象,则放入free_list中
    if (numfree < PyDict_MAXFREELIST && Py_TYPE(mp) == &PyDict_Type)
        free_list[numfree++] = mp;
    else
        Py_TYPE(mp)->tp_free((PyObject *)mp);
    Py_TRASHCAN_SAFE_END(mp)
}
#define free_values(values) PyMem_FREE(values)
```

在销毁的时候,销毁了ma_values对象,并回收dict对象,如果是划分表的话,减少keys的引用次数.

和 PyListObject 中缓冲池的机制一样，缓冲池中只保留了 PyDictObject 对象跟pykeysobject对象， 而 PyDictObject 对象中维护的从堆上申请的 table 的空间则被销毁，并归还给系 统了。

在new_dict的时候:

```c
    if (numfree) {
        //缓冲池中获取dict对象
        mp = free_list[--numfree];
        assert (mp != NULL);
        assert (Py_TYPE(mp) == &PyDict_Type);
        _Py_NewReference((PyObject *)mp);
    }
```


##python2与3中dict的不同地方:

###内存存储:

* 内存布局,分离存储了key和value,详细地介绍:https://mail.python.org/pipermail/python-dev/2012-December/123028.html
* 关于hashtable的管理:

对于旧版的hash table，其每个slot存储的是一个 PyDictKeyEntry 对象（PyDictKeyEntry是一个三元组，包含了hash、key、value），这样带来的问题就是，多占用了一些非必要的内存。对于状态为EMPTY的slot，实际可能存储为（0，NULL，NULL）这种形式，但其实这些数据都是冗余的。

因此新版的hash table对此作出了优化，slot（也即是 dk_indices） 存储的不再是一个 PyDictKeyEntry，而是一个数组的index，这个数组存储了具体且必要的 PyDictKeyEntry对象 。对于那些EMPTY、DUMMY状态的这类slot，只需要用个负数（区分大于0的index）表示即可。

实际上还会根据需要索引 PyDictKeyEntry 对象的数量，动态的决定是用什么类型的变量来表示index。例如，如果所存储的 PyDictKeyEntry 数量不超过127，那么实际上用长度为一个字节的带符号整数（char）存储index即可。需要说明的是，index的值是有可能为负的（EMPTY、DUMMY、ERROR），因此需要用带符号的整数存储。

###形式:
新版的dict有两种形式，分别是 combined 和 split。

* combined,普通dict的用法
* split这种字典的key是共享的，有一个引用计数器 dk_refcnt 来维护当前被引用的个数。而之所以设计出split形式的字典，是因为观察到了python虚拟机中，会有大量key相同而value不同的字典的存在。而这个特定的情况就是实例对象上存储属性的 tp_dict 字典！

我们都知道，python使用dict来存储对象的属性。考虑一个这样的场景：

* 一个类会创建出很多个对象。
* 这些对象的属性，能在一开始就确定下来，并且后续不会增加删除。

方法就是，属于一个类的所有对象共享同一份属性字典的key，而value以数组的方式存储在每个对象的身上。

设计思路: https://www.python.org/dev/peps/pep-0412/#id3

###entry的状态:

python3中每个entry会有四种状态Unused,Active,Dummy(伪删除),Pending(只发生在split-table中,表示还没有插入split-table)


##引用与参考

dict实现思路:

* https://mail.python.org/pipermail/python-dev/2012-December/123028.html
* https://morepypy.blogspot.com/2015/01/faster-more-memory-efficient-and-more.html

