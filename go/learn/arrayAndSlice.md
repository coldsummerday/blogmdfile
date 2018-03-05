##slice的copy




```go
func main() {
     data := [...]int{0,1,2,3,4,5,6,7,8,9};
     s := data[8:]

     s2:=data[:5];
     fmt.Println(s2);
     copy(s2,s);
     fmt.Println(s);
     fmt.Println(s2);
}
```

其中copy是将 s的部分copy到s2上,,
s2:8,9
s:0,1,2,3,4,
因为s2 的0,1有位置了,所以只复制2,3,4到s2的后三位上:

```
[0 1 2 3 4]
[8 9]
[8 9 2 3 4]

```


###修改字符串:
因为字符串是不可修改的,所以只能新建一个byte的数据,然后去修改后赋值给新的字符串:

```go
func main() {
    s:="hello";
    c:=[]byte(s);
    c[0]='3'
    s2:=string(c);
    fmt.Println(s2)
}
```



###map中值为切片:

```go
    map2 := make(map[string][]int)
    map2["1"]=make([]int,6);
    fmt.Println(map2)
```


###map

* 测试key是否存在:

取值的时候,map[key]会返回两个值,第一个值是key的value,第二个值是一个bool值,代表该key是否存在,我们可以利用这个bool判断key

```go
func main() {

    map2 := make(map[string][]int)
    map2["1"]=make([]int,6);
    if value,ok:=map2["2"];ok{
        fmt.Println(value);
    }else {
        fmt.Println("4");
    }

    fmt.Println(map2)

}
```

* for range 与map

对一个map for range的话,会一次返回两个值,(key,value)

```go
func main() {

    map2 := make(map[string]int)
    map2["4"]=5;
    map2["7"]=7;
    for key,value:=range map2 {
        fmt.Println(key,value)
    }

}

4 5
7 7

```

只想知道key:

```go
 for key:=range map2 {
        fmt.Println(key)
    }
```


* 对map排序:

map默认是无序的,如果要对map排序,需要将key或者value拷贝到切片,然后将切片排序,在用切片的for range打印key和value.


```python
import "sort"
func main() {

    map2 := make(map[string]int)
    map2["4"]=5;
    map2["7"]=7;
    map2["6"]= 6;
    keys := make([]string,len(map2))
    i:=0;
    for key,_:=range map2{
        keys[i]=key;
        i++
    }
    sort.Strings(keys);
    for _,k:=range keys{
        fmt.Println(k,map2[k])
    }
 
}

4 5
6 6
7 7
```


如果真想得到一个排序的列表,最好使用结构体切片:

```go
type name struct{
key string
value int
}
```

